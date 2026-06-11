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
          # DOMAIN = "mwtradingsystems.com";
          # ROOT_URL = "https://${srv.DOMAIN}";
          DOMAIN = "de-msa2";
          # Without an explicit ROOT_URL forgejo derives `http://localhost:2999`,
          # which breaks the container registry token flow (clients get redirected
          # to localhost) and the clone URLs shown in the UI.
          ROOT_URL = "http://de-msa2:${toString const.forgejo_port}/";
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
