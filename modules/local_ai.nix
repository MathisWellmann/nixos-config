{...}: {
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    environmentVariables = {
      OLLAMA_NUM_PARALLEL="1";
      OLLAMA_KEEP_ALIVE="1";
      OLLAMA_SCHED_SPREAD="1";
      OLLAMA_GPU_OVERHEAD="22000000";
      OLLAMA_LOAD_TIMEOUT="15m";
    };
  };
}
