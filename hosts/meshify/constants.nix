{
  # Kev decision-model server (modules/ai/kev.nix)
  kev_port = 8009;
  kevModel = "jaredpalmer/kev-4b";

  # llama.cpp router (modules/ai/llama-cpp.nix), moved here from desg0 where
  # SGLang now owns the whole GPU.
  llama-cpp_port = 8001;
  localModel = "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL";
  # Enabled: only models that run fully on the 24GB RTX 3090 next to the
  # desktop (~3GB VRAM) with the router's 200k-token q8_0 KV pool, shared by
  # 4 slots (hosts/meshify/configuration.nix). Measured on 2026-10-07 with
  # 4 users x 50k-token prompts (README). "spare" = free VRAM left after the
  # weights, the full KV pool, the vision projector and the compute buffers.
  # The commented-out models need more VRAM; re-enable them on a bigger GPU.
  # Clients must use the id the router serves: the tag is cut to its last
  # segment (`:UD-Q4_K_XL` -> `:Q4_K_XL`, modules/ai/llama-cpp-model-id.nix).
  localModels = [
    # Qwen3.8-27B (the model desg0 serves) at 3.5 bpw. The GSQ-RCO card
    # reports BF16-level scores; the tag resolves to the `-mtp` file.
    "ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S" # 11.3GiB + 0.9GiB mmproj, ~0.5GB spare
    "unsloth/Qwen-AgentWorld-35B-A3B-GGUF:UD-IQ4_XS" # 16.6GiB, text only, ~1.5GB spare
    "unsloth/North-Mini-Code-1.0-GGUF:UD-IQ4_XS" # 14.2GiB, text only, ~2.3GB spare
    "unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL" # 13.3GiB + 2.1GiB mmproj, ~1.1GB spare
    "unsloth/gemma-4-12b-it-GGUF:UD-Q8_K_XL" # 12.7GiB + 0.2GiB mmproj, ~4.3GB spare
    "ornith-ai/Ornith-1.5-9B-GGUF:Q8_0" # 9.1GiB + 0.9GiB mmproj, ~7.3GB spare
    # Trained for 128k context only; the router caps their slots at 131072.
    "unsloth/Muse-Glimmer-30B-GGUF:Q4_K_XL" # 14.8GiB + 3.6GiB mmproj, ~0.7GB spare
    "bloomer010/Ling-3.0-tiny-GGUF:UD-Q8_K_XL" # 10.4GiB, text only, ~9.1GB spare
    # The 200k KV pool (6.8GB for this architecture) does not fit next to
    # 16.1GiB of weights: OOM. Qwen3.8-27B above replaces it.
    # "unsloth/Qwen3.6-27B-GGUF:Q4_K_XL" # 16.4GiB + 0.9GiB mmproj
    # Fits text-only, but not with its vision projector (~0.9GB spare before
    # it). The QAT build above is the same model, smaller and faster.
    # "unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M" # 15.8GiB + 1.1GiB mmproj
    # "unsloth/gemma-4-31B-it-qat-GGUF:UD-Q4_K_XL" # 16.1GiB + 2.1GiB F32 mmproj, no room for its SWA cache
    # "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL" # 17.5GiB + 1.1GiB mmproj, no room for its SWA cache
    # "poolside/Laguna-XS-2.1-GGUF:Q4_K_M" # 18.9GiB, only ~6k ctx
    # "InternScience/Agents-A1-Q4_K_M-GGUF" # 19.7GiB
    # "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q4_K_M" # 19.7GiB
    # "ProCreations/grug-35b-qat-q4-gguf:Q4_K_M" # 19.7GiB
    # "bartowski/Kwaipilot_KAT-Coder-V2.5-Dev-GGUF:Q4_K_M" # 19.9GiB
    # "ornith-ai/Ornith-1.5-35B-A3B-GGUF:Q4_K_M" # 20.2GiB
    # "bartowski/endless-frontier_BigBang-v1-GGUF:Q4_K_M" # 20.4GiB
    # "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL" # 21.3GiB
    # "unsloth/Nemotron-3-Nano-30B-A3B-GGUF:Q4_K_M" # 22.9GiB
    # "unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF:UD-Q4_K_M" # 23.5GiB
    # "unsloth/diffusiongemma-26B-A4B-it-GGUF:Q8_0" # 25GiB
    # "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q8_0" # 27.1GiB
    # "InternScience/Agents-A1-Q8_0-GGUF" # 34.4GiB
    # "prism-ml/Ternary-Bonsai-27B-gguf:BF16" # F16 is 50GiB; the tag also matches the dspark draft
    #     "AtomicChat/Ling-3.0-flash-GGUF:Q4_K_S" # 69GiB
  ];
  # Per-model llama-server flags (modules/ai/llama-cpp.nix `modelSettings`).
  # Gemma 4 decodes an image (up to 1120 tokens) with non-causal attention in
  # one ubatch: with the default 512, an image request aborts the process
  # (GGML_ASSERT "non-causal attention requires n_ubatch >= n_tokens").
  # 1152 costs ~+320MiB of compute buffer; gemma-4-26B QAT keeps ~1.1GB spare.
  localModelSettings = {
    "unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL".ubatch-size = 1152;
    "unsloth/gemma-4-12b-it-GGUF:UD-Q8_K_XL".ubatch-size = 1152;
  };
}
