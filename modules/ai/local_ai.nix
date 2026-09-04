{
  inputs,
  pkgs,
  ...
}: let
    system = pkgs.stdenv.hostPlatform.system;
    in {
  imports = [
    (import ./prime-agent.nix {})
  ];
  environment.systemPackages = with pkgs; [
    # inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.forge
    inputs.maki.packages.${system}.default
    inputs.llm-agents.packages.${system}.omp
    inputs.llm-agents.packages.${system}.prime-agent
    # inputs.autolith.packages.${system}.default
    # mistral-rs
    claude-code
    codex
    lmstudio
    # stable-diffusion-cpp-cuda
  ];
}
