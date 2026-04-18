# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # TODO: move to `constants.nix`
  hostname = "meshify";
  # const = import ./constants.nix;
  static_ips = import ../../modules/static_ips.nix;
  global_const = import ../../global_constants.nix;
  # vllm = import ./../../modules/ai/vllm_cuda_container.nix {
  #   port = const.vllm_port;
  #   # model = "Qwen/Qwen3.5-27B";
  #   # model = "google/gemma-4-31B-it";
  #   model = "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4";
  # };
  # tensorrt = import ./../../modules/ai/tensorrt_llm_container.nix {
  #   port = const.tensorrt_port;
  # };
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    # inputs.agentica-framework.nixosModules.agentica-chat
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    # ./../../modules/mount_external_drives.nix
    # ./../../modules/mount_remote_nfs_exports.nix
    # ./../../modules/backup_home_to_remote.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/yubi_key.nix
    ./../../modules/nix_binary_cache_client.nix
    ./../../modules/ai/qwen_code.nix
    ./../../modules/ai/local_ai.nix
    ./../../modules/ai/ollama.nix
    ./../../modules/ai/pi-agent.nix
    # monero_miner
    # vllm
    # tensorrt
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Workaround: nixpkgs regression where the initrd activation script runs before
  # /proc and /sys are mounted, so it can't write firmware_class.path or modprobe path.
  # Setting firmware path on the kernel command line ensures it's available from boot start.
  boot.kernelParams = ["firmware_class.path=${config.hardware.firmware}/lib/firmware"];
  systemd.services."modprobe@".serviceConfig.ExecStart = lib.mkForce "-${pkgs.kmod}/sbin/modprobe -abq %i";
  boot.initrd.systemd.services."modprobe@".serviceConfig.ExecStart = lib.mkForce "-${pkgs.kmod}/sbin/modprobe -abq %i";

  age.identityPaths = ["/home/${global_const.username}/.ssh/magewe_meshify"];

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [1234]; # LM studio
  };

  # TODO: extract to own module and use on all hosts
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout" # Allow access to serial device (for Arduino dev)
      "tty"
    ];
    packages = [];
    shell = pkgs.nushell;
  };

  # Home manger can silently fail to do its job, so check with `systemctl status home-manager-m`
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/${hostname}.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  programs = {
    rust-motd = {
      enable = true;
      settings = {
        banner = {
          color = "black";
          command = "${pkgs.fastfetch}/bin/fastfetch";
        };
        filesystems = {
          root = "/";
        };
        service_status = {
          tailscale = "tailscaled";
          prometheus-exporter = "prometheus-node-exporter";
          mnt-poweredge-magewe = "mnt-de-msa2_SATA_SSD_POOL_magewe.mount";
          mnt-poweredge-movies = "mnt-de-msa2_SATA_SSD_POOL_movies.mount";
          mnt-poweredge-music = "mnt-de-msa2_SATA_SSD_POOL_music.mount";
          mnt-poweredge-pdfs = "mnt-de-msa2_SATA_SSD_POOL_pdfs.mount";
          mnt-poweredge-series = "mnt-de-msa2_SATA_SSD_POOL_series.mount";
          mnt-poweredge-video = "mnt-de-msa2_SATA_SSD_POOL_video.mount";
          restic-backups-home = "restic-backups-home";
        };
      };
    };
    npm.enable = true;
    # E.g `kani` requires this if installed with `cargo install --locked kani`
    nix-ld = {
      enable = true;
      libraries = [];
    };
  };
  virtualisation = {
    docker.enable = true;
    podman.enable = true;
  };

  services = {
    # Mullvad required `resolved` and being connected disrupts `tailscale` connectivity in the current configuration.
    mullvad-vpn.enable = true;
    resolved.enable = true;
    blueman.enable = true;
    # backup_home_to_remote = {
    #   enable = true;
    #   local_username = "${global_const.username}";
    #   backup_host_addr = "poweredge";
    #   backup_host_name = "poweredge";
    #   backup_host_dir = "/SATA_SSD_POOL/backup_${hostname}";
    # };
    # mount_remote_nfs_exports = {
    #   enable = true;
    #   nfs_host_name = "de-msa2";
    #   nfs_host_addr = "de-msa2";
    #   nfs_dirs = map (dir: "/nvme_pool/${dir}") ["video" "series" "movies" "music" "magewe"];
    # };
    # agentica-chat = {
    #   enable = true;
    #   sourceDir = "/home/m/symbolica/agentica-framework";
    #   environmentFile = "/etc/secrets/agentica-framework";
    #   frontendPort = 5173;
    #   openFirewall = true;
    # };
  };
  programs.steam.enable = true;

  # fileSystems = {
  #   "/mnt/elitedesk_series" = {
  #     device = "${static_ips.elitedesk_ip}:/external_hdd/series";
  #     fsType = "nfs";
  #     options = ["rw" "rsize=131072" "wsize=131072"];
  #   };
  #   "/mnt/elitedesk_movies" = {
  #     device = "${static_ips.elitedesk_ip}:/external_hdd/movies";
  #     fsType = "nfs";
  #     options = ["rw" "rsize=131072" "wsize=131072"];
  #   };
  # };

  sops = {
    defaultSopsFile = "./../../sops_secrets.yaml";
    defaultSopsFormat = "yaml";
  };
  # Make RTX Pro 6000 work.
  environment.sessionVariables = {
    WLR_DRM_DEVICES = "/dev/dri/by-path/pci-0000:01:00.0-card";
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_DRM_NO_ATOMIC = "1";
  };

  # TODO: extract to own module.
  # Use remote builder machine
  # Make sure the `root` user can `ssh` into the host:
  # sudo mkdir -p /root/.ssh
  # sudo cp ~/.ssh/* /root/.ssh/
  # sudo chmod 600 /root/.ssh/*
  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "desg0";
        sshUser = "m";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 4;
        speedFactor = 2;
        systems = ["x86_64-linux"];
        # supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
        # mandatoryFeatures = [];
      }
    ];
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
