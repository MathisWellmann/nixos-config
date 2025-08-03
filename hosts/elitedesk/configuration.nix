# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  global_const = import ../../global_constants.nix;
  const = import ./constants.nix;
  static_ips = import ../../modules/static_ips.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/monero.nix
    ./../../modules/adguardhome.nix
    ./prometheus.nix
    ./homer_dashboard.nix
    ./gitea.nix
  ];

  networking.hostName = "elitedesk"; # Define your hostname.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = ["networkmanager" "wheel"];
    packages = [];
    shell = pkgs.nushell;
  };

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
        prometheus= "prometheus";
        prometheus-exporter = "prometheus-node-exporter";
        grafana = "grafana";
        adguardhome = "adguardhome";
        jellyfin = "jellyfin";
        nfs-server = "nfs-server";
        monero = "monero";
      };
    };
  };

  fileSystems."/mnt/external_hdd" = {
    device = "/dev/disk/by-uuid/e15ce1db-586f-4e7b-a5d8-d8a4a0b45e48";
    fsType = "btrfs";
    options = [
      # If you don't have this options attribute, it'll default to "defaults"
      "users" # Allows any user to mount and unmount
      "nofail" # Prevent system from failing if this drive doesn't mount
    ];
  };
  services = {
    nfs.server = let
      meshify_addr = "meshify";
      razerblade_addr = "razerblade";
      common_dirs = [
        "series"
        "movies"
      ];
      exports_for_meshify =
        lib.strings.concatMapStrings (dir: "/mnt/external_hdd/" + dir + " ${meshify_addr}(rw,sync,no_subtree_check)\n")
        common_dirs;
      exports_for_razerblade =
        lib.strings.concatMapStrings (dir: "/mnt/external_hdd/" + dir + " ${razerblade_addr}(rw,sync,no_subtree_check)\n")
        common_dirs;
      exports_for_poweredge =
        lib.strings.concatMapStrings (dir: "/mnt/external_hdd/" + dir + " ${static_ips.poweredge_ip}(rw,sync,no_subtree_check)\n")
        common_dirs;
    in {
      enable = true;
      exports = lib.strings.concatStrings [exports_for_meshify exports_for_razerblade exports_for_poweredge];
    };
    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = const.grafana_port;
        };
      };
    };
    jellyfin = {
      # Runs on port 8096
      enable = true;
      openFirewall = true;
    };
  };
  networking.firewall.allowedTCPPorts = [
    2049 # NFS
    const.jellyfin_port
    const.grafana_port
  ];
}
