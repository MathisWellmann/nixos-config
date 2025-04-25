{pkgs, ...}: let
  const = import ./constants.nix;
  const_meshify = import ./../meshify/constants.nix;
  static_ips = import ./../../modules/static_ips.nix;
in{
  virtualisation.oci-containers.containers."mafl" = let
    # Write mafl config.
    mafl_config = ''
      title: Dashboard of MGW
      lang: en
      theme: dark
      checkUpdates: true
      tags:
        - name: media
          color: green
        - name: development
          color: orange
        - name: observability
          color: blue
        - name: ai
          color: pink
        - name: finance
          color: teal
      services:
        - title: LocalAI
          description: open-webui frontend for self hosted LLMs using ollama, hosted on `meshify`.
          link: http://${static_ips.meshify_ip}:${builtins.toString const_meshify.open_webui_port}
          tags:
            - ai
        - title: Jellyfin
          description: Movies and Series
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.jellyfin_port}
          icon:
            url: https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fi.redd.it%2Fuybguvnj1p821.png&f=1&nofb=1&ipt=b317f7cc53b5d1b35a5e26f5cd58f7c8dbc72861b640c515e628bb3f41be1b25&ipo=images
          tags:
            - media
        - title: Polaris
          description: Music library
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.polaris_port}
          tags:
            - media
        - title: Bitmagnet
          description: DHT Torrent Tracker
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.bitmagnet_port}
          tags:
            - media
        - title: Gitea
          description: My Git Server
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.gitea_port}
          tags:
            - development
        - title: Grafana
          description: Server Monitoring Dashboard
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.grafana_port}
          tags:
            - obserservability
        - title: Readeck
          description: Bookmarks
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.readeck_port}
          tags:
            - media
        - title: Mealie
          description: Recipes
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.mealie_port}
        - title: Immich
          description: Photo hosting
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.immich_port}
          tags:
            - media
        - title: Photoprism
          description: AI-powered Photo App
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.photoprism_port}
          tags:
            - media
        - title: Calibre
          description: E-books and pdfs
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.calibre_port}
          tags:
            - media
        - title: UptimeKuma
          description: Check uptime of my websites
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.uptime_kuma_port}
          tags:
            - observability
        - title: SearXNG
          description: Local meta search engine
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.searx_port};
        - title: FreshRSS
          description: RSS Feed reader
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.freshrss_port};
          tags:
            - media
        - title: Firefly-III
          description: Personal Finance Manager
          link: http://${static_ips.poweredge_ip}:${builtins.toString const.firefly_port};
          tags:
            - finaance
    '';
    config_file = pkgs.writeText "/SATA_SSD_POOL/mafl/config.yml" mafl_config;
  in {
    image = "hywax/mafl";
    ports = [
      "${builtins.toString const.mafl_port}:3000"
    ];
    volumes = [
      "${config_file}:/app/data/config.yml"
    ];
  };
}
