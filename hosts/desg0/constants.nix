{
  hostname = "desg0";

  vllm_port = 8000;
  llama-cpp_port = 8001;
  nemotron_voicechat_port = 9000;
  minimax_music3_port = 8002;
  vllmModel = "Qwen/Qwen3.8-27B-FP8";
  localModels = [
    "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL"
    "unsloth/Qwen3.6-27B-GGUF:Q4_K_XL"
    "InternScience/Agents-A1-Q4_K_M-GGUF"
    "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q4_K_M"
    "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q8_0"
    "prism-ml/Ternary-Bonsai-27B-gguf:BF16"
    "ProCreations/grug-35b-qat-q4-gguf:Q4_K_M"
    "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL"
    "unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M"
    "unsloth/diffusiongemma-26B-A4B-it-GGUF:Q8_0"
    "unsloth/gemma-4-12b-it-GGUF:UD-Q8_K_XL"
    "unsloth/Muse-Glimmer-30B-GGUF:Q4_K_XL"
    "AtomicChat/Ling-3.0-flash-GGUF:Q4_K_S"
    "bartowski/Kwaipilot_KAT-Coder-V2.5-Dev-GGUF:Q4_K_M"
    "bartowski/endless-frontier_BigBang-v1-GGUF:Q4_K_M"
    "poolside/Laguna-XS-2.1-GGUF:Q4_K_M"
    "unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q4_K_M"
    "unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF:UD-Q4_K_M"
    "bloomer010/Ling-3.0-tiny-GGUF:UD-Q8_K_XL"
  ];
}
