_: {
  open-webui_port = 8080;
  vllm_port = 8000;
  llama-cpp_port = 8001;
  tensorrt_port = 8002;
  localModel = "unsloth/gemma-4-31B-it-GGUF:UD-Q8_K_XL";
  localModels = [
    "unsloth/gemma-4-31B-it-GGUF:UD-Q8_K_XL"
    "InternScience/Agents-A1-Q8_0-GGUF"
    "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q8_0"
  ];
}
