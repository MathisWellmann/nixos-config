# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: let
  username = "magewe";
  backup_host = "elitedesk";
  backup_target_dir = "/mnt/backup_hdd";
  genoa_mellanox_ip = "169.254.79.94";
  genoa_mellanox_subnet = "16";
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

  networking.hostName = "poweredge"; # Define your hostname.

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
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "d198feeb";
    firewall.allowedTCPPorts = [
      2049 # nfs
      4001 # Greptimedb
    ];
  };

  services = {
    nfs.server = {
      enable = true;
      exports = ''
        /SATA_SSD_POOL/video/ genoa(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/video/ meshify(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/video/ razerblade(rw,sync,no_subtree_check)

        /SATA_SSD_POOL/music/ genoa(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/music/ meshify(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/music/ razerblade(rw,sync,no_subtree_check)

        /SATA_SSD_POOL/series/ genoa(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/movies/ genoa(rw,sync,no_subtree_check)

        /SATA_SSD_POOL/enc/ genoa(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/enc/ meshify(rw,sync,no_subtree_check)
        /SATA_SSD_POOL/enc/ razerblade(rw,sync,no_subtree_check)

        /SATA_SSD_POOL/backup_genoa/ genoa(rw,sync,no_subtree_check)
      '';
    };
    prometheus = {
      exporters = {
        node = {
          enable = true;
          enabledCollectors = ["systemd" "zfs" "nfs"];
          port = 9002;
        };
      };
    };
    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = 3000;
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
