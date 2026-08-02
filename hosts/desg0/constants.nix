_: {
  hostname = "desg0";

  open-webui_port = 3000;
  llama-cpp_port = 8001;
  localModels = [
    # "LiquidAI/LFM2.5-8B-A1B-GGUF:Q8_0"
    "prism-ml/Ternary-Bonsai-27B-gguf:BF16"
  ];
}
