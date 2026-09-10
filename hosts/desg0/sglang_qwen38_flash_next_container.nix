# SGLang container for Qwen3.8-Flash-Next NVFP4 (the NVIDIA export).
#
# Qwen4 preview architecture (`qwen4_exp`): 176B total / 6B active MoE, 512
# experts, GDN + QSA hybrid attention, an in-checkpoint MTP head, and a 51B
# N-gram (PLE) embedding table. Only sglang serves this; vllm has no loader.
#
# Derived from the verified cookbook cell
#   hw=rtx6000 quant=nvfp4-nvda strategy=high-throughput nodes=single pleOffload=on
# https://docs.sglang.io/cookbook/autoregressive/Qwen/Qwen3.8-Flash-Next
#
# This model wants the WHOLE GPU. Stop the Qwen3.8-27B sglang container and
# llama-cpp before starting it. They cannot coexist: the checkpoint alone is
# 78GiB resident on a 96GB card.
#
# THE NVIDIA EXPORT MUST NOT GET --quantization.
# nvidia/Qwen3.8-Flash-Next-NVFP4 is a ModelOpt MIXED_PRECISION export and
# resolves itself to `modelopt_mixed`. Passing `--quantization modelopt_fp4`
# (which the RadixArk export DOES need) makes the load fail. Loading it at all
# needs sglang PR #38121, which is why the image is pinned to
# `dev-qwen38-next-local`; the `qwen38flashnext` image predates the loader.
#
# PLE OFFLOAD IS MANDATORY ON THIS CARD, NOT AN OPTIMISATION.
# The 47.7GiB FP8 N-gram table goes to CPU pinned memory via
# --ple-offload-embedding; the other 78GiB of the checkpoint goes on-card.
# That requires >=64GB of free HOST RAM (desg0 has 503GB) and an unlimited
# memlock rlimit on the container, or the pinned allocation fails outright.
#
# MEASURED 2026-09-10 (this exact config, GPU otherwise idle):
#   max_total_num_tokens = 99456   <- the whole KV pool, shared by ALL requests
#   KV cache   bf16, K 1.14GB + V 1.14GB
#   Mamba      192 slots, conv_state 0.40GB + ssm_state 10.18GB
#   Resident   92.9GiB of 95.6GiB; available_gpu_mem 5.41GB after capture
#   Startup    ~8min to /health 200 (weights load ~75GB, then pools+graphs)
# Sweep, 1024-token prompt / 256 output tokens, unique prefixes, 0 errors:
#   c=1 89.2 | c=2 153.1 | c=4 276.1 | c=8 356.5 | c=16 612.7
#   c=32 851.0 | c=48 1020.6 | c=64 953.1 out tok/s
# Peak is c=48. c=64 regresses because the KV pool saturates, not the SMs:
# 64 x (1024+512) = 98304 tok = 98.8% of the 99456 pool, and token_usage was
# observed at 0.97 with 63 running / 1 queued. With 512-output tokens c=64
# reaches 1117 tok/s, so the dip is workload-shaped, not a hard ceiling.
#
# CONTEXT IS 128k, NOT THE 256k THE COOKBOOK CELL PRINTS.
# The cookbook cell says --context-length 262144, but on this card that is a
# lie the KV pool cannot back: after 78GiB of weights, mem-fraction-static
# 0.93 leaves a pool of only ~98k tokens (0.94 gives ~138k). A 256k request
# would be accepted by the length check and then fail to allocate mid-flight.
# 131072 is set instead so over-long inputs are cleanly rejected with HTTP 400
# at admission. The KV pool, not --context-length, is the real limit here:
# the pool is shared by ALL running requests, so 64-way concurrency means
# ~1.5k tokens each, not 128k each. Scale --max-running-requests down for
# genuine long-context work.
#
# Mamba/GDN state slots are the other scarce pool. The scheduler clamps
# --max-running-requests to what the state pool admits: only 12 with the
# default `extra_buffer` strategy. Reaching 64 takes all three levers, and
# they are load-bearing, not decorative:
#   --mamba-radix-cache-strategy extra_buffer_lazy  4 slots/req instead of 5
#   SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK=1             3 slots/req; a running
#     request's prefix state stops being pinned in the radix tree during
#     decode, so it can be evicted. Trades cache retention, not numerics.
#   --mamba-ssm-dtype bfloat16                      0.055GiB/slot, not 0.109
# --max-mamba-cache-size is then pinned to requests x 3 = 192. Unlike the
# 27B container there is no known headroom bug here, but the same rule holds:
# do not cut this below requests x 3 (see sglang_qwen3_container.nix).
#
# mem-fraction-static 0.93 is an OOM-margin choice, not a throughput one.
# 4096-token prefill chunks peak 1.5-2.6GB above the post-graph-capture
# level, and cells left with 2.4GB free OOMed in the GDN short-conv during
# prefill. 0.93 keeps >=4GB free after capture and >=2.3GB at peak.
#
# No speculative decoding in this cell. The in-checkpoint MTP head is the
# low-latency cell's trick; it costs 4 extra draft state slots per request
# and caps concurrency near 20. High-throughput drops it for 64-way.
{
  port ? 8003,
  username ? "m",
  model ? "nvidia/Qwen3.8-Flash-Next-NVFP4",
  # A ceiling on total GPU memory, not a target. See the header.
  memFractionStatic ? "0.93",
  maxRunningRequests ? 64,
  # Pinned to maxRunningRequests x 3. Do not lower independently.
  maxMambaCacheSize ? 192,
  # NOT 262144: the KV pool cannot back it. See the header.
  contextLength ? 131072,
}:

