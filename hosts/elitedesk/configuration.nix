# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  nixpkgs.config.pulseaudio = true;

  networking.hostName = "elitedesk";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = ["networkmanager" "wheel" "docker"];
    packages = [];
    shell = pkgs.nushell;
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "magewe" = import ./../home.nix;
    };
  };

  # Mount the 16TB backup drive
  fileSystems."/mnt/backup_hdd" = {
    device = "/dev/disk/by-uuid/e15ce1db-586f-4e7b-a5d8-d8a4a0b45e48";
    fsType = "btrfs";
    options = [
      "users" # Allows any user to mount and unmount
      "nofail" # Prevent system from failing if this drive doesn't mount
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
