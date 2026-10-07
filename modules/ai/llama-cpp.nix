{
  models,
  port ? 9000,
  # Host-specific overrides merged over the defaults below. The defaults were
  # tuned for desg0's 96GB card; a `null` value drops the flag, so a smaller
  # host can fall back to llama-server's own (auto) default.
  extraSettings ? {},
  # Per-model llama-server flags, keyed by the entry in `models`; rendered
  # into that model's preset section (flag name without the dashes).
  modelSettings ? {},
}: {
  pkgs,
  lib,
  ...
}: let
  global_const = import ../../global_constants.nix;
  modelId = import ./llama-cpp-model-id.nix {inherit lib;};
  # Sections use the id the router serves anyway (see llama-cpp-model-id.nix),
  # so the INI shows the real model names. The router also lists every model
  # in the HF cache; `dedup-cache-models` hides cache entries that resolve to
  # a preset's file under another name (e.g. `...-IQ3_S-mtp.gguf` as `:MTP`).
  modelsPreset = pkgs.writeText "llama-models.ini" (''
      version = 1
    ''
    + lib.concatMapStringsSep "\n" (model:
      ''
        [${modelId model}]
        hf-repo = ${model}
        dedup-cache-models = 1
      ''
      + lib.concatStrings (lib.mapAttrsToList (key: value: "${key} = ${toString value}\n")
        (modelSettings.${model} or {})))
    models);
in {
  services.llama-cpp = {
    enable = true;
    openFirewall = true;
    settings =
      {
        host = "0.0.0.0";
        inherit port;
        ctx-size = 256000;
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
        # Prometheus exporter: llama-server only serves GET /metrics (router mode
        # requires `?model=<id>`; scrape with `&autoload=false` so scrapes of an
        # unloaded model 400 instead of evicting the active model).
        metrics = true;
      }
      // extraSettings;
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
