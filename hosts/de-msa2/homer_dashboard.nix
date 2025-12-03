{config, ...}: let
  static_ips = import ../../modules/static_ips.nix;
  const = import ./constants.nix;
  const_elitedesk = import ../elitedesk/constants.nix;
  domain = "homer.homelab";
in {
  services = {
    # caddy = {
    #   enable = true;
    #   virtualHosts."${domain}" = {
    #     listenAddresses = [
    #       "${static_ips.elitedesk_ip}:80"
    #     ];
    #     extraConfig = ''
    #       tls internal
    #       handle {
    #               reverse_proxy 127.0.0.1:8080 {
    #                   flush_interval -1
    #           }
    #         }
    #     '';
    #   };
    # };
    homer = {
      enable = true;
      virtualHost = {
        nginx.enable = true;
        inherit domain;
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
                name = "Gitea";
                logo = "assets/tools/gitea.png";
                subtitle = "Git Server";
                tag = "app";
                keywords = "self hosted git";
                url = "http://${static_ips.elitedesk_ip}:${toString const.gitea_port}";
                target = "_blank";
              }
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
              {
                name = "GreptimeDB Dashboard";
                logo = "assets/tools/default.png";
                subtitle = "Dashboard for GreptimeDB";
                tag = "app";
                keywords = "self hosted dns";
                url = "http://${static_ips.desg0_ip}:${toString const.greptimedb_http_port}";
                target = "_blank";
              }
              {
                name = "Uptime Kuma";
                logo = "assets/tools/default.png";
                subtitle = "Uptime monitoring";
                tag = "app";
                keywords = "self hosted uptime";
                url = "http://${static_ips.elitedesk_ip}:${toString const.uptime_kuma_port}";
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
                url = "http://${static_ips.elitedesk_ip}:${toString const_elitedesk.jellyfin_port}";
                target = "_blank";
              }
              {
                name = "Bitmagnet";
                logo = "assets/tools/jellyfin.png";
                subtitle = "Torrent Discovery on DHT";
                tag = "app";
                keywords = "self hosted bitmagnes movies series video";
                url = "http://${static_ips.de-msa2_ip}:${toString const.bitmagnet_port}";
                target = "_blank";
              }
              {
                name = "FreshRss";
                logo = "assets/tools/freshrss.png";
                subtitle = "RSS aggregator";
                tag = "app";
                keywords = "self hosted rss";
                url = "http://${static_ips.elitedesk_ip}:${toString const.freshrss_port}";
                target = "_blank";
              }
            ];
          }
        ];
      };
    };
  };
}
