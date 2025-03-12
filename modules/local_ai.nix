{pkgs, ...}: let
  newer_ollama = pkgs.ollama.overrideAttrs (old: {
    version = "0.6.0";
    src = pkgs.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v0.6.0";
      hash = "sha256-xcnzLBrTbH5IRDZoUR0OoXslcTvml9d/jnQEM52Rmyg=";
      fetchSubmodules = true;
    };
    vendorHash = "sha256-Zpzn2YWpiDAl4cwgrrSpN8CFy4GqqhE1mWsRxtYwdDA=";
  });
in {
  services.ollama = {
    package = newer_ollama;
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
}
