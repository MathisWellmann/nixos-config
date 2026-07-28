# vLLM serving `Qwen3.6-35B-A3B` with the `z-lab` DFlash drafter for speculative decoding.
{
  port ? 8000,
  username ? "m",
  model ? "nvidia/Qwen3.6-35B-A3B-NVFP4",
  draftModel ? "z-lab/Qwen3.6-35B-A3B-DFlash",
  # 15 matches the drafter's block size of 16, which the model card recommends for longer
  # accept lengths. Drop to 7 with a block size of 8 when serving higher concurrency.
  numSpeculativeTokens ? 15,
  maxModelLen ? 262144,
  maxNumSeqs ? 32,
}: {
  networking.firewall.allowedTCPPorts = [port];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.podman-vllm-qwen3 = {
    after = ["nvidia-container-toolkit-cdi-generator.service"];
    requires = ["nvidia-container-toolkit-cdi-generator.service"];
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.vllm-qwen3 = {
      image = "docker.io/vllm/vllm-openai:v0.26.0-x86_64-cu129";
      ports = ["${toString port}:8000"];
      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
        "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      ];
      environment = {
        MAX_JOBS = "4";
        # Hybrid sliding-window/full-attention DFlash drafters require the V2 runner.
        VLLM_USE_V2_MODEL_RUNNER = "1";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
      cmd = [
        model
        "--trust-remote-code"
        # "--speculative-config"
        # ''{"model":"${draftModel}","num_speculative_tokens":${toString numSpeculativeTokens},"method":"dflash"}''
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        "qwen3_coder"
        "--reasoning-parser"
        "qwen3"
        "--default-chat-template-kwargs"
        ''{"enable_thinking":true}''
        # Qwen's recommended thinking-mode sampling params for coding.
        "--override-generation-config"
        ''{"temperature":0.6,"top_p":0.95,"top_k":20,"presence_penalty":0.0}''
        "--max-num-seqs"
        "${toString maxNumSeqs}"
        "--max-model-len"
        "${toString maxModelLen}"
        "--gpu-memory-utilization"
        "0.9"
        "--host"
        "0.0.0.0"
        "--port"
        "8000"
      ];
    };
  };
}
