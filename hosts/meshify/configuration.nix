# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: let
  # TODO: move to `constants.nix`
  hostname = "meshify";
  static_ips = import ../../modules/static_ips.nix;
  global_const = import ../../global_constants.nix;
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/backup_home_to_remote.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/yubi_key.nix
    ./../../modules/monero_miner.nix
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;

  age.identityPaths = ["/home/${global_const.username}/.ssh/magewe_meshify"];

  networking.hostName = "${hostname}";

  # TODO: extract to own module and use on all hosts
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout" # Allow access to serial device (for Arduino dev)
      "tty"
    ];
    packages = [];
    shell = pkgs.nushell;
  };

  # Home manger can silently fail to do its job, so check with `systemctl status home-manager-m`
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
  system.stateVersion = "23.11"; # Did you read the comment?

  programs = {
    rust-motd = {
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
          mnt-poweredge-magewe = "mnt-de-msa2_SATA_SSD_POOL_magewe.mount";
          mnt-poweredge-movies = "mnt-de-msa2_SATA_SSD_POOL_movies.mount";
          mnt-poweredge-music = "mnt-de-msa2_SATA_SSD_POOL_music.mount";
          mnt-poweredge-pdfs = "mnt-de-msa2_SATA_SSD_POOL_pdfs.mount";
          mnt-poweredge-series = "mnt-de-msa2_SATA_SSD_POOL_series.mount";
          mnt-poweredge-video = "mnt-de-msa2_SATA_SSD_POOL_video.mount";
          restic-backups-home = "restic-backups-home";
        };
      };
    };
    npm.enable = true;
    # E.g `kani` requires this if installed with `cargo install --locked kani`
    nix-ld = {
      enable = true;
      libraries = [];
    };
  };

  services = {
    # Mullvad required `resolved` and being connected disrupts `tailscale` connectivity in the current configuration.
    mullvad-vpn.enable = true;
    resolved.enable = true;
    blueman.enable = true;
    grafana.enable = true;
    backup_home_to_remote = {
      enable = true;
      local_username = "${global_const.username}";
      backup_host_addr = "poweredge";
      backup_host_name = "poweredge";
      backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
    };
    mount_remote_nfs_exports = {
      enable = true;
      nfs_host_name = "de-msa2";
      nfs_host_addr = "de-msa2";
      nfs_dirs = map (dir: "/nvme_pool/${dir}") ["video" "series" "movies" "music" "magewe"];
    };
  };

  fileSystems = {
    "/mnt/elitedesk_series" = {
      device = "${static_ips.elitedesk_ip}:/external_hdd/series";
      fsType = "nfs";
      options = ["rw" "rsize=131072" "wsize=131072"];
    };
    "/mnt/elitedesk_movies" = {
      device = "${static_ips.elitedesk_ip}:/external_hdd/movies";
      fsType = "nfs";
      options = ["rw" "rsize=131072" "wsize=131072"];
    };
  };

  sops = {
    defaultSopsFile = "./../../sops_secrets.yaml";
    defaultSopsFormat = "yaml";

    # This creates /run/secrets/create_ap_password
    # secrets.meshify_ap_password = {
    #   sopsFile = ../../sops_secrets.yaml;
    # };
  };
  # Create wifi access point, sharing the primary ethernet connection
  # services.create_ap = {
  #   enable = true;
  #   settings = {
  #     INTERNET_IFACE = "enp11s0";
  #     WIFI_IFACE = "wlp12s0";
  #     SSID = "meshify_ap";
  #     PASSPHRASE = "12345678";
  #   };
  # };
}
