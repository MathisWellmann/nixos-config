# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  lib,
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
    ./../../modules/base_system.nix
    ./../../modules/local_ai.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/backup_home_to_remote.nix
  ];
  time.timeZone = lib.mkForce "Europe/London";

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
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "dialout" # Allow access to serial device (for Arduino dev)
      "tty"
    ];
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

  environment.sessionVariables = {
    NIXOS_OZONE_WL = 1;
  };

  hardware = {
    brillo.enable = true; # Brightness adjustment, e.g.: `brillo -u 150000 -S 100`
    ledger.enable = true;
  };

  # services.backup_home_to_remote = {
  #   enable = true;
  #   local_username = "${global_const.username}";
  #   backup_host_addr = "poweredge";
  #   backup_host_name = "poweredge";
  #   backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  # };

  services = {
    # Mullvad required `resolved` and being connected disrupts `tailscale` connectivity in the current configuration.
    mullvad-vpn.enable = true;
    resolved.enable = true;
    blueman.enable = true;
    trezord.enable = true;
  };
  fileSystems = let
    fsType = "nfs";
    options = [
      "rw"
      "nofail"
      "noatime" # Don't update last file access times when files are read.
      "retry=10" # Retry mounting for up to 10 seconds.
      "vers=4.2" # Force a new version
      "nconnect=4" # Number of connections
      "_netdev" # tells systemd it’s a network filesystem
      "x-systemd.requires=tailscaled.service"
      "x-systemd.after=tailscaled.service"
      "x-systemd.automount" # Only mount when directory is accessed.
    ];
  in {
    "/mnt/elitedesk_movies" = {
      device = "elitedesk:/mnt/external_hdd/movies";
      inherit fsType options;
    };
    "/mnt/elitedesk_series" = {
      device = "elitedesk:/mnt/external_hdd/series";
      inherit fsType options;
    };
    "/mnt/de-msa2_nvme_pool_magewe" = {
      device = "de-msa2:/nvme_pool/magewe";
      inherit fsType options;
    };
    "/mnt/de-msa2_nvme_pool_music" = {
      device = "de-msa2:/nvme_pool/music";
      inherit fsType options;
    };
    "/mnt/de-msa2_nvme_pool_video" = {
      device = "de-msa2:/nvme_pool/video";
      inherit fsType options;
    };
    "/mnt/de-msa2_nvme_pool_pdfs" = {
      device = "de-msa2:/nvme_pool/pdfs";
      inherit fsType options;
    };
  };

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["${global_const.username}"];

  programs = {
    hyprland = {
      enable = true;
    };
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
          restic-backups-home = "restic-backups-home";
        };
        uptime.prefix = "up";
      };
    };
    nix-ld = {
      enable = true;
      libraries = [];
    };
  };

  hardware.bluetooth.enable = true;
}
