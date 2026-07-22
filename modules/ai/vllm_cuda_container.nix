{
  port ? 8000,
  username ? "m",
}: {
  networking.firewall.allowedTCPPorts = [port];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.podman-vllm = {
    after = ["nvidia-container-toolkit-cdi-generator.service"];
    requires = ["nvidia-container-toolkit-cdi-generator.service"];
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.vllm = {
      image = "docker.io/vllm/vllm-openai:v0.25.1-x86_64-cu129";
      ports = ["${toString port}:8000"];
      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
        "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      ];
      environment.MAX_JOBS = "4";
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
      cmd = [
        "poolside/Laguna-S-2.1-NVFP4"
        "--trust-remote-code"
        "--speculative-config"
        ''{"model":"poolside/Laguna-S-2.1-DFlash-NVFP4","num_speculative_tokens":15,"method":"dflash"}''
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        "poolside_v1"
        "--reasoning-parser"
        "poolside_v1"
        "--default-chat-template-kwargs"
        ''{"enable_thinking":true}''
        "--override-generation-config"
        ''{"temperature":0.7,"top_p":0.95}''
        "--max-num-seqs"
        "32"
        "--max-model-len"
        "262144"
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
