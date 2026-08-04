{
  vllm_port = 8000;
  llama-cpp_port = 8001;
  vllmModel = "nvidia/Qwen3.6-35B-A3B-NVFP4";
  localModel = "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL";
  localModels = [
    "InternScience/Agents-A1-Q4_K_M-GGUF"
    "InternScience/Agents-A1-Q8_0-GGUF" # Fast at ~120TPS
    "unsloth/Qwen3.6-27B-GGUF:Q4_K_XL"
    "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q4_K_M"
    "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL"
    "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL"
    "unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M"
  ];
}
