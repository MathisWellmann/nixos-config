# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  username = "magewe";
  backup_host_ip = "169.254.80.160"; # Using the mellanox 100G NIC
  backup_host_name = "poweredge";
  backup_target_dir = "/SATA_SSD_POOL/backup_genoa";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.tikr.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_amd.nix
    ./../../modules/local_ai.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_poweredge_exports.nix
    ./../../modules/prometheus_exporter.nix
  ];

  networking = {
    hostName = "genoa";
    firewall.allowedTCPPorts = [
      8231 # Tikr
      2049 # NFS
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel"];
    packages = [];
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${username}" = import ./../../home/genoa.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  programs.hyprland = {
    enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = 1;
  };

  ### Backup Section ###
  fileSystems."/mnt/${backup_host_name}_backup" = {
    device = "${backup_host_ip}:${backup_target_dir}";
    fsType = "nfs";
    options = ["rw" "nofail"];
  };
  services = {
    restic.backups = {
      home = {
        initialize = true;
        paths = [
          "/home/${username}/"
        ];
        exclude = [
          "/home/${username}/.cache/"
        ];
        passwordFile = "/etc/nixos/secrets/restic/password";
        repository = "/mnt/${backup_host_name}_backup/";
        pruneOpts = ["--keep-daily 14"];
        user = "${username}";
      };
    };
  };
  environment.systemPackages = with pkgs; [
    restic
    flood
  ];

  services.tikr = {
    enable = true;
    database = "GreptimeDb";
    database-addr = "poweredge:4001";
    exchanges = ["BinanceUsdMargin" "BinanceCoinMargin"];
    data-types = ["Trades" "Quotes" "L2OrderBookDelta"];
  };
}
