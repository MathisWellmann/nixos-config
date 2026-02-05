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
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.tikr.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/monero.nix
    ./../../modules/monero_miner.nix
    ./../../modules/adguardhome.nix
    ./../../modules/zfs_replication_service.nix
    ./../../modules/github_runner.nix
    ./freshrss.nix
    ./nexus_dbs.nix
    ./gitea.nix
    ./prometheus.nix
    ./homer_dashboard.nix
    ./zfs_pool.nix
    ./ups.nix
    searx
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
        command = "${pkgs.neofetch}/bin/neofetch";
      };
      filesystems = {
        root = "/";
        nvme_pool_magewe = "/nvme_pool/magewe";
        nvme_pool_ilka = "/nvme_pool/ilka";
        nvme_pool_gitea = "/nvme_pool/gitea";
        nvme_pool_mongodb = "/nvme_pool/mongodb";
        nvme_pool_greptimedb = "/nvme_pool/greptimedb";
        nvme_pool_music = "/nvme_pool/music";
        nvme_pool_pdfs = "/nvme_pool/pdfs";
        nvme_pool_video = "/nvme_pool/video";
      };
      service_status = {
        tailscale = "tailscaled";
        prometheus = "prometheus";
        prometheus-exporter = "prometheus-node-exporter";
        victoriametrics = "victoriametrics";
        grafana = "grafana";
        adguardhome = "adguardhome";
        jellyfin = "jellyfin";
        nfs-server = "nfs-server";
        monero = "monero";
        monero_miner = "xmrig";
        bitmagnet = "bitmagnet";
        greptime_db = "podman-greptimedb";
        dragonfly_db = "podman-dragonfly";
        # tikr_BinanceCoinMargin_L2OrderBookDelta = "tikr@BinanceCoinMargin_L2OrderBookDelta";
        tikr_BinanceCoinMargin_Quotes = "tikr@BinanceCoinMargin_Quotes";
        tikr_BinanceCoinMargin_Trades = "tikr@BinanceCoinMargin_Trades";
        # tikr_BinanceUsdMargin_L2OrderBookDelta = "tikr@BinanceUsdMargin_L2OrderBookDelta";
        tikr_BinanceUsdMargin_Quotes = "tikr@BinanceUsdMargin_Quotes";
        tikr_BinanceUsdMargin_Trades = "tikr@BinanceUsdMargin_Trades";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    const.iperf_port
  ];

  services = {
    tikr = {
      enable = true;
      database = "GreptimeDb";
      database-addr = "localhost:4001";
      exchanges = ["BinanceUsdMargin" "BinanceCoinMargin"];
      data-types = ["AggTrades" "Quotes"];
      prometheus_exporter_base_port = const.tikr_base_port;
    };
    grafana = {
      enable = true;
      settings = {
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
    bitmagnet = {
      enable = true;
      openFirewall = true;
      settings = {
        http_server.port = "${builtins.toString const.bitmagnet_port}";
      };
    };
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
}
