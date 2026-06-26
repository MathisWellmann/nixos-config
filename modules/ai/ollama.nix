_: {
  services.ollama = {
    enable = true;
    # package = new_ollama;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_KEEP_ALIVE = "1";
      OLLAMA_SCHED_SPREAD = "1";
      OLLAMA_LOAD_TIMEOUT = "15m";
      OLLAMA_FLASH_ATTENTION = "true";
      OLLAMA_CONTEXT_LENGTH = "128000";
    };
  };
}
