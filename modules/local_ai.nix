{llama-cpp_port ? 3100}: {pkgs, ...}: let
  new_ollama = pkgs.ollama.overrideAttrs (oldAttrs: rec {
    version = "0.17.7";
    src = pkgs.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      rev = "v${version}";
      hash = "sha256-cAqc38NHvUo5gphq1csTyosTcpUjFcs0dzB0wreEGjs=";
    };
  });
in {
  environment.systemPackages = with pkgs; [
    mistral-rs
    # vllm # Fails to build
    llama-cpp
    claude-code
    lmstudio
  ];
  services = {
    ollama = {
      enable = true;
      package = new_ollama;
      environmentVariables = {
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_KEEP_ALIVE = "1";
        OLLAMA_SCHED_SPREAD = "1";
        OLLAMA_GPU_OVERHEAD = "22000000";
        OLLAMA_LOAD_TIMEOUT = "15m";
      };
    };
    llama-cpp.port = {
      enable = true;
      host = "0.0.0.0";
      port = llama-cpp_port;
      openFirewall = true;
    };
  };
}
