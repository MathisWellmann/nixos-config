{
  hostname = "desg0";

  vllm_port = 8000;
  llama-cpp_port = 8001;
  nemotron_voicechat_port = 9000;
  vllmModel = "nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4";
  localModels = [
    "InternScience/Agents-A1-Q4_K_M-GGUF"
    "unsloth/Qwen3.6-27B-GGUF:Q4_K_XL"
    "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q4_K_M"
    "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL"
    "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL"
    "unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M"
    "unsloth/Muse-Glimmer-30B-GGUF:Q4_K_XL"
    "AtomicChat/Ling-3.0-flash-GGUF:Q4_K_S"
    "bartowski/Kwaipilot_KAT-Coder-V2.5-Dev-GGUF:Q4_K_M"
    "bartowski/endless-frontier_BigBang-v1-GGUFF:Q4_K_M"
    "ProCreations/grug--35b-qat-q4-gguf:Q4_K_M"
  ];
}
