# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  hostname = "madcatz";
  username = "magewe";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
  ];

  i18n.defaultLocale = lib.mkForce "de_DE.UTF-8";

  networking.hostName = "${hostname}";
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
  #     buildkite_agent = "madcatz-gensyn";
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${username}" = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = ["networkmanager" "wheel"];
    packages = [];
    shell = pkgs.nushell;
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
  system.stateVersion = "23.05"; # Did you read the comment?

  services.backup_home_to_remote = {
    enable = true;
    local_username = "${username}";
    backup_host_addr = "poweredge";
    backup_host_name = "poweredge";
    backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
  };

  services.mount_remote_nfs_exports = {
    enable = true;
    nfs_host_name = "poweredge";
    nfs_host_addr = "poweredge";
    nfs_dirs = map (dir: "/SATA_SSD_POOL/${dir}") ["video" "series" "movies" "music" "magewe" "torrents_transmission"];
  };
}
