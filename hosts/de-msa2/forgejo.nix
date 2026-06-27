_: let
  const = import ./constants.nix {};
in {
  networking.firewall.allowedTCPPorts = [
    const.forgejo_port
  ];
  services = {
    forgejo = {
      enable = true;
      # Support Git Large File Storage
      lfs.enable = true;
      stateDir = "/nvme_pool/forgejo";
      settings = {
        server = {
          # Exposed off-cluster at https://forgejo.k3s.lan through the k3s
          # traefik ingress (see env/host_ingress.nix); fleet-trusted
          # `k3s-lan-ca` cert. The firewall port stays open as a plain-HTTP
          # fallback.
          DOMAIN = "forgejo.k3s.lan";
          ROOT_URL = "https://forgejo.k3s.lan/";
          HTTP_PORT = const.forgejo_port;
        };
        service.DISABLE_REGISTRATION = true; # Only my user for now
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
      };
    };
  };
}
