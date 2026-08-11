# vLLM serving `NVIDIA-Nemotron-3.5-Lightning-30B-A3B` with NVFP4 quantization.
{
  port ? 8000,
  username ? "m",
  model ? "nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4",
  maxModelLen ? 262144,
  maxNumSeqs ? 32,
}: {
  networking.firewall.allowedTCPPorts = [port];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.podman-vllm-nemotron = {
    after = ["nvidia-container-toolkit-cdi-generator.service"];
    requires = ["nvidia-container-toolkit-cdi-generator.service"];
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.vllm-nemotron = {
      image = "docker.io/vllm/vllm-openai:v0.26.0-x86_64-cu129";
      ports = ["${toString port}:8000"];
      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
        "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
      ];
      environment = {
        MAX_JOBS = "4";
        VLLM_USE_V2_MODEL_RUNNER = "1";
      };
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
      cmd = [
        model
        "--trust-remote-code"
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        "qwen3_coder"
        "--reasoning-parser"
        "nemotron_v3"
        "--max-num-seqs"
        "${toString maxNumSeqs}"
        "--max-model-len"
        "${toString maxModelLen}"
        "--gpu-memory-utilization"
        "0.25"
        "--host"
        "0.0.0.0"
        "--port"
        "8000"
      ];
    };
  };
}
