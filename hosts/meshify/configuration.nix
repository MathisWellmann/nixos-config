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
  const = import ./constants.nix;
  const_desg0 = import ./../desg0/constants.nix;
  global_const = import ../../global_constants.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ./../../modules/user_m.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/mullvad_tailscale.nix
    ./../../modules/remote_builder.nix
    ./../../modules/mount_remote_nfs_exports.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/yubi_key.nix
    ./../../modules/ai/qwen_code.nix
    ./../../modules/ai/local_ai.nix
    (import ./../../modules/ai/oh-my-pi.nix {
      defaultModel = "vllm/${const_desg0.qwen3Model}";
    })
    (import ../../modules/ai/hermes_agent.nix {
      model = const.localModel;
    })
    (import ./../../modules/ai/pi-agent.nix {
      baseUrl = "http://desg0:${toString const_desg0.llama-cpp_port}/v1";
      vllmBaseUrl = "http://desg0:${toString const_desg0.qwen3_port}/v1";
      vllmModels = [const_desg0.qwen3Model];
    })
    # monero_miner
  ];
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # Workaround: nixpkgs regression where the initrd activation script runs before
    # /proc and /sys are mounted, so it can't write firmware_class.path or modprobe path.
    # Setting firmware path on the kernel command line ensures it's available from boot start.
    kernelParams = ["firmware_class.path=${config.hardware.firmware}/lib/firmware"];
    initrd.systemd.services."modprobe@".serviceConfig.ExecStart = lib.mkForce "-${pkgs.kmod}/sbin/modprobe -abq %i";
  };
  systemd.services."modprobe@".serviceConfig.ExecStart = lib.mkForce "-${pkgs.kmod}/sbin/modprobe -abq %i";

  # /dev/dri/cardN numbering is not stable (boot simple-framebuffer + amdgpu/nvidia
  # probe order), so a hardcoded card1 can point Hyprland at the AMD iGPU, which has
  # no monitors connected -> headless fallback / black screen. All monitors are on
  # the RTX 3090. by-path names can't be used since aquamarine splits on ':'.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="nvidia", SYMLINK+="dri/nvidia-card"
  '';
  environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/nvidia-card";

  age = {
    # agenix skips identities that are not present.
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/${global_const.username}/.ssh/magewe_meshify"
    ];
    # Token for ~/.kube/k3s.yaml (home/meshify.nix, env/cluster_access.nix).
    secrets.k3s_meshify_admin_token = {
      file = ../../secrets/k3s_meshify_admin_token.age;
      owner = global_const.username;
      mode = "0400";
    };
  };

  networking = {
    hostName = "${hostname}";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [
      1234 # LM studio
      9000 # Local symbiont binary exposing `/metrics`
    ];
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
          color = "white";
          command = "${pkgs.fastfetch}/bin/fastfetch";
        };
        filesystems = {
          root = "/";
        };
        service_status = {
          tailscale = "tailscaled";
          prometheus-exporter = "prometheus-node-exporter";
          mnt-de-msa2-magewe = "mnt-de_msa2_nvme_pool_magewe.mount";
          mnt-de-msa2-music = "mnt-de_msa2_nvme_pool_music.mount";
          mnt-de-msa2-video = "mnt-de_msa2_nvme_pool_video.mount";
          mnt-de-msa2-pdfs = "mnt-de_msa2_nvme_pool_pdfs.mount";
          mnt-de-msa2-movies = "mnt-de_msa2_movies.mount";
          mnt-de-msa2-series = "mnt-de_msa2_series.mount";
          restic-backups-home = "restic-backups-home";
        };
      };
    };
    npm.enable = true;
  };
  virtualisation = {
    docker.enable = true;
    podman.enable = true;
  };

  services = {
    blueman.enable = true;
    mount_remote_nfs_exports = {
      enable = true;
      nfs_host_name = "de-msa2";
      nfs_host_addr = "de-msa2";
      nfs_dirs = map (dir: "/nvme_pool/${dir}") ["video" "music" "magewe" "pdfs"];
    };
  };
  fileSystems = {
    # The media drive moved from elitedesk to de-msa2 (2026-08-08).
    "/mnt/de_msa2_movies" = {
      device = "de-msa2:/mnt/external_hdd/movies";
      fsType = "nfs";
      options = ["rw" "nofail"];
    };
    "/mnt/de_msa2_series" = {
      device = "de-msa2:/mnt/external_hdd/series";
      fsType = "nfs";
      options = ["rw" "nofail"];
    };
  };

  programs.steam.enable = true;

  sops = {
    defaultSopsFile = "./../../sops_secrets.yaml";
    defaultSopsFormat = "yaml";
  };
}
