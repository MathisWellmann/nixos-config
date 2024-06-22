# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  config,
  tikr,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop.nix
    ./../../modules/backup.nix
    ./../../modules/buildkite.nix
    ./../../modules/monero.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_poweredge_exports.nix
  ];

  buildkite_queue = "nixos";

  networking.nat.enable = true;

  # Native `systemd-nspawn` container
  # containers.buildkiteGensyn = {
  #   autoStart = true;

  #   config = {
  #     config,
  #     pkgs,
  #     lib,
  #     ...
  #   }: {
  #     imports = [
  #       ./../../modules/buildkite.nix
  #     ];
  #     buildkite_agent = "meshify-gensyn";
  #     buildkite_queue = "nixos";

  #     networking = {
  #       firewall.enable = true;
  #       # Use systemd-resolved inside the container
  #       # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
  #       useHostResolvConf = lib.mkForce false;
  #     };

  #     services.resolved.enable = true;

  #     system.stateVersion = "23.11";
  #     nix.settings.experimental-features = ["nix-command" "flakes"];
  #     environment.systemPackages = with pkgs; [
  #       lsd
  #     ];
  #   };
  # };

  nixpkgs.config.pulseaudio = true;
  age.identityPaths = ["${config.users.users.magewe.home}/.ssh/magewe_meshify"];

  networking.hostName = "meshify";

  # TODO: Move to `home.nix`
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

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
      "magewe" = import ./../../home/meshify.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  environment.systemPackages = [
    tikr.defaultPackage.${pkgs.system}
  ];
}
