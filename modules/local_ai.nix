{pkgs, ...}: let
  open-webui_port = 8080;
  new_ollama = pkgs.ollama.overrideAttrs rec {
    version = "0.9.0";
    src = pkgs.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v${version}";
      hash = "sha256-+8UHE9M2JWUARuuIRdKwNkn1hoxtuitVH7do5V5uEg0=";
      fetchSubmodules = true;
    };
  };
in {
  services.ollama = {
    enable = true;
    package = new_ollama;
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
