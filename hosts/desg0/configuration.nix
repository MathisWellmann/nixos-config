# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  const = import ./constants.nix;
  de-msa2_const = import ../../hosts/de-msa2/constants.nix {};
  global_const = import ../../global_constants.nix;
  forgejo_runner = import ./../../modules/forgejo_runner.nix {
    forgejo_url = "http://de-msa2:${toString de-msa2_const.forgejo_port}";
    state_dir = "/etc/forgejo_runner";
    runner_capacity = 4;
    # Cap CI at 64 of the 192 cores so the co-located k3s control plane
    # (etcd/apiserver/kubelet) is never starved (cf. the 2026-07-02
    # NotReady-flapping incident caused by unbounded nexus builds).
    cpu_quota = "6400%";
    # Deprioritise CI disk I/O 5:1 against the default-weight k3s/etcd units
    # sharing the NVMe -- etcd fsync stalls were the other half of the
    # 2026-07-02 incident. Proportional, so CI keeps full speed on an idle disk.
    io_weight = "20";
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/user_m.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/nix_binary_cache_client.nix
    ./../../modules/ai/local_ai.nix
    (import ./../../modules/ai/oh-my-pi.nix {
      # Served by the sglang container (see sglang_qwen3_container.nix);
      # module/provider names keep the "vllm" prefix for compatibility.
      vllmBaseUrl = "http://127.0.0.1:${toString const.qwen3_port}/v1";
      defaultModel = "vllm/${const.qwen3Model}";
      vllmContextWindow = 262144;
    })
    ./../../modules/k3s_server_follow.nix
    ./../../modules/k3s_nvidia.nix
    # Make the runner's IOWeight actually enforceable: the NVMe uses the
    # `none` scheduler, so proportional io.weight needs blk-iocost (see the
    # module comment).
    (import ./../../modules/blk_iocost.nix {devices = ["nvme0n1"];})
    (import ./../../modules/github_runner.nix {repos = ["symbiont"];})
    (import ./../../modules/ai/pi-agent.nix {
      baseUrl = "http://127.0.0.1:${toString const.llama-cpp_port}/v1";
      enableAgentica = true;
      vllmBaseUrl = "http://127.0.0.1:${toString const.qwen3_port}/v1";
      vllmModels = [const.qwen3Model];
      vllmContextWindow = 262144;
    })
    (import ./../../modules/ai/llama-cpp.nix {
      models = const.localModels;
      port = const.llama-cpp_port;
    })
    # Qwen3.8 server: SGLang replaced vllm (2026-07) — vllm has no support
    # for the qwen3_5 hybrid GDN (mamba) architecture. The vllm 0.6 (~57GB)
    # and sglang (48GB) footprints do not coexist on the one GPU with
    # llama.cpp, so to revert: disable the sglang import and re-enable the
    # commented vllm import below.
    (import ./sglang_qwen3_container.nix {
      port = const.qwen3_port;
      model = const.qwen3Model;
      draftModel = const.qwen3DraftModel;
      inherit (global_const) username;
    })
    # (import ./vllm_qwen3_container.nix {
    #   port = const.qwen3_port;
    #   model = "Qwen/Qwen3.8-27B-FP8";
    #   maxModelLen = 131072;
    #   maxNumSeqs = 64;
    #   inherit (global_const) username;
    # })
    # (import ./../../modules/ai/minimax_music3_container.nix {
    #   port = const.minimax_music3_port;
    #   inherit (global_const) username;
    # })
    # (import ./../../modules/ai/nemotron_voicechat_container.nix {
    #   port = const.nemotron_voicechat_port;
    #   inherit (global_const) username;
    # })
    forgejo_runner
  ];

  networking = {
    hostName = const.hostname;
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "1840e132";
    firewall.allowedTCPPorts = [
      9000 # Local symbiont binary exposing `/metrics`
    ];
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
        command = "${pkgs.fastfetch}/bin/fastfetch";
      };
      filesystems = {
        root = "/";
        home = "/home";
      };
      service_status = {
        tailscale = "tailscaled";
        prometheus-exporter = "prometheus-node-exporter";
        restic-backups-home = "restic-backups-home";
        forgejo_runner = "gitea-runner-default";
        github_runner_symbiont = "github-runner-symbiont";
      };
      uptime.prefix = "up";
    };
  };

  nix.settings.system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];

  virtualisation = {
    docker.enable = true;
    podman.enable = true;
  };
}
