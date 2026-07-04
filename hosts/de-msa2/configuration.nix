# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  global_const = import ../../global_constants.nix;
  const = import ./constants.nix {};
  searx = import ./../../modules/searx.nix {port = const.searx_port;};
  readeck = import ./readeck.nix {
    dir = "/nvme_pool/readeck";
    port = const.readeck_port;
  };
  polaris = import ./../../modules/music_polaris.nix {
    port = const.polaris_port;
    mount_dirs = [
      {
        name = "music";
        source = "/nvme_pool/music";
      }
    ];
  };
  calibre-web = import ./../../modules/calibre_web.nix {port = const.calibre-web_port;};
  mealie = import ./../../modules/mealie.nix {
    port = const.mealie_port;
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/user_m.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/monero.nix
    ./../../modules/k3s_init.nix
    ./../../modules/ai/local_ai.nix
    (import ./../../modules/github_runner.nix {
      repos = ["lfest-rs" "sliding_features-rs" "trade_aggregation-rs" "openresponses-rs"];
    }) # Don't run much load on this host. TODO: move to desg0
    (import ./../../modules/ai/pi-agent.nix {
      baseUrl = "http://meshify:8001/v1";
      enableAgentica = true;
    })
    # ./freshrss.nix
    ./nexus_dbs.nix
    ./forgejo.nix
    ./bencher.nix
    ./prometheus.nix
    ./alerting.nix
    ./zfs_pool.nix
    ./harmonia.nix
    # ./ups.nix
    searx
    # (import ./../../modules/monero_miner.nix {max-threads-hint = 25;})
    readeck
    polaris
    calibre-web
    mealie
  ];

  networking.hostName = "de-msa2"; # Define your hostname.

  # Home manger can silently fail to do its job, so check with `systemctl status home-manager-m`
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  programs.rust-motd = {
    enable = true;
    settings = {
      banner = {
        color = "black";
        command = "${pkgs.fastfetch}/bin/fastfetch";
      };
      filesystems = {
        root = "/";
        nvme_pool_magewe = "/nvme_pool/magewe";
        nvme_pool_ilka = "/nvme_pool/ilka";
        nvme_pool_forgejo = "/nvme_pool/forgejo";
        nvme_pool_mongodb = "/nvme_pool/mongodb";
        nvme_pool_greptimedb = "/nvme_pool/greptimedb";
        nvme_pool_music = "/nvme_pool/music";
        nvme_pool_pdfs = "/nvme_pool/pdfs";
        nvme_pool_video = "/nvme_pool/video";
      };
      service_status = {
        tailscale = "tailscaled";
        forgejo = "forgejo";
        forgejo_runner = "gitea-runner-default";
        prometheus-node-exporter = "prometheus-node-exporter";
        victoriametrics = "victoriametrics";
        victorialogs = "victorialogs";
        grafana = "grafana";
        nfs-server = "nfs-server";
        monero = "monero";
        monero_miner = "xmrig";
        bitmagnet = "bitmagnet";
        dragonfly_db = "podman-dragonfly";
        github-runner-lfest-rs = "github-runner-de-msa2-lfest-rs";
        github-runner-trade_aggregation-rs = "github-runner-de-msa2-trade_aggregation-rs";
        github-runner-openresponses-rs = "github-runner-de-msa2-openresponses-rs";
        github-runner-sliding_features-rs = "github-runner-de-msa2-sliding_features-rs";
        bencher-ui = "podman-bencher-ui";
        bencher-api = "podman-bencher-api";
        readeck = "podman-readeck";
        polaris = "polaris";
        calibre-web = "calibre-web";
        mealie = "mealie";
        immich = "immich-server";
        k3s = "k3s";
        ntfy-sh = "ntfy-sh";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    const.iperf_port
    const.habit_trove_port
  ];

  services = {
    grafana = {
      enable = true;
      settings = {
        security.secret_key = "/etc/secrets/grafana";
        server = {
          # Exposed off-cluster at https://grafana.k3s.lan through the k3s
          # traefik ingress (see env/host_ingress.nix); fleet-trusted
          # `k3s-lan-ca` cert. `root_url` makes the UI emit correct links.
          http_addr = "0.0.0.0";
          http_port = const.grafana_port;
          root_url = "https://grafana.k3s.lan/";
          serve_from_sub_path = false;
        };
      };
      # Declarative (repo-tracked) provisioning: the VictoriaMetrics datasource
      # and the dashboards under `./dashboards`. Provisioned objects are managed
      # by these files (matched by `uid`), so they are recreated on every
      # `nixos-rebuild switch` and cannot be permanently edited in the UI --
      # edits must land in the repo. Coexists with any datasources/dashboards
      # added manually through the UI (those have different uids).
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              # Referenced by dashboards via the `${datasource}` variable, and
              # by this fixed `uid` so dashboard JSON is portable across
              # rebuilds. Same VictoriaMetrics endpoint the vmalert/alerting
              # stack uses (hosts/de-msa2/alerting.nix). VM speaks the
              # Prometheus query API, so `type = "prometheus"`.
              name = "VictoriaMetrics";
              uid = "victoriametrics";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString const.victoriametrics_port}";
              isDefault = true;
              jsonData.timeInterval = "5s";
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "repo-dashboards";
              type = "file";
              # Keep the sidebar organized; matches the "tikr" tag on the CH
              # dashboard. Grafana creates the folder on first load.
              folder = "tikr";
              # `foldersFromFilesStructure` would mirror subdirs as folders;
              # a single flat folder is enough here.
              options.path = ./dashboards;
              # Allow the provider to update dashboards in place on rebuild.
              allowUiUpdates = false;
              disableDeletion = false;
            }
          ];
        };
      };
    };
    uptime-kuma = {
      enable = true;
      settings = {
        UPTIME_KUMA_HOST = "0.0.0.0";
        PORT = "${builtins.toString const.uptime_kuma_port}";
      };
    };
    # bitmagnet = {
    #   enable = true;
    #   openFirewall = true;
    #   settings = {
    #     http_server.port = "${builtins.toString const.bitmagnet_port}";
    #   };
    # };
    minidlna = {
      enable = true;
      openFirewall = true;
      settings = {
        friendly_name = "mathis_music";
        media_dir = ["/nvme_pool/music"];
        inotify = "yes";
        port = const.minidlna_port;
      };
    };
    # its a todo list app.
    vikunja = {
      enable = true;
      port = const.vikunja_port;
      # Exposed off-cluster at https://vikunja.k3s.lan through the k3s traefik
      # ingress (see env/host_ingress.nix); fleet-trusted `k3s-lan-ca` cert.
      frontendScheme = "https";
      frontendHostname = "vikunja.k3s.lan";
    };
    immich = {
      enable = true;
      host = "0.0.0.0";
      mediaLocation = "/nvme_pool/immich";
      openFirewall = true;
      port = const.immich_port;
    };
  };

  virtualisation.oci-containers.containers = {
    "HabitTrove" = {
      image = "dohsimpson/habittrove:latest";
      ports = [
        "${builtins.toString const.habit_trove_port}:3000"
      ];
      volumes = [
        "/nvme_pool/habit_trove:/app/data"
      ];
      environmentFiles = [
        /etc/secrets/habit_trove
      ];
    };
  };
}
