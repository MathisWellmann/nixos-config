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
# One-time setup (secrets/secrets.nix has the recipients):
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
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  user = "nixos-cache-builder";
  state_dir = "/var/lib/${user}";
  ntfy_url = "https://ntfy.k3s.lan/cluster-alerts";
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

      git clone -q --depth 1 --branch ${branch} ${repo} repo
      cd repo
      before="$(git rev-parse HEAD)"

      nix flake update --accept-flake-config
      if git diff --quiet flake.lock; then
        echo "flake.lock unchanged since $before; still building in case the cache lags behind"
      fi

      # gc roots under $workdir keep the closures alive until the push is
      # done; they go away with the workdir.
      for host in ${lib.escapeShellArgs hosts}; do
        echo "==> building $host"
        nix build --accept-flake-config --no-update-lock-file \
          --out-link "result-$host" \
          ".#nixosConfigurations.$host.config.system.build.toplevel"
      done

      echo "==> pushing to ${cache}"
      attic push ${cache} result-*

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
