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
  const = import ./constants.nix;
  static_ips = import ./../../modules/static_ips.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/harmonia_cache.nix
    ./../../modules/monero.nix
    ./../../modules/monero_miner.nix
    ./../../modules/searx.nix
    ./freshrss.nix
    ./firefly.nix
    ./mafl.nix
    ./prometheus.nix
    # ./../../modules/nats_cluster.nix
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${const.username}" = {
    isNormalUser = true;
    description = "${const.username}";
    extraGroups = ["wheel" "docker"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      gitea-actions-runner
    ];
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${const.username}" = import ./../../home/home.nix;
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
  boot.kernelParams = ["zfs.zfs_arc_max=128000000000"]; # 128 GB ARC size limit
  boot.zfs = {
    forceImportRoot = false;
    extraPools = ["SATA_SSD_POOL"];
  };
  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
      pools = ["SATA_SSD_POOL"];
    };
    autoSnapshot.enable = true;
    trim = {
      enable = false;
      interval = "weekly";
    };
  };

  networking = {
    hostName = const.hostname;
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "d198feeb";
    firewall.allowedTCPPorts = [
      2049 # nfs
      const.greptimedb_http_port
      const.greptimedb_rpc_port
      const.greptimedb_mysql_port
      const.greptimedb_postgres_port
      const.gitea_port
      const.grafana_port
      const.mafl_port
      const.homer_port
      const.mealie_port
      const.mongodb_port
      const.uptime_kuma_port
      const.nats_port
      const.searx_port
    ];
    firewall.allowedUDPPorts = [
      53   # Adguard DNS
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
      exports = lib.strings.concatStrings [exports_for_meshify exports_for_razerblade];
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
    jellyfin = {
      # Runs on port 8096
      enable = true;
      openFirewall = true;
    };
    # tikr = {
    #   enable = true;
    #   database = "GreptimeDb";
    #   database-addr = "poweredge:4001";
    #   exchanges = ["BinanceUsdMargin" "BinanceCoinMargin"];
    #   data-types = ["Trades" "Quotes" "L2OrderBookDelta"];
    #   prometheus_exporter_base_port = const.tikr_base_port;
    # };
    # Music server
    minidlna = {
      enable = true;
      openFirewall = true;
      settings = {
        friendly_name = "poweredge_minidlna";
        media_dir = ["/SATA_SSD_POOL/music"];
        inotify = "yes";
        port = 8200;
      };
    };
    # Self hosted Git
    gitea = {
      enable = true;
      appName = "MW-Trading-Systems";
      repositoryRoot = "/SATA_SSD_POOL/gitea";
      user = "${const.username}";
      settings = {
        server = {
          HTTP_PORT = const.gitea_port;
          ROOT_URL = "http://${toString static_ips.poweredge_ip}:${toString const.gitea_port}";
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
    gitea-actions-runner.instances.${const.hostname} = {
      enable = true;
      name = "${const.hostname}";
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
    calibre-web = {
      enable = true;
      listen = {
        ip = "0.0.0.0";
        port = const.calibre_port;
      };
      openFirewall = true;
    };
    polaris = {
      enable = true;
      openFirewall = true;
      port = const.polaris_port;
      settings = {
        mount_dirs = [
          {
            name = "SATA_SSD_POOL";
            source = "/SATA_SSD_POOL/music";
          }
        ];
      };
    };
    bitmagnet = {
      enable = true;
      openFirewall = true;
      settings = {
        http_server.port = "${builtins.toString const.bitmagnet_port}";
      };
    };
    # Marked as broken. TODO: re-enable
    mealie = {
      enable = true;
      port = const.mealie_port;
    };

    # gotosocial = {
    #   enable = true;
    #   openFirewall = true;
    #   settings = {
    #     application-name = "gotosocial-magewe";
    #     bind-address = "0.0.0.0";
    #     host = "localhost";
    #     db-address = "/var/lib/gotosocial/database.sqlite";
    #     db-type = "sqlite";
    #     port = const.gotosocial_port;
    #     protocol = "https";
    #     storage-local-base-path = "/var/lib/gotosocial/storage";
    #   };
    # };
    immich = {
      enable = true;
      host = "0.0.0.0";
      mediaLocation = "/SATA_SSD_POOL/immich";
      openFirewall = true;
      port = const.immich_port;
    };
    photoprism = {
      enable = true;
      port = const.photoprism_port;
      address = "0.0.0.0";
      originalsPath = "/SATA_SSD_POOL/magewe/bilder";
      passwordFile = "/etc/nixos/secrets/photoprism";
    };
    cloudflared = {
      enable = true;
      tunnels."poweredge" = {
        credentialsFile = "/home/magewe/.cloudflared/9c4b5093-598c-45cb-89b7-8fa608bfb363.json";
        default = "http_status:404";
        ingress = {
          "immich.mwtradingsystems.com" = "http://localhost:${builtins.toString const.immich_port}";
          "www.mwtradingsystems.com" = "http://localhost:${builtins.toString const.immich_port}";
          "@.mwtradingsystems.com" = "http://localhost:${builtins.toString const.immich_port}";
        };
      };
    };
    # Nix Cache Proxy Server
    ncps = {
      enable = true;
      server.addr = "0.0.0.0:${builtins.toString const.ncps_port}";
      cache = {
        allowPutVerb = true;
        databaseURL = "sqlite:/var/lib/ncps/db/db.sqlite";
        dataPath = "/var/lib/ncps";
        hostName = const.hostname;
        maxSize = "512G";
      };
      upstream = {
        caches = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
      };
      openTelemetry = {
        enable = false;
        grpcURL = "http://127.0.0.1:${builtins.toString const.prometheus_port}";
      };
    };
    uptime-kuma = {
      enable = true;
      settings = {
        UPTIME_KUMA_HOST = "0.0.0.0";
        PORT = "${builtins.toString const.uptime_kuma_port}";
      };
    };
    adguardhome = {
      enable = true;
      openFirewall = true;
      port = const.adguardhome_port;
      settings = {
        http = {
          address = "${static_ips.poweredge_ip}:${const.adguardhome_port}";
        };
        dns = {
          upstream_dns = [
            "9.9.9.9#dns.quand9.net"
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          parental_enabled = false;
        };
        filters = map(url: { enabled = true; url = url; }) [
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_0.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"  # The Big List of Hacked Malware Web Sites
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"  # malicious url blocklist
        ];
      };
    };
  };

  ##### Containers #####
  virtualisation.oci-containers.containers = {
    "homer" = {
      image = "b4bz/homer";
      ports = [
        "${builtins.toString const.homer_port}:8080"
      ];
      volumes = [
        "/SATA_SSD_POOL/homer:/www/assets"
      ];
    };
    "readeck" = {
      image = "codeberg.org/readeck/readeck:latest";
      ports = [
        "${builtins.toString const.readeck_port}:8000"
      ];
      volumes = [
        "/SATA_SSD_POOL/readeck:/readeck"
      ];
    };
    # "greptimedb" = let
    #   version = "v0.9.3";
    # in {
    #   image = "greptime/greptimedb:${version}";
    #   cmd = [
    #     "standalone"
    #     "start"
    #     "--http-addr"
    #     "0.0.0.0:${builtins.toString const.greptimedb_http_port}"
    #     "--rpc-addr"
    #     "0.0.0.0:${builtins.toString const.greptimedb_rpc_port}"
    #     "--mysql-addr"
    #     "0.0.0.0:${builtins.toString const.greptimedb_mysql_port}"
    #     "--postgres-addr"
    #     "0.0.0.0:${builtins.toString const.greptimedb_postgres_port}"
    #   ];
    #   ports = [
    #     "${builtins.toString const.greptimedb_http_port}:4000"
    #     "${builtins.toString const.greptimedb_rpc_port}:4001"
    #     "${builtins.toString const.greptimedb_mysql_port}:4002"
    #     "${builtins.toString const.greptimedb_postgres_port}:4003"
    #   ];
    #   volumes = [
    #     "/SATA_SSD_POOL/greptimedb:/tmp/greptimedb"
    #   ];
    # };
  };

  virtualisation.docker.enable = true;

  ### Backup Section ###
  fileSystems."/mnt/${const.backup_host}_backup" = {
    device = "${const.backup_host}:${const.backup_target_dir}";
    fsType = "nfs";
    options = ["rw" "rsize=131072" "wsize=131072"];
  };
  services.restic.backups = {
    zfs_sata_ssd_pool = {
      initialize = true;
      paths = [
        "/SATA_SSD_POOL/*"
        "${const.gitea_state_dir}"
      ];
      passwordFile = "/etc/nixos/secrets/restic/password";
      repository = "/mnt/${const.backup_host}_backup/restic/SATA_SSD_POOL";
      pruneOpts = ["--keep-daily 14"];
      user = "${const.username}";
    };
  };
  environment.systemPackages = with pkgs; [
    restic
    gitea
    radicle-node
  ];

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

  # Nexus Databases
  virtualisation.oci-containers.containers."dragonfly" = {
    image = "docker.dragonflydb.io/dragonflydb/dragonfly";
    ports = [
      "${builtins.toString const.dragonfly_port}:6379"
    ];
    extraOptions = ["--ulimit" "memlock=-1"];
  };
  services.mongodb = {
    enable = true;
    dbpath = "/SATA_SSD_POOL/mongodb";
    user = "${const.username}";
    bind_ip = "0.0.0.0";
  };
  # Raise open file limits for mongodb.
  security.pam.services.mongodb.limits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1000000";
    }
  ];

  fileSystems."/mnt/desg0_magewe" = {
    device = "${static_ips.desg0_ip}:/nvme_pool/magewe";
    fsType = "nfs";
    options = ["rw" "rsize=131072" "wsize=131072"];
  };
  fileSystems."/mnt/desg0_ilka" = {
    device = "${static_ips.desg0_ip}:/nvme_pool/ilka";
    fsType = "nfs";
    options = ["rw" "rsize=131072" "wsize=131072"];
  };
}
