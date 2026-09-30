# Cache builder: keeps the fleet binary cache (atticd on de-msa2,
# hosts/de-msa2/attic.nix) stocked with every host's system closure, so a
# `nixos-rebuild switch` anywhere only downloads.
#
# Once a day: clone the repo, `nix flake update`, build every
# nixosConfiguration, `attic push` the results and, only if all of that
# succeeded, commit the new flake.lock and push it. The commit is what makes
# the cache useful: clients rebuild from the same lock the builder built, so
# they evaluate to the very store paths that were just pushed. A lock that
# does not build is never committed.
#
# Because the lock is updated on every run, this job is the fleet's canary for
# upstream nixpkgs changes: it breaks the day nixpkgs marks a package we
# install as insecure, renames an option, or drops a package, even though the
# committed lock still evaluates fine. Two things limit the damage:
#
#   * A failing host no longer aborts the run. The remaining hosts are still
#     built and pushed, so the cache degrades host by host instead of going
#     stale all at once (it silently did for days when `radicle-node` was
#     marked insecure on 2026-09-25).
#   * A `pi` agent then gets the build log and the repo, diagnoses the
#     failure, patches it, checks that *every* host still evaluates, and
#     pushes a `cache-mechanic/fix-*` branch for review -- same idea as
#     hosts/de-msa2/clanker-bot.nix. It never pushes to the default branch:
#     an unreviewed LLM edit here would reach every host's next rebuild.
#
# One-time setup (secrets/agenix-rules.nix has the recipients):
#   # Push-only attic token, minted on de-msa2:
#   sudo atticd-atticadm make-token --sub cache-builder --validity 5y --push nixos \
#     | (cd secrets && agenix -e attic-push-token.age)
#   # Deploy key; add the public half to the GitHub repo with write access:
#   ssh-keygen -t ed25519 -N "" -C nixos-cache-builder@desg0 -f /tmp/k
#   (cd secrets && agenix -e nixos-config-deploy-key.age < /tmp/k); cat /tmp/k.pub
#
# Alongside, `attic watch-store` uploads every path that lands in this
# host's store as it appears. desg0 is the remote builder for the laptops
# (modules/remote_builder.nix), so whatever anyone builds through it, dev
# shells and one-offs included, is in the cache too.
#
# Manual run / inspection:
#   sudo systemctl start nixos-cache-builder.service
#   journalctl -u nixos-cache-builder -f
{
  hosts,
  repo ? "git@github.com:MathisWellmann/nixos-config.git",
  branch ? "main",
  cache ? "nixos",
  # Direct, not through the attic.k3s.lan ingress: the proxy path is slow for
  # bulk pushes (see modules/base_system.nix substituters). The push token is
  # a signed JWT, so plain HTTP on the LAN is the same trust model as pulls.
  attic_endpoint ? "http://de-msa2:3019",
  on_calendar ? "04:00",
  # Model the repair agent runs on, as "<provider>/<model>". Pinned rather than
  # inherited so the unattended run never depends on whatever the interactive
  # user last picked with `/model`.
  agent_model,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  user = "nixos-cache-builder";
  state_dir = "/var/lib/${user}";
  ntfy_url = "https://ntfy.k3s.lan/cluster-alerts";
  # Identity the repair agent commits under, so its work is easy to spot in
  # `git log` and in the ntfy feed.
  agent_name = "cache-mechanic";
  fix_branch_prefix = "${agent_name}/fix-";
  agent_bin = "/run/current-system/sw/bin/pi";
  # Attic client config for both units: endpoint plus the push-only token,
  # read at runtime so a rotated secret takes effect on the next start.
  attic_config_dir = pkgs.writeTextDir "attic/config.toml" ''
    default-server = "de-msa2"
    [servers.de-msa2]
    endpoint = "${attic_endpoint}"
    token-file = "${config.age.secrets.attic-push-token.path}"
  '';
in {
  age.secrets = {
    attic-push-token = {
      file = ../secrets/attic-push-token.age;
      owner = user;
    };
    nixos-config-deploy-key = {
      file = ../secrets/nixos-config-deploy-key.age;
      owner = user;
    };
  };

  users = {
    users.${user} = {
      isSystemUser = true;
      group = user;
      home = state_dir;
      createHome = true;
    };
    groups.${user} = {};
  };

  # The builder never builds on behalf of anyone else, but it must be able to
  # push whatever it just built to the cache and to add the derivation
  # outputs as gc roots for the duration of the run.
  nix.settings.trusted-users = [user];

  systemd.services.nixos-cache-builder = {
    description = "Update flake.lock, build all hosts and push them to the attic cache";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path = with pkgs; [
      attic-client
      gitMinimal
      nix
      openssh
      curl
      # For the repair agent: pi's bash tool needs a shell (`bash` provides
      # both `bash` and `sh`), and its launcher shells out to jq to build
      # models.json from the vLLM server's /v1/models.
      bash
      jq
      coreutils
    ];
    environment = {
      HOME = state_dir;
      XDG_CONFIG_HOME = attic_config_dir;
      GIT_SSH_COMMAND = lib.concatStringsSep " " [
        "ssh"
        "-i ${config.age.secrets.nixos-config-deploy-key.path}"
        "-o IdentitiesOnly=yes"
        "-o UserKnownHostsFile=${state_dir}/known_hosts"
        "-o StrictHostKeyChecking=accept-new"
      ];
    };
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = user;
      # The first run compiles whatever the upstream caches do not have; later
      # runs are incremental against the local store.
      TimeoutStartSec = "12h";
      # Leave the interactive machine usable while the build runs.
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
    script = ''
      set -euo pipefail

      notify() {
        curl -fsS -m 10 -H "Title: nixos-cache-builder on ${config.networking.hostName}" \
          -H "Priority: $1" -H "Tags: $2" -d "$3" ${ntfy_url} >/dev/null || true
      }
      trap 'notify high warning "failed at line $LINENO; see journalctl -u nixos-cache-builder"' ERR

      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT
      cd "$workdir"

      git clone -q --branch ${branch} ${repo} repo
      cd repo
      before="$(git rev-parse HEAD)"

      nix flake update --accept-flake-config
      if git diff --quiet flake.lock; then
        echo "flake.lock unchanged since $before; still building in case the cache lags behind"
      fi

      # gc roots under $workdir keep the closures alive until the push is
      # done; they go away with the workdir.
      #
      # A host that fails to evaluate must not abort the run: the whole point
      # of the cache is that the other hosts still get their closures pushed.
      # `|| true` under `set -e` would also swallow the exit code, so the
      # status is captured explicitly and the log kept for the agent below.
      failed_hosts=""
      for host in ${lib.escapeShellArgs hosts}; do
        echo "==> building $host"
        if nix build --accept-flake-config --no-update-lock-file \
          --out-link "result-$host" \
          ".#nixosConfigurations.$host.config.system.build.toplevel" \
          2>&1 | tee "$workdir/build-$host.log"; then
          :
        else
          echo "==> FAILED $host"
          failed_hosts="$failed_hosts $host"
        fi
      done
      failed_hosts="''${failed_hosts# }"

      # Push whatever did build. A partial cache still spares every client the
      # rebuild for the hosts that are fine.
      if compgen -G "result-*" >/dev/null; then
        echo "==> pushing to ${cache}"
        attic push ${cache} result-*
      else
        echo "==> nothing built, skipping push"
      fi

      if [ -n "$failed_hosts" ]; then
        # Hand the failure to the agent: it diagnoses, patches and pushes a
        # branch for review. It must never touch ${branch} -- a bad fix would
        # otherwise reach every host's next rebuild unreviewed.
        echo "==> build failed for:$failed_hosts; invoking ${agent_name}"
        notify high warning "build failed for:$failed_hosts; ${agent_name} is investigating"

        first_failed="''${failed_hosts%% *}"
        # Tail only: a full nix build log is far larger than the context window,
        # and the actual error is always at the end.
        failure_log="$(tail -c 4000 "$workdir/build-$first_failed.log")"
        fix_branch="${fix_branch_prefix}$(date +%Y%m%d-%H%M%S)"

        # Unquoted heredoc so the env vars reach the prompt verbatim.
        # No backticks and no command substitutions inside.
        agent_prompt="$(cat <<PROMPT
      You are "${agent_name}", a maintenance bot for the NixOS fleet config in the
      current working directory (a fresh clone of ${repo}, branch ${branch}, with an
      already-updated flake.lock).

      The daily cache build failed for these hosts:$failed_hosts
      Every other host built fine, so this is almost certainly config in this repo
      meeting a change in the freshly updated nixpkgs, not broken infrastructure.

      Tail of the build log for "$first_failed":
      ---
      $failure_log
      ---

      Do this:
      1. Identify the root cause. Reproduce evaluation cheaply with:
           nix eval --accept-flake-config --no-update-lock-file \\
             .#nixosConfigurations.$first_failed.config.system.build.toplevel.drvPath
         Note the flake input for nixpkgs is named "nixpkgs-unstable", not "nixpkgs".
      2. Fix it with the smallest change to this repo. Typical causes: a package
         newly marked insecure, a renamed or removed option, a dropped package.
         Prefer removing or replacing an unused package over adding
         permittedInsecurePackages, which accepts the vulnerability and pins a
         version string that must be bumped on every update. If you must allow an
         insecure package, scope it to the host that needs it.
         Do NOT paper over the failure by disabling a host or deleting a feature
         that is actually in use.
      3. Verify EVERY one of these hosts still evaluates, not just the one you
         fixed: ${lib.concatStringsSep " " hosts}
         Use the nix eval command from step 1 for each. All must print a .drv path.
      4. If and only if all hosts evaluate, commit and push a branch:
           git config user.name "${agent_name}"
           git config user.email "${agent_name}@${config.networking.hostName}"
           git checkout -b $fix_branch
           git add -A
           git commit -m "<scope>: <what and why>"
           git push -q origin $fix_branch
         Explain in the commit message WHY the change was needed, citing the
         upstream change. Then print the branch name.
      5. If you cannot fix it, or cannot get all hosts to evaluate, push nothing
         and explain what you found and what you ruled out.

      Never push to ${branch}. Never touch flake.lock: the lock is this run's input
      and is committed separately only when every host builds.
      PROMPT
        )"

        # pi lives in the system profile, which is not on a service's PATH.
        # The model is pinned so the bot never depends on whatever model the
        # interactive user last selected.
        if ${agent_bin} --model ${lib.escapeShellArg agent_model} -p "$agent_prompt"; then
          if git ls-remote --exit-code --heads origin "$fix_branch" >/dev/null 2>&1; then
            notify high wrench "${agent_name} pushed $fix_branch for:$failed_hosts -- review and merge"
          else
            notify high warning "${agent_name} could not fix:$failed_hosts; no branch pushed"
          fi
        else
          notify high warning "${agent_name} errored while investigating:$failed_hosts"
        fi

        # The lock is never committed on a partial build: clients must not
        # rebuild from a lock whose closures are not all in the cache.
        exit 1
      fi

      if git diff --quiet flake.lock; then
        notify low package "lock unchanged, ${toString (builtins.length hosts)} hosts (re)pushed"
        exit 0
      fi

      git config user.name "nixos-cache-builder"
      git config user.email "nixos-cache-builder@desg0"
      git add flake.lock
      git commit -q -m "flake.lock: automated update $(date -I)" \
        -m "Built and pushed to the ${cache} cache for: ${lib.concatStringsSep ", " hosts}."
      git push -q origin HEAD:${branch}
      notify low package "flake.lock updated to $(git rev-parse --short HEAD), ${toString (builtins.length hosts)} hosts pushed"
    '';
  };

  systemd.services.attic-watch-store = {
    description = "Push every new /nix/store path to the attic cache";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "nix-daemon.socket"];
    wants = ["network-online.target"];
    environment.XDG_CONFIG_HOME = attic_config_dir;
    serviceConfig = {
      User = user;
      Group = user;
      ExecStart = "${lib.getExe pkgs.attic-client} watch-store --jobs 4 ${cache}";
      Restart = "always";
      RestartSec = 30;
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.nixos-cache-builder = {
    description = "Daily run of nixos-cache-builder";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = on_calendar;
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
