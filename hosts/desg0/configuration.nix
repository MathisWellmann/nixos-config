# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  const = import ./constants.nix;
  global_const = import ../../global_constants.nix;
  static_ips = import ./../../modules/static_ips.nix;
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
    inputs.home-manager.nixosModules.default
  ];

  networking = {
    hostName = const.hostname;
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "1840e132";
  };

  boot.supportedFilesystems = ["zfs"];
  boot.kernelParams = ["zfs.zfs_arc_max=128000000000"]; # 128 GB ARC size limit
  boot.zfs = {
    forceImportRoot = false;
    extraPools = [
      "nvme_pool"
    ];
  };
  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
      pools = [
        "nvme_pool"
      ];
    };
    autoSnapshot.enable = true;
    trim = {
      enable = false;
      interval = "weekly";
    };
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
      };
      uptime.prefix = "up";
    };
  };
  networking.firewall.allowedTCPPorts = [
    18142 # tari node
    const.nfs_port
    const.greptimedb_http_port
    const.greptimedb_rpc_port
    const.greptimedb_mysql_port
    const.greptimedb_postgres_port
    const.iperf_port
  ];

  virtualisation.oci-containers.containers."greptimedb" = let
    version = "v0.15.1";
  in {
    image = "greptime/greptimedb:${version}";
    cmd = [
      "standalone"
      "start"
      "--http-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_http_port}"
      "--rpc-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_rpc_port}"
      "--mysql-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_mysql_port}"
      "--postgres-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_postgres_port}"
    ];
    ports = [
      "${builtins.toString const.greptimedb_http_port}:${builtins.toString const.greptimedb_http_port}"
      "${builtins.toString const.greptimedb_rpc_port}:${builtins.toString const.greptimedb_rpc_port}"
      "${builtins.toString const.greptimedb_mysql_port}:${builtins.toString const.greptimedb_mysql_port}"
      "${builtins.toString const.greptimedb_postgres_port}:${builtins.toString const.greptimedb_postgres_port}"
    ];
    volumes = [
      "/nvme_pool/greptimedb:/greptimedb_data"
    ];
  };
  services = {
    nfs.server = let
      meshify_addr = "meshify";
      razerblade_addr = "razerblade";
      common_dirs = [
        "magewe"
        "ilka"
        "pdfs"
      ];
      exports_for_meshify =
        lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " ${meshify_addr}(rw,sync,no_subtree_check)\n")
        common_dirs;
      exports_for_poweredge =
        lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " ${static_ips.poweredge_ip}(rw,sync,no_subtree_check)\n")
        common_dirs;
      exports_for_razerblade =
        lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " ${razerblade_addr}(rw,sync,no_subtree_check)\n")
        common_dirs;
    in {
      enable = true;
      exports = lib.strings.concatStrings [
        exports_for_meshify
        exports_for_razerblade
        exports_for_poweredge
      ];
    };
  };
}
