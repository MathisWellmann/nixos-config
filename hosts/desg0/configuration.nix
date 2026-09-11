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
      # Must match --context-length in sglang_qwen3_container.nix. The server
      # rejects longer inputs with HTTP 400.
      vllmContextWindow = 262144;
    })
    ./../../modules/k3s_server_follow.nix
    ./headlong.nix
    ./../../modules/k3s_nvidia.nix
    # Make the runner's IOWeight actually enforceable: the NVMe uses the
    # `none` scheduler, so proportional io.weight needs blk-iocost (see the
    # module comment).
    (import ./../../modules/blk_iocost.nix {devices = ["nvme0n1"];})
    (import ./../../modules/github_runner.nix {repos = ["symbiont"];})
    (import ./../../modules/ai/pi-agent.nix {
      # Was llama-cpp_port; that module is disabled (sglang owns the GPU),
      # so the default backend is the sglang server too.
      baseUrl = "http://127.0.0.1:${toString const.qwen3_port}/v1";
      enableAgentica = true;
      vllmBaseUrl = "http://127.0.0.1:${toString const.qwen3_port}/v1";
      vllmModels = [const.qwen3Model];
      # Must match --context-length in sglang_qwen3_container.nix.
      vllmContextWindow = 262144;
    })
    # Web frontend for the sglang server.
    (import ./open_webui.nix {
      port = const.open_webui_port;
      inferenceUrl = "http://host.docker.internal:${toString const.qwen3_port}/v1";
    })
    # DISABLED 2026-09-10: sglang now takes the whole 96GB GPU
    # (mem-fraction-static 0.93, ~95GB resident) so llama.cpp's ~20GB no
    # longer fits. Re-enable this together with lowering memFractionStatic
    # back to 0.58 on the sglang import below.
    # (import ./../../modules/ai/llama-cpp.nix {
    #   models = const.localModels;
    #   port = const.llama-cpp_port;
    # })
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
      # Full-GPU tuning (2026-09-10): llama-cpp is off, so this no longer
      # shares the card. See the module header for the sizing.
      memFractionStatic = "0.93";
      # 24, not 16: measured 2026-09-10, it costs only 5% of the KV pool
      # (1,072,169 -> 1,013,801) and buys +19% throughput (1166 -> 1390
      # tok/s). Do NOT go to 32+: DSpark's intermediate mamba buffer scales
      # with concurrency and eats the pool (32 -> 838k, 64 -> 138k, which
      # cannot hold even ONE 200k request).
      maxRunningRequests = 24;
      # 1.5x the 24x4=96 running-request floor. The bare floor is what
      # crashed the scheduler in 2026-08 via the radix-cache path
      # (extra_buffer_lazy keeps a slot per cached prefix too), so it needs
      # headroom. 144 costs 87k KV tokens (1,013,801 -> 926,249) and ran
      # clean under sustained 24-way load with mamba usage 0.02-0.04.
      maxMambaCacheSize = 144;
      contextLength = 262144;
    })
    # Qwen3.8-Flash-Next (Qwen4 preview, 176B/6B MoE) on port 8003. MUTUALLY
    # EXCLUSIVE with the sglang import above and with llama-cpp: the
    # checkpoint is 78GiB resident on the 96GB card even with the PLE table
    # offloaded to host RAM. To use it, comment out the sglang_qwen3
    # container and the llama-cpp import, then uncomment this.
    # (import ./sglang_qwen38_flash_next_container.nix {
    #   port = const.qwen38FlashNext_port;
    #   model = const.qwen38FlashNextModel;
    #   inherit (global_const) username;
    # })
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
      const.headlong_web_port # Headlong web viewer (systemd `headlong-web`)
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
