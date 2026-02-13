{open-webui_port}: {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mistral-rs
    vllm
  ];
  services.ollama = {
    enable = true;
    # package = new_ollama;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_KEEP_ALIVE = "1";
      OLLAMA_SCHED_SPREAD = "1";
      OLLAMA_GPU_OVERHEAD = "22000000";
      OLLAMA_LOAD_TIMEOUT = "15m";
    };
  };
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = open-webui_port;
    openFirewall = true;
  };
}
