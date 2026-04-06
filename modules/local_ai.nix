{llama-cpp_port ? 3100}: {pkgs, ...}: let
  new_ollama = pkgs.ollama.overrideAttrs (oldAttrs: rec {
    version = "0.20.2";
    doCheck = false;
    doTest = false;
    src = pkgs.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      rev = "v${version}";
      hash = "sha256-Ic3eLOohLR7MQGkLvDJBNOCiBBKxh6l8X9MgK0b4w+Y=";
    };
  });
in {
  environment.systemPackages = with pkgs; [
    mistral-rs
    # vllm # Fails to build
    claude-code
    codex
    lmstudio
    stable-diffusion-cpp-cuda
  ];
  services = {
    ollama = {
      enable = true;
      package = new_ollama;
      environmentVariables = {
        OLLAMA_NUM_PARALLEL = "2";
        OLLAMA_KEEP_ALIVE = "1";
        OLLAMA_SCHED_SPREAD = "1";
        OLLAMA_LOAD_TIMEOUT = "15m";
        OLLAMA_FLASH_ATTENTION = "true";
        OLLAMA_CONTEXT_LENGTH = "128000";
      };
    };
  };
}
