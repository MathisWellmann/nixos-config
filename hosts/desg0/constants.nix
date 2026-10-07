{
  hostname = "desg0";

  # Qwen3.8-27B server. Served by SGLang (NVFP4 + DSpark) since 2026-07;
  # previously vllm (FP8). Named engine-neutral because other hosts share it.
  qwen3_port = 8000;
  qwen3Model = "RadixArk/Qwen3.8-27B-NVFP4";
  qwen3DraftModel = "RadixArk/Qwen3.8-27B-DSpark";
  # The llama-cpp router itself moved to meshify (hosts/meshify/constants.nix),
  # but the pi-agent clients still point their llama.cpp provider here.
  llama-cpp_port = 8001;
  # Qwen3.8-Flash-Next (Qwen4 preview) served by SGLang. Mutually exclusive
  # with qwen3_port's server: it needs the whole GPU.
  qwen38FlashNext_port = 8003;
  qwen38FlashNextModel = "nvidia/Qwen3.8-Flash-Next-NVFP4";
  nemotron_voicechat_port = 9000;
  minimax_music3_port = 8002;
  # Open WebUI frontend, inference -> sglang on qwen3_port.
  open_webui_port = 8090;
}
