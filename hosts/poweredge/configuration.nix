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
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/namecoin.nix
    ./../../modules/monero.nix
    ./../../modules/local_ai.nix
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
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
  };

  networking = {
    hostName = "poweredge"; # Define your hostname.
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "d198feeb";
    firewall.allowedTCPPorts = [
      2049 # nfs
      4001 # Greptimedb
      3001 # Grafana
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
      exports_for_genoa =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${genoa_addr}/${genoa_subnet}(rw,sync,no_subtree_check)\n")
        [
          "video"
          "music"
          "series"
          "movies"
          "backup_genoa"
          "magewe"
          "torrents_transmission"
        ];
      exports_for_meshify =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${meshify_addr}(rw,sync,no_subtree_check)\n")
        [
          "video"
          "music"
          "series"
          "movies"
          "backup_meshify"
          "magewe"
          "torrents_transmission"
        ];
      exports_for_razerblade =
        lib.strings.concatMapStrings (dir: "/SATA_SSD_POOL/" + dir + " ${razerblade_addr}(rw,sync,no_subtree_check)\n")
        [
          "video"
          "music"
          "series"
          "movies"
          "backup_razerblade"
          "magewe"
          "torrents_transmission"
        ];
    in {
      enable = true;
      exports = lib.strings.concatStrings [exports_for_genoa exports_for_meshify exports_for_razerblade];
    };
    prometheus = {
      enable = true;
      listenAddress = "0.0.0.0";
      retentionTime = "1y";
      port = 9001;
      exporters = {
        node = {
          enable = true;
          port = 9002;
          enabledCollectors = ["systemd" "zfs"];
        };
        # mongodb.enable = true;
        # bitcoin.enable = true;
        # buildkite-agent.enable = true;
      };
      scrapeConfigs = map (host: {
        job_name = "${host}-node";
        static_configs = [
          {
            targets = ["${host}:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }) ["127.0.0.1" "genoa" "meshify" "superserver" "elitedesk" "razerblade"];
    };
    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = 3001;
        };
      };
    };
    jellyfin = {
      # Runs on port 8096
      enable = true;
      openFirewall = true;
    };
  };

  virtualisation.oci-containers.containers."greptimedb" = {
    image = "greptime/greptimedb";
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

  ### VPN Container for torrenting linux ISOs of course.
  containers.torrent = {
    bindMounts = {
      "/torrents_transmission" = {
        hostPath = "/SATA_SSD_POOL/torrents_transmission";
        isReadOnly = false;
      };
    };
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";
    config = {...}: {
      system.stateVersion = "24.11";
      services = {
        mullvad-vpn.enable = true;
        transmission = {
          enable = true;
          settings = {
            download-dir = "/torrents_transmission/finished";
            incomplete-dir = "/torrents_tranmission/incomplete";
            incomplete-dir-enabled = true;
            watch-dir = "/torrents_transmission/watch_dir";
            watch-dir-enable = true;
            speed-limit-down-enabled = true;
            speed-limit-down = 5000; # in KB/s
            speed-limit-up-enabled = true;
            speed-limit-up = 5000;
          };
        };
      };
      systemd.services."mullvad-daemon".postStart = ''
        while ! ${pkgs.mullvad}/bin/mullvad status >/dev/null; do sleep 1; done

        ${pkgs.mullvad}/bin/mullvad lan set allow
        ${pkgs.mullvad}/bin/mullvad lockdown-mode set on
        ${pkgs.mullvad}/bin/mullvad auto-connect set on
        ${pkgs.mullvad}/bin/mullvad connect
      '';
    };
  };
  # critical fix for mullvad-daemon to run in container, otherwise errors with: "EPERM: Operation not permitted"
  # It seems net_cls API filesystem is deprecated as it's part of cgroup v1. So it's not available by default on hosts using cgroup v2.
  # https://github.com/mullvad/mullvadvpn-app/issues/5408#issuecomment-1805189128
  fileSystems."/tmp/net_cls" = {
    device = "net_cls";
    fsType = "cgroup";
    options = ["net_cls"];
  };
  # Needed for DNS to work within the container.
  networking.firewall.interfaces."ve-torrent".allowedUDPPorts = [53];

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
      ];
      passwordFile = "/etc/nixos/secrets/restic/password";
      repository = "/mnt/${backup_host}_backup/restic/SATA_SSD_POOL";
      pruneOpts = ["--keep-daily 14"];
      user = "${username}";
    };
  };
  environment.systemPackages = with pkgs; [
    restic
  ];
}
