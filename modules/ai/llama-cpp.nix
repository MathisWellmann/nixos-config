{
  models,
  port ? 9000,
}: {
  pkgs,
  lib,
  ...
}: {
  services.llama-cpp = {
    enable = true;
    openFirewall = true;
    settings = {
      host = "0.0.0.0";
      inherit port;
      # Context
      c = 256000; # context window
      # GPU offload - max layers (96GB VRAM can easily fit this model)
      ngl = 999; # all layers to GPU
      # GPU optimization (Blackwell FA3 native support)
      flash-attn = "on"; # Flash Attention 3
      cache-type-k = "f16"; # KV cache type for K
      cache-type-v = "f16"; # KV cache type for V
      kv-offload = true; # keep KV cache in VRAM
      # Load fully into VRAM (no disk mmap)
      no-mmap = true;
      # CPU / threading (7950X: 16C/32T)
      t = 16; # inference threads
      tb = 16; # batch threads
      b = 2048; # batch size
      ub = 512; # uBatch size
      poll = 80; # high polling for low latency
      prio = 2; # high process priority
      # NUMA / memory (1 NUMA node system)
      numa = "isolate";
      mlock = true; # lock model in RAM (prevent swapping)
      hf = models;
    };
  };
  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
  # ponytail: HUGGINGFACE_HUB_CACHE still needed for model discovery under the dynamic user.
  systemd.services.llama-cpp.serviceConfig.Environment =
    lib.mkAfter ["HUGGINGFACE_HUB_CACHE=/var/cache/llama-cpp/huggingface"];
}
