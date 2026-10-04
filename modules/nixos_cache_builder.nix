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
#     pushes the `cache-mechanic/fix` branch for review -- same idea as
#     hosts/de-msa2/clanker-bot.nix. It never pushes to the default branch:
#     an unreviewed LLM edit here would reach every host's next rebuild.
#
# After a repair the previously failing hosts are rebuilt on the patched tree.
# If they all pass, the run continues into the normal push-and-commit path, so
# a night that needed a fix still fills the cache and still lands a lock --
# the fix itself waits for review on the branch. The lock is only ever
# committed when all hosts built *and* the push succeeded, because a client
# rebuilding from that lock expects to find those closures in the cache.
#
# The repair branch name is fixed rather than timestamped, and the previous
# attempt is used as the starting point. A timestamped branch per run made the
# agent re-derive the same fix from scratch every night and left a pile of
# near-identical unmerged branches (four for one tracy build break in
# 2026-10). Opening the PR is left to the human: the deploy key can push but
# not call the GitHub API, and the ntfy message carries the compare link.
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
  # One stable branch, not one per run: the agent picks up where the last
  # attempt left off instead of re-deriving the same patch every night.
  fix_branch = "${agent_name}/fix";
  # Web URL of the repo, for the "open a PR" link in the ntfy message. Derived
  # from the ssh remote so the two cannot drift apart.
  repo_url = let
    path = lib.removeSuffix ".git" (lib.last (lib.splitString ":" repo));
  in "https://github.com/${path}";
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
      #
      # Sets $failed_hosts to the subset of "$@" that did not build. Defined as
      # a function because the repair path below builds a second time, on the
      # patched tree, and must apply the exact same criterion.
      failed_hosts=""
      build_hosts() {
        failed_hosts=""
        for host in "$@"; do
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
      }

      # Pushes every result-* symlink. A partial cache still spares the hosts
      # that are fine their rebuild, so this runs even when some host failed.
      #
      # An empty result-* set means nothing built at all. That used to only
      # print "skipping push" and fall through to the lock commit, which on
      # 2026-09-28..30 published a lock whose closures were in no cache. It is
      # a hard error now: a push is the one thing this unit exists to do.
      #
      # The set is collected with a plain glob, not `compgen -G`: compgen is
      # part of bash's programmable completion, which a non-interactive shell
      # does not load, so it failed with "command not found" and made every
      # run take the "nothing built" path -- silently, because the old code
      # only logged it. That is the 2026-09-28..30 bug.
      push_results() {
        local results=(result-*)
        if [ ! -e "''${results[0]}" ]; then
          echo "==> nothing built, nothing to push" >&2
          return 1
        fi
        echo "==> pushing ''${#results[@]} closures to ${cache}"
        attic push ${cache} "''${results[@]}"
      }

      build_hosts ${lib.escapeShellArgs hosts}

      if [ -n "$failed_hosts" ]; then
        # Hand the failure to the agent: it diagnoses, patches and pushes a
        # branch for review. It must never touch ${branch} -- a bad fix would
        # otherwise reach every host's next rebuild unreviewed.
        echo "==> build failed for:$failed_hosts; invoking ${agent_name}"
        notify high warning "build failed for:$failed_hosts; ${agent_name} is investigating"

        broken_hosts="$failed_hosts"
        first_failed="''${failed_hosts%% *}"
        # Tail only: a full nix build log is far larger than the context window,
        # and the actual error is always at the end.
        failure_log="$(tail -c 4000 "$workdir/build-$first_failed.log")"

        # Continue from the last attempt instead of from a bare ${branch}, so a
        # fix that needs more than one night accumulates rather than restarts.
        # The branch is rebased onto the current ${branch} first: its diff must
        # apply to what is actually deployed, not to last week's tree.
        git config user.name "${agent_name}"
        git config user.email "${agent_name}@${config.networking.hostName}"

        # The updated flake.lock is an unstaged change at this point, and both
        # `git rebase` and `git checkout -B` refuse to run with a dirty tree.
        # Park it in a file rather than `git stash`: the lock is this run's
        # input and must survive every branch switch below unchanged, including
        # the paths where a rebase is aborted.
        cp flake.lock "$workdir/flake.lock.new"
        git checkout -q -- flake.lock

        if git fetch -q origin "${fix_branch}" 2>/dev/null; then
          echo "==> resuming ${fix_branch} from the previous run"
          git checkout -q -B "${fix_branch}" FETCH_HEAD
          if git rebase -q "$before"; then
            resumed=yes
          else
            # The old patch no longer applies: ${branch} moved under it, most
            # likely because the fix was merged or hand-fixed. Start clean
            # rather than hand the agent a conflicted tree.
            echo "==> previous ${fix_branch} no longer applies, starting fresh"
            git rebase --abort || true
            git checkout -q -B "${fix_branch}" "$before"
            resumed=no
          fi
        else
          git checkout -q -B "${fix_branch}" "$before"
          resumed=no
        fi

        # Put the run's lock back, so the agent reproduces the failure against
        # the same inputs the build used.
        cp "$workdir/flake.lock.new" flake.lock

        # Unquoted heredoc so the env vars reach the prompt verbatim.
        # No backticks and no command substitutions inside.
        agent_prompt="$(cat <<PROMPT
      You are "${agent_name}", a maintenance bot for the NixOS fleet config in the
      current working directory (a fresh clone of ${repo}, with an already-updated
      flake.lock). You are on branch ${fix_branch}, checked out from ${branch}.
      Previous attempt carried over: $resumed -- if yes, your own earlier commits
      are already here, so review them with "git log ${branch}..HEAD" and amend or
      extend them instead of starting over.

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
         Carrying a local patch for a package nobody here uses is usually worse
         than dropping the package: say so in the commit message if you drop one.
         Do NOT paper over the failure by disabling a host or deleting a feature
         that is actually in use.
      3. Verify EVERY one of these hosts still evaluates, not just the one you
         fixed: ${lib.concatStringsSep " " hosts}
         Use the nix eval command from step 1 for each. All must print a .drv path.
      4. If and only if all hosts evaluate, commit on the current branch:
           git add -- <the files you changed>
           git commit -m "<scope>: <what and why>"
         Stage the files you changed by name. Do NOT use "git add -A": it would
         pick up flake.lock and the result-* build symlinks, neither of which
         belongs in your commit.
         Explain in the commit message WHY the change was needed, citing the
         upstream change. Do not push: the calling script rebuilds the failing
         hosts on your commit and pushes the branch itself.
      5. If you cannot fix it, or cannot get all hosts to evaluate, commit
         nothing and explain what you found and what you ruled out.

      Never commit to ${branch}. Never touch flake.lock: the lock is this run's
      input and is committed separately only when every host builds.
      PROMPT
        )"

        # pi lives in the system profile, which is not on a service's PATH.
        # The model is pinned so the bot never depends on whatever model the
        # interactive user last selected.
        if ! ${agent_bin} --model ${lib.escapeShellArg agent_model} -p "$agent_prompt"; then
          notify high warning "${agent_name} errored while investigating:$broken_hosts"
          push_results || true
          exit 1
        fi

        # Trust the rebuild, not the agent's report: on 2026-10-04 it reported
        # "builds to completion" on a tree that had not been verified here.
        if git diff --quiet "$before" -- .; then
          notify high warning "${agent_name} could not fix:$broken_hosts; no change made"
          push_results || true
          exit 1
        fi

        echo "==> ${agent_name} patched the tree; rebuilding:$broken_hosts"
        build_hosts $broken_hosts

        if [ -n "$failed_hosts" ]; then
          echo "==> still failing after the repair:$failed_hosts"
          # Push the branch anyway: a partial fix is a useful starting point
          # for tomorrow's run and for a human reading the diff.
          git push -q --force-with-lease origin "HEAD:refs/heads/${fix_branch}"
          notify high warning \
            "${agent_name} fix incomplete, still failing:$failed_hosts -- see ${repo_url}/compare/${branch}...${fix_branch}"
          push_results || true
          exit 1
        fi

        # Every host builds on the patched tree. Push the branch for review and
        # keep going: the cache gets today's closures and ${branch} gets today's
        # lock, while the repo change itself waits for a human.
        git push -q --force-with-lease origin "HEAD:refs/heads/${fix_branch}"
        notify high wrench \
          "${agent_name} fixed:$broken_hosts -- open a PR at ${repo_url}/compare/${branch}...${fix_branch}?expand=1"

        # The lock commit must not carry the unreviewed fix with it. Go back to
        # the pristine ${branch} tree, drop in only the updated flake.lock, and
        # commit that. The closures just pushed were built *with* the fix, so
        # the hosts that needed it still rebuild locally until the PR lands --
        # the other hosts, the majority, get a warm cache either way.
        git checkout -q -B lock-update "$before"
        git checkout -q -- .
        cp "$workdir/flake.lock.new" flake.lock
      fi

      push_results

      if git diff --quiet "$before" -- flake.lock; then
        notify low package "lock unchanged, ${toString (builtins.length hosts)} hosts (re)pushed"
        exit 0
      fi

      git config user.name "nixos-cache-builder"
      git config user.email "nixos-cache-builder@desg0"
      git add flake.lock
      git commit -q -m "flake.lock: automated update $(date -I)" \
        -m "Built and pushed to the ${cache} cache for: ${lib.concatStringsSep ", " hosts}."
      # Fast-forward only: if someone pushed to ${branch} during the run, the
      # lock we built is no longer the lock they would get. Fail and let
      # tomorrow's run redo it against the new tip.
      if git push -q origin "HEAD:${branch}"; then
        notify low package "flake.lock updated to $(git rev-parse --short HEAD), ${toString (builtins.length hosts)} hosts pushed"
      else
        notify high warning "${branch} moved during the run; lock not committed, cache still pushed"
        exit 1
      fi
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
