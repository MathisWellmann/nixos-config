# DeepSeek Harness (`dsh web`) web UI, always on.
#
# `dsh web` hard-binds to 127.0.0.1:3080 -- its config schema only accepts
# 127.0.0.1 or 0.0.0.0. The dsh-web-proxy forwarder exposes it on the tailnet
# IP below, and the k3s traefik ingress routes dsh.k3s.lan to it
# (manifests/prod/dsh/). Keep the tailnet IP in sync with
# EndpointSlice-dsh.yaml.
#
# dsh-web starts after home-manager-m.service because the home activation
# writes $DSH_HOME/.env (see home/deepseek-harness.nix `dotenv`) and the
# ~/.dsh/sessions -> /var/lib/monty-persona/sessions symlink.
{ inputs, pkgs, ... }:
let
  # Same package the user profile installs: the llm-agents `dsh` with
  # NODE_PATH wrapped, so plugin bundles resolve their core deps.
  dsh = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
in
{
  systemd.services = {
    dsh-web = {
      description = "DeepSeek Harness web UI (dsh web)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "tailscaled.service" "home-manager-m.service" ];
      wants = [ "network-online.target" "home-manager-m.service" ];
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
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "tailscaled.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart =
          "${pkgs.socat}/bin/socat TCP-LISTEN:3080,bind=100.83.142.17,reuseaddr,fork TCP:127.0.0.1:3080";
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
  networking.firewall.allowedTCPPorts = [ 3080 ];
}
