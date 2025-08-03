{pkgs, config, ...}: let
  const = import ./constants.nix;
  global_const = import ../../global_constants.nix;
  static_ips = import ../../modules/static_ips.nix;
  in {
  services = {
    gitea = {
      enable = true;
      appName = "MW-Trading-Systems";
      repositoryRoot = "${const.gitea_state_dir}/repository_root";
      user = "${global_const.username}";
      settings = {
        server = {
          HTTP_PORT = const.gitea_port;
          ROOT_URL = "http://${toString static_ips.elitedesk_ip}:${toString const.gitea_port}";
        };
        mailer = {
          ENABLED = true;
          MAILER_TYPE = "sendmail";
          FROM = "gitea@mwtradingsystems.com";
          SENDMAIL_PATH = "${pkgs.system-sendmail}/bin/sendmail";
        };
      };
      stateDir = "${const.gitea_state_dir}";
    };
    gitea-actions-runner.instances.${config.networking.hostName} = {
      enable = true;
      name = "${config.networking.hostName}";
      labels = [
        "nixos"
        "poweredge"
      ];
      # put in `TOKEN= ...` with the token
      tokenFile = /var/secrets/gitea-actions-runner;
      url = config.services.gitea.settings.server.ROOT_URL;
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        nodejs
        wget
        nix
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [
    const.gitea_port
  ];
}
