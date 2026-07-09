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
      c = 128000; # context window
      # GPU offload - max layers (96GB VRAM can easily fit this model)
      ngl = 999; # all layers to GPU
      # GPU optimization (Blackwell FA3 native support)
      flash-attn = "on"; # Flash Attention 3
      kv-offload = true; # keep KV cache in VRAM
      # Load fully into VRAM (no disk mmap)
      no-mmap = true;
      poll = 80; # high polling for low latency
      prio = 2; # high process priority
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
