{pkgs, ...}: let
  # newer_ollama = pkgs.ollama.overrideAttrs (old: {
  #   version = "0.6.4";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "ollama";
  #     repo = "ollama";
  #     tag = "v0.6.4";
  #     hash = "sha256-d8TPVa/kujFDrHbjwv++bUe2txMlkOxAn34t7wXg4qE=";
  #     fetchSubmodules = true;
  #   };
  #   vendorHash = "sha256-4wYgtdCHvz+ENNMiHptu6ulPJAznkWetQcdba3IEB6s=";
  # });
in {
  services.ollama = {
    # package = newer_ollama;
    enable = true;
    # acceleration = "cuda";
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_KEEP_ALIVE = "1";
      OLLAMA_SCHED_SPREAD = "1";
      OLLAMA_GPU_OVERHEAD = "22000000";
      OLLAMA_LOAD_TIMEOUT = "15m";
    };
  };
}
