# `dsh web` (DeepSeek Harness) hard-binds to 127.0.0.1:3080 -- its config
# schema only accepts 127.0.0.1 or 0.0.0.0. This forwarder exposes it on the
# tailnet IP so the k3s traefik ingress can route dsh.k3s.lan to it.
# Keep the tailnet IP in sync with manifests/prod/dsh/EndpointSlice-dsh.yaml.
{ pkgs, ... }: {
  systemd.services.dsh-web-proxy = {
    description = "Forward 100.83.142.17:3080 -> 127.0.0.1:3080 (dsh web)";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:3080,bind=100.83.142.17,reuseaddr,fork TCP:127.0.0.1:3080";
      NoNewPrivileges = true;
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
      Restart = "on-failure";
    };
  };

  # Only reachable via the tailnet, not the LAN.
  networking.firewall.allowedTCPPortsInterfaces = {
    "tailscale0" = [ 3080 ];
  };
}
