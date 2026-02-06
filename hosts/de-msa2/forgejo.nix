{
  pkgs,
  config,
  ...
}: let
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
        service.DISABLE_REGISTRATION = true; # Only my user for now
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
      };
    };
    gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.default = {
        enable = true;
        name = "${config.networking.hostName}";
        url = "http://localhost:${toString const.forgejo_port}";
        # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
        tokenFile = "/run/secrets/forgejo_runner";
        labels = [
          # Provide native execution on the host.
          "native:host"
        ];
        hostPackages = with pkgs; [
          nix
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          nodejs
          wget
        ];
        settings = {
          # Execute this many tasks concurrently at the same time.
          runner.capacity = 4;
          cache.dir = "/nvme_pool/forgejo-runner/cache";
          host.workdir_parent = "/nvme_pool/forgejo-runner/";
        };
      };
    };
  };
  # Ensure systemd allows writing to that ZFS directory.
  systemd.services.gitea-runner-default.serviceConfig.ReadWritePaths = [
    "/nvme_pool/forgejo-runner"
  ];
}
