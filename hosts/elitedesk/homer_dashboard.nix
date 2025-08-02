{config, ...}: let
  static_ips = import ../../modules/static_ips.nix;
  const = import ./constants.nix;
  domain = "homer.homelab";
in {
  services = {
    caddy = {
      enable = true;
      virtualHosts."${domain}" = {
        listenAddresses = [
          "${static_ips.elitedesk_ip}:80"
        ];
        extraConfig = ''
          tls internal
          handle {
                  reverse_proxy 127.0.0.1:8080 {
                      flush_interval -1
              }
            }
        '';
      };
    };
    homer = {
      enable = true;
      virtualHost = {
        nginx.enable = true;
        domain = domain;
      };
      settings = {
        title = "Dashboard of MGW";
        header = true;
        defaults = {
          layout = "columns";
          colorTheme = "auto";
        };
        theme = "default";
        links = [
          {
            name = "Github";
            icon = "fab fa-github";
            url = "https://github.com/";
            target = "_blank";
          }
        ];
        services = [
          # Group
          {
            name = "Homelab Observability";
            icon = "fas fa-code-branch";
            items = [
              # Service in that group
              {
                name = "Grafana";
                logo = "assets/tools/grafana.png";
                subtitle = "Server observability";
                tag = "app";
                keywords = "self hosted grafana";
                url = "http://${static_ips.elitedesk_ip}:${toString const.grafana_port}";
                target = "_blank";
              }
              {
                name = "AdguardHome";
                logo = "assets/tools/adguardhome.png";
                subtitle = "DNS with ad blocking";
                tag = "app";
                keywords = "self hosted dns";
                url = "http://${static_ips.elitedesk_ip}:${toString config.services.adguardhome.port}";
                target = "_blank";
              }
            ];
          }
          {
            name = "Media";
            icon = "fas fa-code-branch";
            subtitle = "Movies Series Video Music";
            items = [
              {
                name = "Jellyfin";
                logo = "assets/tools/jellyfin.png";
                subtitle = "Media Streaming";
                tag = "app";
                keywords = "self hosted jellyfin movies series video";
                url = "http://${static_ips.elitedesk_ip}:${toString const.jellyfin_port}";
                target = "_blank";
              }
            ];
          }
        ];
      };
    };
  };
}
