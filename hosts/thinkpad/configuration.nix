# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  global_const = import ../../global_constants.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    inputs.home-manager.nixosModules.default
    ./hardware-configuration.nix
    ../../modules/base_system.nix
    ../../modules/root_pkgs.nix
    ../../modules/base_system.nix
    ../../modules/mount_external_drives.nix
    ../../modules/local_ai.nix
  ];

  networking.hostName = "thinkpad"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = "m";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      git
      helix
    ];
  };

  # Home manger can silently fail to do its job, so check with `systemctl status home-manager-m`
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/thinkpad.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  environment.systemPackages = with pkgs; [
    slack
  ];
}
