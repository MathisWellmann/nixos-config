# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  hostname = "tensorbook";
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
  ];
  time.timeZone = lib.mkForce "Europe/London";

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${global_const.username}" = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = ["networkmanager" "wheel" "audio"];
    packages = with pkgs; [
      flyctl
      bc # GNU calculator
      bun
      supabase-cli
      nixpacks
    ];
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
        service_status = {};
        uptime.prefix = "up";
      };
    };
    nix-ld = {
      enable = true;
      libraries = [];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = 1;
  };

  hardware.brillo.enable = true; # Brightness adjustment, e.g.: `brillo -u 150000 -S 100`

  # Required for being able to download inside `nix build` environment, e.g rust dependencies pulling in data.
  nix.settings.sandbox = false;
  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.departure-mono
  ];
  virtualisation = {
    docker.enable = true;
    podman.enable = true;
  };
  # Link /bin/bash to bash
  systemd.tmpfiles.rules = [
    "L /bin/bash - - - - ${pkgs.bash}/bin/bash"
  ];
  fileSystems."/mnt/de-msa2_nvme_pool_magewe" = {
    device = "de-msa2:/nvme_pool/magewe";
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
  };
}
