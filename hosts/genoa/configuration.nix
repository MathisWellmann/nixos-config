# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: let
  hostname = "genoa";
  username = "magewe";
  mongodb_port = 27017;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    # ./../../modules/desktop_amd.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/local_ai.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/backup_home_to_remote.nix
    ./../../modules/monero.nix
    # ./../../modules/monero_miner.nix
  ];

  networking = {
    hostName = "${hostname}";
    firewall.allowedTCPPorts = [
      8231 # Tikr
      mongodb_port
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${username}" = import ./../../home/${hostname}.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  programs.hyprland = {
    enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = 1;
  };

  services.backup_home_to_remote = {
    enable = true;
    local_username = "${username}";
    backup_host_addr = "169.254.90.239";
    backup_host_name = "poweredge";
    backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  };

  services.mount_remote_nfs_exports = {
    enable = true;
    nfs_host_name = "poweredge";
    # nfs_host_addr = "169.254.80.160";
    nfs_host_addr = "poweredge";
    nfs_dirs = map (dir: "/SATA_SSD_POOL/${dir}") ["video" "series" "movies" "music" "magewe" "torrents_transmission" "ilka" "pdfs"];
  };

  # Care must be taken when usin luks, see:
  # https://kokada.capivaras.dev/blog/an-unordered-list-of-hidden-gems-inside-nixos/
  services.fstrim.enable = true;

  services.mongodb = {
    enable = true;
    dbpath = "/mongodb";
    user = "${username}";
    bind_ip = "0.0.0.0";
  };

  hardware.ledger.enable = true;
  services.trezord.enable = true;

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
        mnt-poweredge-ilka = "mnt-poweredge_SATA_SSD_POOL_ilka.mount";
        mnt-poweredge-magewe = "mnt-poweredge_SATA_SSD_POOL_magewe.mount";
        mnt-poweredge-movies = "mnt-poweredge_SATA_SSD_POOL_movies.mount";
        mnt-poweredge-music = "mnt-poweredge_SATA_SSD_POOL_music.mount";
        mnt-poweredge-pdfs = "mnt-poweredge_SATA_SSD_POOL_pdfs.mount";
        mnt-poweredge-series = "mnt-poweredge_SATA_SSD_POOL_series.mount";
        mnt-poweredge-video = "mnt-poweredge_SATA_SSD_POOL_video.mount";
        mongodb = "mongodb";
        restic-backups-home = "restic-backups-home";
      };
      uptime.prefix = "up";
    };
  };
}
