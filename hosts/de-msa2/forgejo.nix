_: let
  const = import ./constants.nix;
  # srv = config.services.forgejo.setings.server;
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
          # DOMAIN = "mwtradingsystems.com";
          # ROOT_URL = "https://${srv.DOMAIN}";
          HTTP_PORT = const.forgejo_port;
        };
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
      };
    };
  };
}
