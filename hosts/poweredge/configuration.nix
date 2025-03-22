# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  lib,
  pkgs,
  inputs,
  config,
  ...
}: let
  username = "magewe";
  backup_host = "elitedesk";
  backup_target_dir = "/mnt/backup_hdd";
  tikr_base_port = 9184;
  mongodb_port = 27017;
  jellyfin_port = 8096;
  gitea_port = 3000;
  gitea_state_dir = "/var/lib/gitea";
  grafana_port = 3001;
  mafl_port = 3002;
  homer_port = 3003;
  readeck_port = 3004;
  mealie_port = 3005;
  gotosocial_port = 3006;
  immich_port = 3007;
  photoprism_port = 3008;
  bitmagnet_port = 3009;
  polaris_port = 3010;
  calibre_port = 3011;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/monero.nix
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${username}" = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["wheel"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      cloudflared
    ];
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${username}" = import ./../../home/home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  boot.supportedFilesystems = ["zfs"];
  boot.zfs = {
    forceImportRoot = false;
    extraPools = ["SATA_SSD_POOL"];
  };
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    trim.enable = false;
  };

  networking = {
    hostName = "poweredge"; # Define your hostname.
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "d198feeb";
    firewall.allowedTCPPorts = [
      2049 # nfs
      4000 # Greptimedb
      4001 # Greptimedb
      4003 # Greptimedb
      gitea_port
      grafana_port
      mafl_port
      homer_port
      mealie_port
      mongodb_port # Mongodb
    ];
    # For containers to access the internet.
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"]; # All container interfaces that need internet access.
      externalInterface = "eno1";
    };
  };

  services = {
    nfs.server = let
      # Using ip of mellanox 100G NIC. would be cool if tailscale would use that route, but that a future todo.
      genoa_addr = "169.254.79.94";
      genoa_subnet = "16";
      meshify_addr = "meshify";
      razerblade_addr = "razerblade";
      common_dirs = [
        "video"
        "music"
        "series"
        "movies"
        "magewe"
        "torrents_transmission"
        "pdfs"
      ];
      exports_for_genoa =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${genoa_addr}/${genoa_subnet}(rw,sync,no_subtree_check)\n")
        (common_dirs
          ++ ["backup_genoa" "ilka"]);
      exports_for_meshify =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${meshify_addr}(rw,sync,no_subtree_check)\n")
        (common_dirs
          ++ ["backup_meshify"]);
      exports_for_razerblade =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${razerblade_addr}(rw,sync,no_subtree_check)\n")
        (common_dirs
          ++ ["backup_razerblade"]);
    in {
      enable = true;
      exports = lib.strings.concatStrings [exports_for_genoa exports_for_meshify exports_for_razerblade];
    };
    prometheus = let
      node_scrape_configs = map (host: {
        job_name = "${host}-node";
        static_configs = [
          {
            targets = ["${host}:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }) ["127.0.0.1" "genoa" "meshify" "superserver" "elitedesk" "razerblade"];
      n_tikr_services =
        builtins.length config.services.tikr.exchanges
        + builtins.length config.services.tikr.data-types;
      tikr_max_port = tikr_base_port + n_tikr_services;
      tikr_ports = lib.range tikr_base_port tikr_max_port;
      tikr_scrape_configs =
        map (local_tikr_port: {
          job_name = "tikr-${toString local_tikr_port}";
          static_configs = [
            {
              targets = ["127.0.0.1:${toString local_tikr_port}"];
            }
          ];
        })
        tikr_ports;
    in {
      enable = true;
      listenAddress = "0.0.0.0";
      retentionTime = "30d";
      port = 9001;
      exporters = {
        node = {
          enable = true;
          port = 9002;
          enabledCollectors = ["systemd"];
        };
        zfs = {
          enable = true;
          port = 9134;
        };
        postgres = {
          enable = true;
          dataSourceName = "username=postgres dbname=public host=localhost port=4003 sslmode=disable";
          port = 9215;
        };
        mongodb = {
          enable = true;
          collectAll = true;
          uri = "mongodb://localhost:${toString mongodb_port}";
          port = 9216;
        };
        restic = {
          enable = true;
          port = 9753;
          repository = config.services.restic.backups.zfs_sata_ssd_pool.repository;
          passwordFile = "/etc/nixos/secrets/restic/password";
        };
      };
      scrapeConfigs =
        node_scrape_configs
        ++ tikr_scrape_configs
        ++ [
          {
            job_name = "postgres-greptimedb";
            static_configs = [
              {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}"];}
            ];
          }
          {
            job_name = "zfs";
            static_configs = [
              {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}"];}
            ];
          }
          {
            job_name = "mongodb";
            static_configs = [
              {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.mongodb.port}"];}
            ];
          }
          {
            job_name = "restic";
            static_configs = [
              {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.restic.port}"];}
            ];
          }
        ];
    };
    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = grafana_port;
        };
      };
    };
    jellyfin = {
      # Runs on port 8096
      enable = true;
      openFirewall = true;
    };
  };

  # Containers
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
      services:
        - title: Jellyfin
          description: Movies and Series
          link: http://poweredge:${builtins.toString jellyfin_port}
          icon:
            url: https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fi.redd.it%2Fuybguvnj1p821.png&f=1&nofb=1&ipt=b317f7cc53b5d1b35a5e26f5cd58f7c8dbc72861b640c515e628bb3f41be1b25&ipo=images
          tags:
            - media
        - title: Polaris
          description: Music library
          link: http://poweredge:${builtins.toString polaris_port}
          tags:
            - media
        - title: Bitmagnet
          description: DHT Torrent Tracker
          link: http://poweredge:${builtins.toString bitmagnet_port}
          tags:
            - media
        - title: Gitea
          description: My Git Server
          link: http://poweredge:${builtins.toString gitea_port}
          tags:
            - development
        - title: Grafana
          description: Server Monitoring Dashboard
          link: http://poweredge:${builtins.toString grafana_port}
          tags:
            - development
        - title: Readeck
          description: Bookmarks
          link: http://poweredge:${builtins.toString readeck_port}
          tags:
            - media
        - title: Mealie
          description: Recipes
          link: http://poweredge:${builtins.toString mealie_port}
        - title: Immich
          description: Photo hosting
          link: http://poweredge:${builtins.toString immich_port}
          tags:
            - media
        - title: Photoprism
          description: AI-powered Photo App
          link: http://poweredge:${builtins.toString photoprism_port}
          tags:
            - media
        - title: Calibre
          description: E-books and pdfs
          link: http://poweredge:${builtins.toString calibre_port}
          tags:
            - media
    '';
    config_file = pkgs.writeText "/SATA_SSD_POOL/mafl/config.yml" mafl_config;
  in {
    image = "hywax/mafl";
    ports = [
      "${builtins.toString mafl_port}:3000"
    ];
    volumes = [
      "${config_file}:/app/data/config.yml"
    ];
  };

  virtualisation.oci-containers.containers."homer" = {
    image = "b4bz/homer";
    ports = [
      "${builtins.toString homer_port}:8080"
    ];
    volumes = [
      "/SATA_SSD_POOL/homer:/www/assets"
    ];
  };

  virtualisation.oci-containers.containers."readeck" = {
    image = "codeberg.org/readeck/readeck:latest";
    ports = [
      "${builtins.toString readeck_port}:8000"
    ];
    volumes = [
      "/SATA_SSD_POOL/readeck:/readeck"
    ];
  };

  virtualisation.oci-containers.containers."greptimedb" = let
    version = "v0.9.3";
  in {
    image = "greptime/greptimedb:${version}";
    cmd = [
      "standalone"
      "start"
      "--http-addr"
      "0.0.0.0:4000"
      "--rpc-addr"
      "0.0.0.0:4001"
      "--mysql-addr"
      "0.0.0.0:4002"
      "--postgres-addr"
      "0.0.0.0:4003"
    ];
    ports = [
      "4000:4000"
      "4001:4001"
      "4002:4002"
      "4003:4003"
    ];
    volumes = [
      "/SATA_SSD_POOL/greptimedb:/tmp/greptimedb"
    ];
  };

  ### Backup Section ###
  fileSystems."/mnt/${backup_host}_backup" = {
    device = "${backup_host}:${backup_target_dir}";
    fsType = "nfs";
    options = ["rw" "rsize=131072" "wsize=131072"];
  };
  services.restic.backups = {
    zfs_sata_ssd_pool = {
      initialize = true;
      paths = [
        "/SATA_SSD_POOL/*"
        "${gitea_state_dir}"
      ];
      passwordFile = "/etc/nixos/secrets/restic/password";
      repository = "/mnt/${backup_host}_backup/restic/SATA_SSD_POOL";
      pruneOpts = ["--keep-daily 14"];
      user = "${username}";
    };
  };
  environment.systemPackages = with pkgs; [
    restic
    gitea
    radicle-node
  ];

  services.tikr = {
    enable = true;
    database = "GreptimeDb";
    database-addr = "poweredge:4001";
    exchanges = ["BinanceUsdMargin" "BinanceCoinMargin"];
    data-types = ["Trades" "Quotes" "L2OrderBookDelta"];
    prometheus_exporter_base_port = tikr_base_port;
  };

  # Music server
  # services.minidlna = {
  #   enable = true;
  #   openFirewall = true;
  #   settings = {
  #     friendly_name = "poweredge_music_server";
  #     media_dir = ["/SATA_SSD_POOL/music"];
  #     inotify = "yes";
  #     port = 8200;
  #   };
  # };

  services.mongodb = {
    enable = true;
    dbpath = "/SATA_SSD_POOL/mongodb";
    user = "${username}";
    bind_ip = "0.0.0.0";
  };

  # Self hosted Git
  services.gitea = {
    enable = true;
    appName = "MW-Trading-Systems";
    repositoryRoot = "/SATA_SSD_POOL/gitea";
    user = "${username}";
    settings.server.HTTP_PORT = gitea_port;
    stateDir = "${gitea_state_dir}";
  };

  # Decentralized git protocol
  # services.radicle =
  # let
  #   port = 8776;
  #   domain = "mw_systems";
  # in {
  #   enable = true;
  #   node = {
  #     listenAddress = "0.0.0.0";
  #     listenPort = port;
  #     openFirewall = true;
  #   };
  #   privateKeyFile = "/etc/nixos/secrets/radicle/private_key";
  #   publicKey = "/etc/nixos/secrets/radicle/public_key";
  #   settings = {
  #     node = {
  #       alias = "seed.radicle.${domain}";
  #       externalAddresses = ["seed.radicle.${domain}:${builtins.toString port}"];
  #       seedingPolicy = {
  #         default = "allow";
  #         scope = "all";
  #       };
  #     };
  #   };
  # };

  services.calibre-web = {
    enable = true;
    listen = {
      ip = "0.0.0.0";
      port = calibre_port;
    };
    openFirewall = true;
  };

  services.polaris = {
    enable = true;
    openFirewall = true;
    port = polaris_port;
    settings = {
      mount_dirs = [
        {
          name = "SATA_SSD_POOL";
          source = "/SATA_SSD_POOL/music";
        }
      ];
    };
  };

  services.bitmagnet = {
    enable = true;
    openFirewall = true;
    settings = {
      http_server.port = "${builtins.toString bitmagnet_port}";
    };
  };

  services.mealie = {
    enable = true;
    port = mealie_port;
  };

  services.gotosocial = {
    enable = true;
    openFirewall = true;
    settings = {
      application-name = "gotosocial-magewe";
      bind-address = "0.0.0.0";
      host = "localhost";
      db-address = "/var/lib/gotosocial/database.sqlite";
      db-type = "sqlite";
      port = gotosocial_port;
      protocol = "https";
      storage-local-base-path = "/var/lib/gotosocial/storage";
    };
  };

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    mediaLocation = "/SATA_SSD_POOL/immich";
    openFirewall = true;
    port = immich_port;
  };

  services.photoprism = {
    enable = true;
    port = photoprism_port;
    address = "0.0.0.0";
    originalsPath = "/SATA_SSD_POOL/magewe/bilder";
    passwordFile = "/etc/nixos/secrets/photoprism";
  };

  programs.rust-motd = {
    enable = true;
    settings = {
      banner = {
        color = "black";
        command = "${pkgs.neofetch}/bin/neofetch";
      };
      filesystems = {
        root = "/";
      };
      service_status = {
        tailscale = "tailscaled";
        prometheus-exporter = "prometheus-node-exporter";
        mnt-elitedesk_backup = "mnt-elitedesk_backup.mount";
        bitmagnet = "bitmagnet";
        calibre-web = "calibre-web";
        gitea = "gitea";
        gotosocial = "gotosocial";
        grafana = "grafana";
        immich = "immich-server";
        jellyfin = "jellyfin";
        mealie = "mealie";
        monero = "monero";
        photoprism = "photoprism";
        greptimedb = "podman-greptimedb";
        homer = "podman-homer";
        mafl = "podman-mafl";
        readeck = "podman-readeck";
        polaris = "polaris";
        tikr_BinanceCoinMargin_L2OrderBookDelta = "tikr@BinanceCoinMargin_L2OrderBookDelta";
        tikr_BinanceCoinMargin_Quotes = "tikr@BinanceCoinMargin_Quotes";
        tikr_BinanceCoinMargin_Trades = "tikr@BinanceCoinMargin_Trades";
        tikr_BinanceUsdMargin_L2OrderBookDelta = "tikr@BinanceUsdMargin_L2OrderBookDelta";
        tikr_BinanceUsdMargin_Quotes = "tikr@BinanceUsdMargin_Quotes";
        tikr_BinanceUsdMargin_Trades = "tikr@BinanceUsdMargin_Trades";
        cloudflare-tunnel = "cloudflared-tunnel-poweredge";
      };
    };
  };

  services.cloudflared = {
    enable = true;
    tunnels."poweredge" = {
      credentialsFile = "/home/magewe/.cloudflared/9c4b5093-598c-45cb-89b7-8fa608bfb363.json";
      default = "http_status:404";
      ingress = {
        "immich.mwtradingsystems.com" = "http://localhost:${builtins.toString immich_port}";
        "www.mwtradingsystems.com" = "http://localhost:${builtins.toString immich_port}";
        "@.mwtradingsystems.com" = "http://localhost:${builtins.toString immich_port}";
      };
    };
  };
}
