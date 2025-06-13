# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: let
  hostname = "razerblade";
  global_const = import ../../global_constants.nix;
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
    ./../../modules/desktop_nvidia.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/backup_home_to_remote.nix
  ];

  networking = {
    hostName = "${hostname}";
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "5d140ae5";
    networkmanager.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${global_const.username}" = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = ["networkmanager" "wheel" "audio"];
    packages = [];
    shell = pkgs.nushell;
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/${hostname}.nix;
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

  hardware.brillo.enable = true; # Brightness adjustment, e.g.: `brillo -u 150000 -S 100`

  boot.supportedFilesystems = ["zfs"];
  boot.zfs = {
    forceImportRoot = false;
    extraPools = [];
  };
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };

  services.backup_home_to_remote = {
    enable = true;
    local_username = "${global_const.username}";
    backup_host_addr = "poweredge";
    backup_host_name = "poweredge";
    backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  };

  services.mount_remote_nfs_exports = {
    enable = true;
    nfs_host_name = "poweredge";
    nfs_host_addr = "poweredge";
    nfs_dirs = map (dir: "/SATA_SSD_POOL/${dir}") ["video" "series" "movies" "music" "magewe" "torrents_transmission" "pdfs"];
  };
  fileSystems."/mnt/elitedesk_backup_hdd" = {
    device = "elitedesk:/mnt/backup_hdd";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  # Mullvad required `resolved` and being connected disrupts `tailscale` connectivity in the current configuration.
  services.mullvad-vpn.enable = true;
  services.resolved.enable = true;

  hardware.ledger.enable = true;
  services.trezord.enable = true;

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["${global_const.username}"];
  # services.openvpn.servers = {
  #   mullvad = {
  #     config = ''config /home/${global_const.username}/mullvad_config_linux_se_got/mullvad_se_got.conf '';
  #     updateResolvConf = true;
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
        mnt-poweredge-ilka = "mnt-poweredge_SATA_SSD_POOL_ilka.mount";
        mnt-poweredge-magewe = "mnt-poweredge_SATA_SSD_POOL_magewe.mount";
        mnt-poweredge-movies = "mnt-poweredge_SATA_SSD_POOL_movies.mount";
        mnt-poweredge-music = "mnt-poweredge_SATA_SSD_POOL_music.mount";
        mnt-poweredge-pdfs = "mnt-poweredge_SATA_SSD_POOL_pdfs.mount";
        mnt-poweredge-series = "mnt-poweredge_SATA_SSD_POOL_series.mount";
        mnt-poweredge-video = "mnt-poweredge_SATA_SSD_POOL_video.mount";
        mnt-poweredge-backup = "mnt-poweredge_SATA_SSD_POOL_backup.mount";
        mnt-elitedesk-backup_hdd = "mnt-elitedesk_backup_hdd.mount";
        restic-backups-home = "restic-backups-home";
      };
      uptime.prefix = "up";
    };
  };

}
