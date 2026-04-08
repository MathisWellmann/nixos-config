{
  port ? 8000,
  username ? "m",
  model ? "unsloth/Qwen3.5-27B-GGUF-IQ4_XS", # Fits in 16GB VRAM.
}: {
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";

    containers.vllm = {
      image = "docker.io/vllm/vllm-openai:latest";

      ports = [
        "${toString port}:8000"
      ];

      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
      ];

      environmentFiles = [
        "/etc/secrets/vllm.env"
      ];

      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];

      cmd = [
        "--model"
        model
      ];
    };
  };
}
