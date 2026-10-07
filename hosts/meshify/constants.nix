{
  # Kev decision-model server (modules/ai/kev.nix)
  kev_port = 8009;
  kevModel = "jaredpalmer/kev-4b";

  # llama.cpp router (modules/ai/llama-cpp.nix), moved here from desg0 where
  # SGLang now owns the whole GPU.
  llama-cpp_port = 8001;
  localModel = "unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL";
  # Enabled: only models that run fully on the 24GB RTX 3090 next to the
  # desktop (~3GB VRAM) with at least 32k tokens of q8_0 KV cache. Estimated
  # from the GGUF + mmproj sizes and GGUF metadata (2026-10-07); the context
  # `--fit` picks at load time is noted per model. The commented-out models
  # need more VRAM; re-enable them on a bigger GPU.
  localModels = [
    "unsloth/Qwen3.6-27B-GGUF:Q4_K_XL" # 16.4GiB, ~50k ctx
    "unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M" # 15.8GiB, ~190k ctx
    "unsloth/gemma-4-12b-it-GGUF:UD-Q8_K_XL" # 12.7GiB, full 256k ctx
    "unsloth/Muse-Glimmer-30B-GGUF:Q4_K_XL" # 14.8GiB + 3.6GiB mmproj, ~90k ctx
    "bloomer010/Ling-3.0-tiny-GGUF:UD-Q8_K_XL" # 10.4GiB, full 128k ctx
    # Added after a Hugging Face search (2026-10-07). All five ran 16 users
    # with 8k prompts each in the README sweep.
    # Qwen3.8-27B (the model desg0 serves) at 3.5 bpw. The GSQ-RCO card
    # reports BF16-level scores; the tag resolves to the `-mtp` file.
    "ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S" # 11.3GiB + 0.9GiB mmproj, ~200k ctx
    "unsloth/Qwen-AgentWorld-35B-A3B-GGUF:UD-IQ4_XS" # 16.6GiB, text only, ~200k ctx
    "ornith-ai/Ornith-1.5-9B-GGUF:Q8_0" # 9.1GiB + 0.9GiB mmproj, full 256k ctx
    "unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL" # 13.3GiB + 2.1GiB mmproj, full 256k ctx
    "unsloth/North-Mini-Code-1.0-GGUF:UD-IQ4_XS" # 14.2GiB, text only, ~350k ctx
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
    # "AtomicChat/Ling-3.0-flash-GGUF:Q4_K_S" # 69GiB
  ];
}
