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
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/buildkite.nix
  ];

  # Running buildkite for `WellmannCapitalManagement`.
  buildkite_agent = "superserver";
  buildkite_queue = "nixos";

  networking = {
    hostName = "superserver";
    nat.enable = true;
  };

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
  #     buildkite_agent = "ss-gensyn";
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
  #   };
  # };

  # Enable ip forwarding for exposing tailscale subnet routes.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."ipv6.conf.all.forwarding" = 1;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = ["networkmanager" "wheel"];
    packages = [];
    shell = pkgs.nushell;
  };

  services = {
    prometheus = {
      exporters = {
        node = {
          enable = true;
          enabledCollectors = ["systemd"];
          port = 9002;
        };
      };
    };
    nfs.server = {
      enable = true;
      exports = ''
        /home/magewe/temp_nfs_dir/  169.254.51.104(rw,sync,no_subtree_check)
      '';
    };
  };
  networking.firewall.allowedTCPPorts = [
    2049 # nfs
  ];

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "magewe" = import ./../../home/home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
