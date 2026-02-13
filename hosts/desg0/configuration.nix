# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  const = import ./constants.nix;
  de-msa2_const = import ../../hosts/de-msa2/constants.nix;
  global_const = import ../../global_constants.nix;
  forgejo_runner = import ./../../modules/forgejo_runner.nix {
    forgejo_url = "http://de-msa2:${toString de-msa2_const.forgejo_port}";
    state_dir = "/etc/forgejo_runner";
    runner_capacity = 4;
  };
  monero_miner = import ./../../modules/monero_miner.nix {max-threads-hint = 12;};
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/nix_binary_cache_client.nix
    ./../../modules/local_ai.nix
    forgejo_runner
    monero_miner
    inputs.home-manager.nixosModules.default
  ];

  networking = {
    hostName = const.hostname;
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "1840e132";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = global_const.username;
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
    packages = [];
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
        prometheus-exporter = "prometheus-node-exporter";
        restic-backups-home = "restic-backups-home";
        forgejo_runner = "gitea-runner-default";
      };
      uptime.prefix = "up";
    };
  };
}
