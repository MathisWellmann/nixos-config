# SGLang container for Qwen3.8-27B NVFP4 with DSpark speculative decoding.
#
# SGLang supports the qwen3_5 hybrid GDN (mamba) architecture, vllm does not.
#
# Sizing: FULL GPU since 2026-09-10. llama-cpp is commented out in
# configuration.nix, so this owns all 96GB of the RTX PRO 6000. The call site
# overrides the defaults below to 0.93 / 16 / 128 / 262144.
#
# CURRENT (2026-09-10): mem-fraction 0.93, conc 24, 144 mamba slots, 256k.
#   max_total_num_tokens = 926,249   <- fp8 KV pool, shared by ALL requests
#   available_gpu_mem 2.13GB after capture; 95594MiB of 97887MiB resident
#
# CONCURRENCY IS A KV-POOL TRADE, NOT A FREE KNOB.
# DSpark's intermediate mamba buffer scales with concurrency x draft tokens
# (per_req 74.8MB x (conc+1) x 8), so raising concurrency SHRINKS the KV
# pool hard. Measured at mem-fraction 0.93, pin = conc x 4:
#   conc 16 (pin 128): pool 1,072,169  free 2.55GB   1166 tok/s
#   conc 24 (pin  96): pool 1,013,801  free 2.09GB   1390 tok/s
#   conc 24 (pin 144): pool   926,249  free 2.13GB   <- CHOSEN
#   conc 32 (pin 128): pool   838,697  free 1.81GB   1531 tok/s
#   conc 64 (pin 256): pool   138,281  free 0.58GB   1656 tok/s
# conc 64 wins on raw throughput (+42%) but its 138k pool cannot hold even
# ONE 200k request, so it is useless for long-context agents. 24 is the knee.
#
# Sweep at the chosen config, 1k prompt / 1k output, ignore_eos, 0 errors:
#   c=1 243.0 | c=4 793.7 | c=8 812.3 | c=16 1265.6 | c=24 1390.1 tok/s
#
# Validated against the real workload (0 errors, nothing crashed):
#   4 agents x 200k ctx  -> all 4 complete, TTFT med 206s, max 274s
#   16 agents x 100k ctx -> all 16 complete, TTFT med 196s, max 362s
# The 16x100k case needs 1.6M tokens against a 926k pool. SGLang QUEUES and
# preempts instead of failing; token usage peaked 0.91 with no retraction.
# So oversubscribing the pool costs latency, never errors.
#
# Prefix caching is what makes this usable: a repeated 100k prompt goes
# 24.3s -> 1.9s (12.8x). Agent turn 2+ hits the cache, so the ~200s TTFT is
# a cold-start worst case, not the steady state.
#
# Over-length input is rejected cleanly at admission:
#   260,052 tokens -> HTTP 200;  270,052 -> HTTP 400 "longer than the
#   model's context length (262144 tokens)". Never a crash.
#
# WARNING: available_gpu_mem is only 2.13GB.
#  - Do NOT raise mem-fraction-static past 0.93.
#  - Do NOT raise --chunked-prefill-size past 2048. 8192 was tried and OOMed
#    during prefill CUDA-graph capture ("markCaptureEnd called with no
#    captures in progress" + CUDA out of memory).
#
# --mem-fraction-static is a ceiling on TOTAL GPU memory, not a target. It
# bounds the KV pool, so it must be raised together with context.
#
# An explicit --max-mamba-cache-size BYPASSES --mamba-full-memory-ratio:
# kv_cache_configurator.py takes the "from_max_running_requests" branch and
# gives the mamba pool exactly the pinned slot count, leaving everything else
# to KV. The ratio only applies when the pin is absent, where it splits the
# budget r/(1+r) toward mamba. So the 0.145 below is informational at the
# current call site, not a constraint.
#
# Historic (llama-cpp era, 48GB cap): 0.58 / conc 2 / 192k gave a pool of
# 379988 tokens and used 46.8GB. Restore those if llama-cpp comes back.
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
