# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  config,
  tikr,
  ...
}: let
  username = "magewe";
  backup_host_name = "poweredge";
  backup_target_dir = "/SATA_SSD_POOL/backup_meshify";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    # ./../../modules/local_ai.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/backup.nix
    ./../../modules/buildkite.nix
    ./../../modules/mount_external_drives.nix
    ./../../modules/mount_poweredge_exports.nix
    ./../../modules/prometheus_exporter.nix
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

  services.mongodb = let
    system = pkgs.system;
    # pkgs-stable = import inputs.nixpkgs-stable { inherit system; config.allowUnfree = true; };
  in {
    enable = true;
    dbpath = "/home/magewe/mongodb";
    user = "root";
    bind_ip = "0.0.0.0";
    # package = pkgs-stable.legacyPackages."${pkgs.system}".mongodb;
    # package = pkgs-stable.mongodb;
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

  environment.systemPackages = with pkgs; [
    tikr.defaultPackage.${pkgs.system}
    restic
  ];

  ### Backup Section ###
  fileSystems."/mnt/${backup_host_name}_backup" = {
    device = "${backup_host_name}:${backup_target_dir}";
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
}
