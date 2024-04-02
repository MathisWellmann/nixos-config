# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/monero.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop.nix
    ./../../modules/backup.nix
    ./../../modules/buildkite.nix
  ];

  buildkite_queue = "nixos";

  nixpkgs.config.pulseaudio = true;
  age.identityPaths = ["${config.users.users.magewe.home}/.ssh/magewe_meshify"];

  networking.hostName = "meshify";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # TODO: Move to `home.nix`
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # TODO: move next to `hyprland` setup
  # environment.sessionVariables = {
  #   WLR_NO_HARDWARE_CURSORS = "1";
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = ["networkmanager" "wheel" "docker"];
    packages = [];
    shell = pkgs.nushell;
  };

  virtualisation.docker.enable = true;

  services.mongodb = {
    enable = true;
    dbpath = "/home/magewe/mongodb";
    user = "root";
    bind_ip = "0.0.0.0";
  };
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd"];
        port = 9002;
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    27017 # Mongodb
    8231 # Tikr
  ];
  networking.nameservers = ["192.168.0.75"];

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "magewe" = import ./../home_with_desktop.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
