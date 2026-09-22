# DeepSeek Harness (`dsh web`) web UI, always on.
#
# `dsh web` hard-binds to 127.0.0.1:3080 -- its config schema only accepts
# 127.0.0.1 or 0.0.0.0. The dsh-web-proxy forwarder exposes it on the tailnet
# IP below, and the k3s traefik ingress routes dsh.k3s.lan to it (the `dsh`
# entry in env/host_ingress.nix; its `hostIp` default is this tailnet IP).
#
# dsh-web starts after home-manager-m.service because the home activation
# writes $DSH_HOME/.env (see home/deepseek-harness.nix `dotenv`) and the
# ~/.dsh/sessions -> /var/lib/monty-persona/sessions symlink.
#
# That shared sessions root is also written by the monty-persona service. At
# boot dsh enumerates every session dir and reads the first zstd frame of the
# newest `session*.jsonl.zstd`; it must be exactly one header line, or dsh
# dies with "corrupt Zstandard session log" and the unit crash-loops (traefik
# then answers 502). Early monty-persona logs (unversioned
# `session.jsonl.zstd`, Sept 2026) were rewritten as a single frame and trip
# this. Fix: move the offending session dir out of the root, e.g. into
# /var/lib/monty-persona/sessions-quarantine/ (done 2026-09-22 for four
# `jeff-17894*`/`jeff-1789560491603` dirs), then `systemctl restart dsh-web`.
# Find offenders with `journalctl -u dsh-web` (the path is not logged; use
# `zstd -l` frame counts: a legacy log with 1 frame is always bad).
{
  inputs,
  pkgs,
  ...
}: let
  # Same package the user profile installs: the llm-agents `dsh` with
  # NODE_PATH wrapped, so plugin bundles resolve their core deps.
  dsh = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
in {
  systemd.services = {
    dsh-web = {
      description = "DeepSeek Harness web UI (dsh web)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "tailscaled.service" "home-manager-m.service"];
      wants = ["network-online.target" "home-manager-m.service"];
      serviceConfig = {
        User = "m";
        ExecStart = "${dsh}/bin/dsh web --no-open --trusted-host dsh.k3s.lan";
        Restart = "always";
        RestartSec = "5s";
        # It's the user's agent harness: it spawns subprocesses and writes
        # its state under /home/m/.dsh, so keep the sandboxing light.
        NoNewPrivileges = true;
        PrivateTmp = true;
        # NixOS's default service PATH (coreutils/findutils/grep/sed/systemd
        # store paths only) has no `bash` and no `bwrap`: under it the dsh
        # bash tool cannot spawn a shell and both Linux sandbox backends
        # probe unusable (the Landlock launcher's probe child is a bare
        # name, too). Use the system environment plus bubblewrap, DSH's
        # preferred Linux sandbox backend.
        Environment = [
          "PATH=/run/current-system/sw/bin:${pkgs.bubblewrap}/bin:${pkgs.systemd}/bin"
        ];
      };
    };

    dsh-web-proxy = {
      description = "Forward 100.83.142.17:3080 -> 127.0.0.1:3080 (dsh web)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "tailscaled.service"];
      wants = ["network-online.target"];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:3080,bind=100.83.142.17,reuseaddr,fork TCP:127.0.0.1:3080";
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = true;
        Restart = "on-failure";
      };
    };
  };

  # The socat socket only binds the tailnet IP, so nothing answers on the LAN
  # -- the hole just covers tailnet -> 100.83.142.17:3080.
  networking.firewall.allowedTCPPorts = [3080];
}
