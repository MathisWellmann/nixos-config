{
  models,
  port ? 9000,
}: {
  pkgs,
  lib,
  ...
}: let
  hfFlags = lib.flatten (map (m: ["-hf" m]) models);
in {
  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    inherit port;
    openFirewall = true;
    extraFlags =
      [
        # Context
        "-c"
        "128000" # context window
        # GPU offload - max layers (96GB VRAM can easily fit this model)
        "-ngl"
        "999" # all layers to GPU
        # GPU optimization (Blackwell FA3 native support)
        "--flash-attn"
        "on" # Flash Attention 3
        "--kv-offload" # keep KV cache in VRAM
        # Load fully into VRAM (no disk mmap)
        "--no-mmap"
        "--poll"
        "80" # high polling for low latency
        "--prio"
        "2" # high process priority
        "--mlock" # lock model in RAM (prevent swapping)
      ]
      ++ hfFlags;
  };
  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
  # Fix: llama.cpp with -hf needs HUGGINGFACE_HUB_CACHE to find models
  # under the dynamic user.
  systemd.services.llama-cpp.serviceConfig.Environment =
    lib.mkAfter ["HUGGINGFACE_HUB_CACHE=/var/cache/llama-cpp/huggingface"];
}
