# SGLang container for Qwen3.8-27B NVFP4 with DSpark speculative decoding.
#
# SGLang supports the qwen3_5 hybrid GDN (mamba) architecture, vllm does not.
#
# Sizing: 192k context at concurrency 2, in a 48GB cap. llama-cpp gets the
# other half of the 96GB RTX PRO 6000.
#
# VRAM model, measured 2026-08-29:
#   total = 27.4GB fixed + 40.03KB/token of KV pool + 0.296GB/slot of mamba
# The fixed part is weights 21.68 + draft 3.64 + CUDA graphs 1.6 + misc 0.5.
# KV is 40.03KB/token, not the 32.8KB of the ratio formula, because SGLang
# allocates two KV pools. 200k context needs 48.6GB and gets only 12 mamba
# slots, so 192k is better.
#
# --mem-fraction-static is a ceiling on TOTAL GPU memory, not a target. It
# bounds the KV pool. At 0.52 the pool held 267302 tokens, which is less than
# 2 x 196608, so two full-context requests did not fit. 0.58 uses 46.8GB and
# gives a pool of 379988 tokens. That is 1.93x the context, so one request can
# use the full 192k, and two can run together at 190k each.
#
# CAUTION: do not set --max-mamba-cache-size to concurrency x S (= 8).
# That value crashed the scheduler twice on 2026-08-29:
#   mamba_component.py:479  assert slot is not None, "Can not alloc mamba cache"
# The assert came from cache_unfinished_req. extra_buffer_lazy keeps a state
# slot for each cached prefix, not only for each running request. Logs showed
# "mamba num: 6, mamba usage: 0.88" with 2 running requests. 16 slots give the
# radix cache the headroom that 8 slots do not.
#
# A dead scheduler child makes the parent exit 0. Restart=on-failure does not
# fire, so the unit stays inactive. Restart=always corrects this.
#
# Mamba ratio, per the cookbook:
#   ratio = (S + D) x state_bytes / (L x kv_bytes_per_token)
# S = 4 (extra_buffer_lazy), D = gamma+1 = 8, state_bytes = 78.4MB at bf16.
# For L = 192k+1k: (4+8) x 78.4e6 / (197632 x 32.8e3) = 0.145. The pin
# overrides this ratio, so the ratio only sets an upper bound.
#
# Keep --mamba-full-memory-ratio set. Unset, it defaults to 0.9, which
# over-provisions the KV pool and clamps concurrency.
{
  port ? 8000,
  username ? "m",
  model ? "RadixArk/Qwen3.8-27B-NVFP4",
  draftModel ? "RadixArk/Qwen3.8-27B-DSpark",
  # A ceiling, not a target: the engine uses 48.0GB of it.
  memFractionStatic ? "0.58",
  # Not concurrency x S. See the CAUTION in the header.
  maxMambaCacheSize ? 16,
  mambaFullMemoryRatio ? "0.145",
  maxRunningRequests ? 2,
  contextLength ? 196608,
}:

{ config, lib, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.sglang-qwen3 = {
    image = "docker.io/lmsysorg/sglang:qwen38-27b-cu129";
    ports = [ "${toString port}:8000" ];

    volumes = [
      # The JIT caches make container rebuilds fast.
      "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
      "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      "/home/${username}/.triton:/root/.triton"
    ];

    environment = {
      MAX_JOBS = "4";
    };

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
    ];

    # To grow concurrency, this knob cuts S from 4 to 3. It is not part of
    # the verified recipe:
    # environment = { SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK = "1"; }
  };

  # Podman stops with "Error: statfs ...: no such file or directory" when a
  # bind-mount source is absent. Each new volume needs a rule here.
  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache 0755 ${username} users -"
    "d /home/${username}/.cache/flashinfer 0755 ${username} users -"
    "d /home/${username}/.triton 0755 ${username} users -"
  ];

  hardware.nvidia-container-toolkit.enable = true;
  systemd.services.podman-sglang-qwen3 = {
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
    # The first start pulls a 65GB image and takes 17 minutes. Without
    # backoff, five fast restarts burn the start limit and the unit dies.
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = "30s";
    serviceConfig.Restart = lib.mkForce "always";
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
