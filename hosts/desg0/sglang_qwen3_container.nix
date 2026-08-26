# SGLang container for Qwen3.8-27B NVFP4 with DSpark speculative decoding.
#
# Replaces the vllm-qwen3 container (2026-07): SGLang supports the qwen3_5
# hybrid GDN (mamba) architecture with DSpark, vllm does not.
#
# Sizing target (2026-08): 256k context at concurrency 2, on the 96GB
# RTX PRO 6000 shared with llama-cpp.service (~20GB resident).
#
# Per the cookbook's mamba ratio calculator:
#   ratio = (S + D) x state_bytes / (L x kv_bytes_per_token)
# where S = state slots/request (extra_buffer_lazy = 4), D = DSpark verify
# slots = gamma+1 = 8, state_bytes = 78.4MB at bf16, kv_bytes_per_token =
# 32.8KB at fp8, and L = avg total request length (input+output).
# For L = 256k+1k: ratio = (4+8) x 78.4e6 / (263168 x 32.8e3) = 0.109.
#
# --mamba-full-memory-ratio was previously UNSET, so it defaulted to 0.9 --
# the exact failure the docs warn about ("the default (0.9) over-provisions
# the KV pool and silently clamps concurrency"). That default, plus
# extra_buffer S=5 pinned at 80 slots, spent ~15.6GB on GDN state and left
# only max_total_num_tokens=21714 -- i.e. the advertised 262144 context
# rejected anything past ~21.7k tokens with HTTP 400.
#
# MEASURED at the prior 128k/concurrency-4 settings (mem-fraction 0.62):
#   max_total_num_tokens=445052; mamba cache 4.1GB; 4x118k concurrent served
#   with 0 errors, 0 retractions; 124k single prompt accepted.
# The 256k/concurrency-2 settings below are derived from the same formula,
# not measured -- check max_total_num_tokens after first boot.
#
# - extra_buffer_lazy lowers S from 5 to 4 "at no accuracy cost" (docs) and
#   is the recommended lever when the state pool bounds concurrency.
# - --max-mamba-cache-size = target_concurrency x S = 2 x 4 = 8. This pins
#   the state pool and overrides the ratio; both are emitted per the docs.
#   D is deliberately NOT folded in -- the engine sizes the verify buffer
#   separately, so including it would over-provision.
# - --context-length 262144 is the checkpoint's native limit; at concurrency
#   2 the pool must cover 2x 256k -- verify max_total_num_tokens on boot.
# - bf16 SSM state halves the state pool vs fp32 (78.4MB vs 153.9MB/slot).
#   Docs flag this as an accuracy gate worth validating for the workload.
#
# Concurrency >4 is possible (~0.52 mem-fraction for 6, ~0.62 for 8 by the
# same formula) but was not validated here; raise max-running-requests and
# max-mamba-cache-size together (pin = concurrency x 4) if needed.
{
  port ? 8000,
  username ? "m",
  model ? "RadixArk/Qwen3.8-27B-NVFP4",
  draftModel ? "RadixArk/Qwen3.8-27B-DSpark",
  memFractionStatic ? "0.62",
  # target_concurrency (2) x S (4, extra_buffer_lazy).
  maxMambaCacheSize ? 8,
  # Balanced ratio for L = 256k input + 1k output; see header.
  mambaFullMemoryRatio ? "0.109",
  maxRunningRequests ? 2,
  contextLength ? 262144,
}:

{ config, lib, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.sglang-qwen3 = {
    image = "docker.io/lmsysorg/sglang:qwen38-27b-cu129";
    ports = [ "${toString port}:8000" ];

    volumes = [
      # Host HuggingFace cache (NVFP4 model + DSpark draft are ~25GB total).
      "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
      # FlashInfer JIT kernels survive container rebuilds.
      "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      # Triton JIT cache (GDN kernels) survives container rebuilds.
      "/home/${username}/.triton:/root/.triton"
    ];

    environment = {
      # Parallelise JIT kernel compilation on first boot (mirrors the vllm
      # container).
      MAX_JOBS = "4";
    };

    # Image entrypoint is nvidia_entrypoint.sh; it execs this cmd.
    cmd = [
      "sglang"
      "serve"
      "--trust-remote-code"
      "--model-path"
      model
      "--kv-cache-dtype"
      "fp8_e4m3"
      "--mamba-ssm-dtype"
      "bfloat16"
      "--mem-fraction-static"
      memFractionStatic
      "--context-length"
      (toString contextLength)
      "--max-running-requests"
      (toString maxRunningRequests)
      "--attention-backend"
      "flashinfer"
      "--chunked-prefill-size"
      "2048"
      "--speculative-algorithm"
      "DSPARK"
      "--speculative-draft-model-path"
      draftModel
      "--speculative-draft-attention-backend"
      "flashinfer"
      "--mamba-radix-cache-strategy"
      "extra_buffer_lazy"
      "--max-mamba-cache-size"
      (toString maxMambaCacheSize)
      "--mamba-full-memory-ratio"
      mambaFullMemoryRatio
      "--reasoning-parser"
      "qwen3"
      "--tool-call-parser"
      "qwen3_coder"
      # Expose Prometheus /metrics on the API port. OFF by default in SGLang;
      # without it the `sglang` scrape job on de-msa2 gets a 404.
      "--enable-metrics"
      "--host"
      "0.0.0.0"
      "--port"
      "8000"
    ];

    extraOptions = [
      "--device=nvidia.com/gpu=all"
      "--ipc=host"
    ];

    # Experimental knob, intentionally OFF (not in the verified recipe). With
    # extra_buffer_lazy (S=4) this would free one more slot for S=3, cutting
    # the state pool further if concurrency needs to grow:
    # environment = { SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK = "1"; }
  };

  # Podman refuses to start when a bind-mount source is missing
  # ("Error: statfs ...: no such file or directory"), so create the JIT cache
  # dirs declaratively. The huggingface cache is created by the download path.
  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache 0755 ${username} users -"
    "d /home/${username}/.cache/flashinfer 0755 ${username} users -"
    "d /home/${username}/.triton 0755 ${username} users -"
  ];

  # GPU access via CDI: ensure the nvidia container toolkit is running.
  hardware.nvidia-container-toolkit.enable = true;
  systemd.services.podman-sglang-qwen3 = {
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
    # The first start pulls a ~65GB image (~17min). Without backoff, five
    # instant restarts burn the start limit and leave the unit dead.
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = "30s";
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