{ config, lib, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.sglang-qwen38-flash-next = {
    # Pinned: this build carries the #38121 MIXED_PRECISION loader that the
    # NVIDIA export needs. `qwen38flashnext` cannot load it.
    image = "docker.io/lmsysorg/sglang:dev-qwen38-next-local";
    ports = [ "${toString port}:8000" ];

    volumes = [
      # The JIT caches make container rebuilds fast.
      "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
      "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      "/home/${username}/.triton:/root/.triton"
    ];

    environment = {
      MAX_JOBS = "4";
      # The pools are sized to the GiB; fragmentation is what OOMs the GDN
      # short-conv during prefill.
      PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
      # Third of the three levers that get concurrency from 12 to 64.
      SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK = "1";
    };

    cmd = [
      "sglang"
      "serve"
      "--model-path"
      model
      # Deliberately NO --quantization: the NVIDIA export self-resolves to
      # modelopt_mixed and rejects an explicit one. See the header.
      "--tp"
      "1"
      "--fp4-gemm-backend"
      "flashinfer_cutlass"
      "--moe-runner-backend"
      "flashinfer_cutlass"
      # Mandatory on a 96GB card: parks the 47.7GiB FP8 N-gram table in
      # pinned host RAM.
      "--ple-offload-embedding"
      "--page-size"
      "64"
      "--mamba-track-interval"
      "64"
      "--chunked-prefill-size"
      "4096"
      "--context-length"
      (toString contextLength)
      "--mamba-radix-cache-strategy"
      "extra_buffer_lazy"
      "--max-running-requests"
      (toString maxRunningRequests)
      "--max-mamba-cache-size"
      (toString maxMambaCacheSize)
      "--mamba-ssm-dtype"
      "bfloat16"
      "--mem-fraction-static"
      memFractionStatic
      "--reasoning-parser"
      "qwen3"
      # Without this flag the `sglang` scrape job on de-msa2 gets a 404.
      "--enable-metrics"
      "--host"
      "0.0.0.0"
      "--port"
      "8000"
    ];

    extraOptions = [
      "--device=nvidia.com/gpu=all"
      "--ipc=host"
      # The pinned 47.7GiB PLE table needs an unlimited memlock rlimit.
      # Without this the allocation fails and the server never starts.
      # NOTE: no --shm-size. The cookbook's docker line sets --shm-size 32g,
      # but podman rejects it together with --ipc=host ("cannot set shmsize
      # when running in the {host } IPC Namespace"). --ipc=host already gives
      # the container the host's unlimited /dev/shm, so it is redundant.
      "--ulimit=memlock=-1:-1"
    ];
  };

  # Podman stops with "Error: statfs ...: no such file or directory" when a
  # bind-mount source is absent. Each new volume needs a rule here.
  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache 0755 ${username} users -"
    "d /home/${username}/.cache/flashinfer 0755 ${username} users -"
    "d /home/${username}/.triton 0755 ${username} users -"
  ];

  hardware.nvidia-container-toolkit.enable = true;
  systemd.services.podman-sglang-qwen38-flash-next = {
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
    # The first start pulls a large image and a 78GiB checkpoint. Without
    # backoff, five fast restarts burn the start limit and the unit dies.
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = "30s";
    # A dead scheduler child makes the parent exit 0, so Restart=on-failure
    # (the oci-containers default) never fires and the unit sits inactive.
    serviceConfig.Restart = lib.mkForce "always";
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
