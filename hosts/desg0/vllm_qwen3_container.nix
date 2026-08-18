# vLLM serving `Qwen/Qwen3.8-27B-FP8` on desg0.
#
# DEPRECATED (2026-07): replaced by sglang_qwen3_container.nix (SGLang +
# NVFP4 + DSpark). Not imported from configuration.nix anymore. Kept as a
# fallback; re-importing it requires disabling the sglang container because
# both 48–57GB footprints plus llama.cpp do not fit on the one GPU.
#
# Qwen3.8 is the `qwen3_5` hybrid architecture: only 16 of its 64 layers run
# full attention (`full_attention_interval: 4`), the other 48 are Gated DeltaNet
# linear attention. It is also multimodal (`Qwen3_5ForConditionalGeneration`,
# with a `vision_config`), though only text serving is verified upstream.
#
# Settings follow the official recipe: https://recipes.vllm.ai/Qwen/Qwen3.8-27B
{
  port ? 8000,
  username ? "m",
  model ? "Qwen/Qwen3.8-27B-FP8",
  # 262144 is the native context. Extensible to 1M, but that additionally needs
  # `--hf-overrides '{"text_config": {"max_position_embeddings": 1010000}}'`
  # (nested under `text_config`, unlike the 2.4T which takes it flat).
  maxModelLen ? 262144,
  maxNumSeqs ? 64,
  # ~27GiB of FP8 weights + KV cache on the 95.6GiB RTX PRO 6000, which also
  # hosts llama.cpp (~27GiB). Raise only when the card is otherwise idle.
  gpuMemoryUtilization ? "0.6",
}: {
  networking.firewall.allowedTCPPorts = [port];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.podman-vllm-qwen3 = {
    after = ["nvidia-container-toolkit-cdi-generator.service"];
    requires = ["nvidia-container-toolkit-cdi-generator.service"];
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.vllm-qwen3 = {
      # `qwen3_5` is unsupported before 0.27.1. The recipe asks for 0.27.2 for
      # MTP speculative decoding, but that is nightly-only -- no such container
      # tag is published -- so MTP stays off and plain serving is
      # code-identical on 0.27.1.
      image = "docker.io/vllm/vllm-openai:v0.27.1-x86_64-cu129";
      ports = ["${toString port}:8000"];
      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
        "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      ];
      environment = {
        MAX_JOBS = "4";
        # The hybrid linear/full-attention stack requires the V2 runner.
        VLLM_USE_V2_MODEL_RUNNER = "1";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
      cmd = [
        model
        "--trust-remote-code"
        "--reasoning-parser"
        "qwen3"
        # Without these, any request with `tool_choice: "auto"` (what agent
        # harnesses like `pi` send) is rejected with a 400 by the OpenAI server.
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        "qwen3_coder"
        # Roughly doubles usable KV cache.
        "--kv-cache-dtype"
        "fp8"
        "--max-num-seqs"
        "${toString maxNumSeqs}"
        "--max-model-len"
        "${toString maxModelLen}"
        "--gpu-memory-utilization"
        gpuMemoryUtilization
        "--host"
        "0.0.0.0"
        "--port"
        "8000"
      ];
    };
  };
}
