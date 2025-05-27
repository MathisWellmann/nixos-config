# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  config,
  ...
}: let
  hostname = "meshify";
  username = "magewe";
  open-webui_port = 8080;
  metastable_port = 4000;
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
    # ./../../modules/backup.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/backup_home_to_remote.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/monero.nix
    # ./../../modules/monero_miner.nix
    ./../../modules/virtualization_host.nix
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.nat.enable = true;

  age.identityPaths = ["${config.users.users.magewe.home}/.ssh/magewe_meshify"];

  networking.hostName = "${hostname}";

  # TODO: Move to `home.nix`
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel" "docker"];
    packages = [];
    shell = pkgs.nushell;
  };

  virtualisation.docker.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    8231 # Tikr
  ];
  networking.nameservers = ["192.168.0.75"];

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
  system.stateVersion = "23.11"; # Did you read the comment?

  services.backup_home_to_remote = {
    enable = true;
    local_username = "${username}";
    backup_host_addr = "poweredge";
    backup_host_name = "poweredge";
    backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  };

  services.mount_remote_nfs_exports = {
    enable = true;
    nfs_host_name = "poweredge";
    nfs_host_addr = "poweredge";
    nfs_dirs = map (dir: "/SATA_SSD_POOL/${dir}") ["video" "series" "movies" "music" "magewe" "torrents_transmission"];
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
        mnt-poweredge-magewe = "mnt-poweredge_SATA_SSD_POOL_magewe.mount";
        mnt-poweredge-movies = "mnt-poweredge_SATA_SSD_POOL_movies.mount";
        mnt-poweredge-music = "mnt-poweredge_SATA_SSD_POOL_music.mount";
        mnt-poweredge-pdfs = "mnt-poweredge_SATA_SSD_POOL_pdfs.mount";
        mnt-poweredge-series = "mnt-poweredge_SATA_SSD_POOL_series.mount";
        mnt-poweredge-video = "mnt-poweredge_SATA_SSD_POOL_video.mount";
        restic-backups-home = "restic-backups-home";
      };
    };
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = open-webui_port;
    openFirewall = true;
  };

  virtualisation.oci-containers.containers."metastable" = {
    image = "ghcr.io/mat-sz/metastable:cuda";
    ports = [
      "${builtins.toString metastable_port}:5001"
    ];
    volumes = [];
  };

  # Mullvad required `resolved` and being connected disrupts `tailscale` connectivity in the current configuration.
  services.mullvad-vpn.enable = true;
  services.resolved.enable = true;
}
