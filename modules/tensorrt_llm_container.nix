{
  port ? 8000,
  username ? "m",
  model ? "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4",
}: {
  networking.firewall.allowedTCPPorts = [
    port
  ];
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";

    containers.tensorrt-llm = {
      image = "nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc11";

      login = {
        registry = "nvcr.io";
        username = "$oauthtoken";
        passwordFile = "/etc/secrets/ngc_api_key";
      };

      ports = [
        "${toString port}:8000"
      ];

      volumes = [
        "/home/${username}/.cache/huggingface:/root/.cache/huggingface"
      ];

      # environmentFiles = [
      #   "/etc/secrets/tensorrt_llm.env"
      # ];

      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];

      cmd = [
        "trtllm-server"
        "serve"
        model
        "--port"
        "8000"
        "--host"
        "0.0.0.0"
      ];
    };
  };
}
