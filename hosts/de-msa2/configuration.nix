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
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/prometheus_exporter.nix
  ];

  networking.hostName = "de-msa2"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${global_const.username}" = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
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
      "${global_const.username}" = import ./../../home/home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

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
        prometheus = "prometheus";
        prometheus-exporter = "prometheus-node-exporter";
        grafana = "grafana";
        adguardhome = "adguardhome";
        jellyfin = "jellyfin";
        nfs-server = "nfs-server";
        monero = "monero";
      };
    };
  };
}
