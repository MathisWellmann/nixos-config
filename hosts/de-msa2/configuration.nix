# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  global_const = import ../../global_constants.nix;
  const = import ./constants.nix;
  searx = import ./../../modules/searx.nix {port = const.searx_port;};
  monero_miner = import ./../../modules/monero_miner.nix {max-threads-hint = 25;};
  readeck = import ./readeck.nix {
    dir = "/nvme_pool/readeck";
    port = const.readeck_port;
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/monero.nix
    ./../../modules/zfs_replication_service.nix
    ./../../modules/github_runner.nix # Don't run much load on this host. TODO: move to desg0
    # ./freshrss.nix
    ./nexus_dbs.nix
    ./forgejo.nix
    ./prometheus.nix
    ./zfs_pool.nix
    ./harmonia.nix
    ./homepage.nix
    # ./ups.nix
    searx
    monero_miner
    readeck
  ];

  networking.hostName = "de-msa2"; # Define your hostname.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${global_const.username}" = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      git
      helix
      claude-code
    ];
  };

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
        grafana = "grafana";
        nfs-server = "nfs-server";
        monero = "monero";
        monero_miner = "xmrig";
        bitmagnet = "bitmagnet";
        greptime_db = "podman-greptimedb";
        dragonfly_db = "podman-dragonfly";
        tikr_BinanceCoinSpot_Quotes = "tikr@BinanceSpot_Quotes";
        tikr_BinanceCoinSpot_Trade = "tikr@BinanceSpot_Trade";
        tikr_BinanceCoinMargin_Quotes = "tikr@BinanceCoinMargin_Quotes";
        tikr_BinanceCoinMargin_Trade = "tikr@BinanceCoinMargin_Trade";
        tikr_BinanceUsdMargin_Quotes = "tikr@BinanceUsdMargin_Quotes";
        tikr_BinanceUsdMargin_Trade = "tikr@BinanceUsdMargin_Trade";
        github-runner-lfest-rs = "github-runner-de-msa2-lfest-rs";
        github-runner-trade_aggregation-rs = "github-runner-de-msa2-trade_aggregation-rs";
        github-runner-openresponses-rs = "github-runner-de-msa2-openresponses-rs";
        github-runner-sliding_features-rs = "github-runner-de-msa2-sliding_features-rs";
        bencher-ui = "podman-bencher-ui";
        bencher-api = "podman-bencher-api";
        iggy-server = "iggy-server";
        readeck = "podman-readeck";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    const.iperf_port
    const.habit_trove_port
    const.bencher_ui_port
    const.bencher_api_port
  ];

  services = {
    grafana = {
      enable = true;
      settings = {
        security.secret_key = "/etc/secrets/grafana";
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = const.grafana_port;
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
      frontendScheme = "http";
      frontendHostname = "0.0.0.0";
    };
    # mealie = {
    #   enable = true;
    #   port = const.mealie_port;
    # };
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
    "bencher-api" = {
      image = "ghcr.io/bencherdev/bencher-api:latest";
      ports = [
        "${toString const.bencher_api_port}:3000"
      ];
      volumes = [
        "/nvme_pool/bencher/config:/etc/bencher" # Config dir
        "/nvme_pool/bencher/data:/var/lib/bencher/data" # Data dir
      ];
    };
    "bencher-ui" = {
      image = "ghcr.io/bencherdev/bencher-console:latest";
      ports = [
        "${toString const.bencher_ui_port}:3000"
      ];
      environment = {
        BENCHER_API_URL = "http://127.0.0.1:${toString const.bencher_api_port}";
        INTERNAL_API_URL = "http://host.podman.internal:${toString const.bencher_api_port}";
      };
    };
  };
}
