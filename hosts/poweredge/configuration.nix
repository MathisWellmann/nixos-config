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
    ./../../modules/namecoin.nix
    ./../../modules/monero.nix
    ./../../modules/local_ai.nix
  ];

  networking.hostName = "poweredge"; # Define your hostname.

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
  };

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

  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
  networking.hostId = "d198feeb";

  networking.firewall.allowedTCPPorts = [2049];
  services = {
    nfs.server = {
      enable = true;
      exports = ''
        /SATA_SSD_POOL/video/ razerblade(rw,sync,no_subtree_check)
      '';
    };
    prometheus = {
      exporters = {
        node = {
          enable = true;
          enabledCollectors = ["systemd" "zfs" "nfs"];
          port = 9002;
        };
      };
    };
    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          http_port = 3000;
        };
      };
    };
  };

  virtualisation.oci-containers.containers."greptimedb" = {
    image = "greptime/greptimedb";
    cmd = [
      "standalone"
      "start"  
    ];
    ports = [
      "4000:4000"
      "4001:4001"
      "4002:4002"
      "4003:4003"
    ];
    volumes = [
      "/SATA_SSD_POOL/greptimedb:/tmp/greptimedb"
    ];
  };
}
