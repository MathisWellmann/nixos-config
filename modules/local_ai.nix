{...}: let
  open-webui_port = 8080;
in {
  services.ollama = {
    enable = true;
    acceleration = "cuda";
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
