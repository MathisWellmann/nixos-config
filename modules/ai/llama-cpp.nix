{
  model,
  port ? 9000,
}: {
  pkgs,
  lib,
  ...
}: {
  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    inherit port;
    openFirewall = true;
    extraFlags = [
      # Context
      "-c"
      "256000" # context window
      # GPU offload - max layers (96GB VRAM can easily fit this model)
      "-ngl"
      "999" # all layers to GPU
      # HuggingFace source
      "-hf"
      model # huggingface model source
      # GPU optimization (Blackwell FA3 native support)
      "--flash-attn"
      "on" # Flash Attention 3
      "--cache-type-k"
      "f16" # KV cache type for K
      "--cache-type-v"
      "f16" # KV cache type for V
      "--kv-offload" # keep KV cache in VRAM
      # Load fully into VRAM (no disk mmap)
      "--no-mmap"
      # CPU / threading (7950X: 16C/32T)
      "-t"
      "16" # inference threads
      "-tb"
      "16" # batch threads
      "-b"
      "2048" # batch size
      "-ub"
      "512" # uBatch size
      "--poll"
      "80" # high polling for low latency
      "--prio"
      "2" # high process priority
      # NUMA / memory (1 NUMA node system)
      "--numa"
      "isolate"
      "--mlock" # lock model in RAM (prevent swapping)
    ];
  };
  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
  # Fix: llama.cpp with -hf needs HUGGINGFACE_HUB_CACHE to find models
  # under the dynamic user.
  systemd.services.llama-cpp.serviceConfig.Environment =
    lib.mkAfter ["HUGGINGFACE_HUB_CACHE=/var/cache/llama-cpp/huggingface"];
}
