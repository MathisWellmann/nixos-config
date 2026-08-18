# SGLang container for Qwen3.8-27B NVFP4 with DSpark speculative decoding.
#
# Replaces the vllm-qwen3 container (2026-07): SGLang supports the qwen3_5
# hybrid GDN (mamba) architecture with DSpark, vllm does not.
#
# Sizing (96GB RTX PRO 6000, ~48GB reserved for this instance):
# - --mem-fraction-static 0.45 → ~43GB static pool; +~5GB non-static
#   (CUDA context, NCCL, workspace) ≈ 48GB total.
# - --max-mamba-cache-size 80 = 16 concurrent requests × S=5 state slots
#   (extra_buffer strategy). This PINS the GDN state pool; the ratio
#   calculator is overridden. 80 × 78.4MB ≈ 6.3GB.
# - KV pool (fp8_e4m3, 32KB/token) takes the remainder ≈ ~550k tokens
#   ≈ 2× the 256k max context, i.e. full 16-way 256k concurrency is
#   admitted and single-stream decode speed is unaffected by the pool.
# - DSpark: verify slots D = gamma+1 = 8 (auto-inferred from the draft
#   model; do NOT set --speculative-dspark-block-size).
# - bf16 SSM state is mandatory at this budget (fp32 would need ~59GB).
#
# Verified recipe envelope: ISL 8192 / OSL 1024 @ concurrency 1
# (cookbook cell: hw=rtx6000, quant=nvfp4, spec=dspark, tier=low-latency,
# ssmDtype=bfloat16). 256k @ 16 concurrent is unverified — benchmark with
# scripts/vllm_bench.py (or python3 -m sglang.bench_serving) after first boot.
{
  port ? 8000,
  username ? "m",
  model ? "RadixArk/Qwen3.8-27B-NVFP4",
  draftModel ? "RadixArk/Qwen3.8-27B-DSpark",
  memFractionStatic ? "0.45",
  maxMambaCacheSize ? 80,
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
      "--max-running-requests"
      "16"
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
      "extra_buffer"
      "--max-mamba-cache-size"
      (toString maxMambaCacheSize)
      "--reasoning-parser"
      "qwen3"
      "--tool-call-parser"
      "qwen3_coder"
      "--host"
      "0.0.0.0"
      "--port"
      "8000"
    ];

    extraOptions = [
      "--device=nvidia.com/gpu=all"
      "--ipc=host"
    ];

    # Experimental knob, intentionally OFF (not in the verified recipe):
    # environment = { SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK = "1"; } # frees 1 state slot (S=4)
  };

  # GPU access via CDI: ensure the nvidia container toolkit is running.
  hardware.nvidia-container-toolkit.enable = true;
  systemd.services.podman-sglang-qwen3 = {
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
