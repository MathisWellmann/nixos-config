{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.forge
    inputs.maki.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp
    # mistral-rs
    # vllm # Fails to build
    claude-code
    codex
    lmstudio
    # stable-diffusion-cpp-cuda
  ];
}
