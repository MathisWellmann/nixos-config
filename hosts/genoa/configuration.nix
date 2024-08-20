# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{inputs, ...}: let
  hostname = "genoa";
  username = "magewe";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_amd.nix
    ./../../modules/local_ai.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/backup_home_to_remote.nix
  ];

  networking = {
    hostName = "${hostname}";
    firewall.allowedTCPPorts = [
      8231 # Tikr
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
      "${username}" = import ./../../home/${hostname}.nix;
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

  services.backup_home_to_remote = {
    enable = true;
    local_username = "${username}";
    backup_host_addr = "169.254.90.239";
    backup_host_name = "poweredge";
    backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  };

  services.mount_remote_nfs_exports = {
    enable = true;
    nfs_host_name = "poweredge";
    nfs_host_addr = "169.254.90.239";
    nfs_dirs = map (dir: "/SATA_SSD_POOL/${dir}") ["video" "series" "movies" "music" "magewe" "torrents_transmission" "ilka"];
  };
}
