# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  const = import ./constants.nix;
  de-msa2_const = import ../../hosts/de-msa2/constants.nix;
  global_const = import ../../global_constants.nix;
  forgejo_runner = import ./../../modules/forgejo_runner.nix {
    forgejo_url = "http://de-msa2:${toString de-msa2_const.forgejo_port}";
    state_dir = "/etc/forgejo_runner";
    runner_capacity = 8;
    # Cap CI at 96 of the 192 cores so the co-located k3s control plane
    # (etcd/apiserver/kubelet) is never starved (cf. the 2026-07-02
    # NotReady-flapping incident caused by unbounded nexus builds).
    cpu_quota = "9600%";
    # Deprioritise CI disk I/O 5:1 against the default-weight k3s/etcd units
    # sharing the NVMe -- etcd fsync stalls were the other half of the
    # 2026-07-02 incident. Proportional, so CI keeps full speed on an idle disk.
    io_weight = "20";
    runners = [
      {
        name = "default";
        tokenFile = "/etc/secrets/forgejo_runner";
        labels = ["native:host"];
      }
      {
        name = "monty-persona";
        runner_name = "desg0-monty";
        tokenFile = "/etc/secrets/forgejo_runner_monty-persona";
        labels = ["native:host"];
      }
    ];
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
    ./../../modules/k3s_nvidia.nix
    # Make the runner's IOWeight actually enforceable: the NVMe uses the
    # `none` scheduler, so proportional io.weight needs blk-iocost (see the
    # module comment).
    (import ./../../modules/blk_iocost.nix {devices = ["nvme0n1"];})
    (import ./../../modules/github_runner.nix {repos = ["symbiont"];})
    # Nightly: bump flake.lock, build every host, push to attic, commit the lock.
    (import ./../../modules/nixos_cache_builder.nix {
      hosts = ["de-msa2" "de-n5" "desg0" "meshify" "poweredge" "razerblade" "superserver" "tensorbook"];
      # The repair agent runs against the local sglang server configured just
      # below, so a broken build is diagnosed without leaving the host.
      agent_model = "vllm/${const.qwen3Model}";
    })
    (import ./../../modules/ai/pi-agent.nix {
      # Was llama-cpp_port; that module is disabled (sglang owns the GPU),
      # so the default backend is the sglang server too.
      baseUrl = "http://127.0.0.1:${toString const.qwen3_port}/v1";
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
    # The llama-cpp router moved to meshify (2026-10-07): sglang takes the
    # whole 96GB GPU here (mem-fraction-static 0.93, ~95GB resident).
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
      # 12, from production metrics (2026-09-11..2026-10-03, ~47k-token
      # median prompts; plot in docs/diagrams/sglang-concurrency-sweetspot.png).
      # The 2026-09-10 sweep that chose 24 used 1k-token prompts, so it did
      # not show the cost of long prefills. With the real workload, 12 -> 13
      # is a cliff: ITL 30 -> 73 ms, TTFT 7 -> 19 s, decode halves, because
      # 50k prefills take the place of decode steps. Decode peaks at 8, and
      # decode+prefill is ~3.3k tok/s at 12. KV usage is only ~0.6 there, so
      # compute is the limit. Above 12, requests now wait in the queue and
      # do not slow down every running stream. Do NOT go to 32+: DSpark's
      # intermediate mamba buffer scales with concurrency and eats the pool.
      maxRunningRequests = 12;
      # Kept from the conc-24 config: 1.5x its 24x4=96 running-request
      # floor. The bare floor crashed the scheduler in 2026-08 via the
      # radix-cache path (extra_buffer_lazy keeps a slot per cached prefix
      # too), so it needs headroom. For conc 12 this is 3x the 48 floor: too
      # large but safe. A smaller pin would give back KV tokens (144 costs
      # 87k: 1,013,801 -> 926,249), but that is not tested yet.
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
        color = "white";
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
        nixos_cache_builder = "nixos-cache-builder.timer";
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
