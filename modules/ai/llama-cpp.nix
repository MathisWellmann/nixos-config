{
  models,
  port ? 9000,
}: {
  pkgs,
  lib,
  ...
}: let
  global_const = import ../../global_constants.nix;
  modelsPreset = pkgs.writeText "llama-models.ini" (''
      version = 1
    ''
    + lib.concatMapStringsSep "\n" (model: ''
      [${model}]
      hf-repo = ${model}
    '')
    models);
in {
  services.llama-cpp = {
    enable = true;
    openFirewall = true;
    settings = {
      host = "0.0.0.0";
      inherit port;
      # Context
      ctx-size = 256000; # context window
      # GPU offload - max layers (96GB VRAM can easily fit this model)
      n-gpu-layers = 999; # all layers to GPU
      # GPU optimization (Blackwell FA3 native support)
      flash-attn = "on"; # Flash Attention 3
      cache-type-k = "f16"; # KV cache type for K
      cache-type-v = "f16"; # KV cache type for V
      kv-offload = true; # keep KV cache in VRAM
      # No top-level model: this starts llama-server in router mode. Requests are
      # routed by their OpenAI `model` field and models load on demand.
      models-preset = modelsPreset;
      models-max = 1;
      # no-mmap = true; # Load fully into VRAM (no disk mmap)
      threads = 64; # inference threads
      threads-batch = 64; # batch threads
      batch-size = 2048; # batch size
      ubatch-size = 512; # uBatch size
      poll = 80; # high polling for low latency
      prio = 2; # high process priority
      # NUMA / memory (1 NUMA node system)
      numa = "isolate";
      mlock = true; # lock model in RAM (prevent swapping)
    };
  };
  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
  # HUGGINGFACE_HUB_CACHE and LLAMA_CACHE
  systemd.services.llama-cpp.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = global_const.username;
    Group = "users";
    Environment = [
      "HUGGINGFACE_HUB_CACHE=/home/${global_const.username}/.cache/llama-cpp"
      "LLAMA_CACHE=/home/${global_const.username}/.cache/llama-cpp"
    ];
    ProtectHome = lib.mkForce false;
  };
}
