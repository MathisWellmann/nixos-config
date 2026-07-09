{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.forge # Fails to build currently
    inputs.dirge.packages.${pkgs.stdenv.hostPlatform.system}.default # TODO: remove
    inputs.maki.packages.${pkgs.stdenv.hostPlatform.system}.default
    # mistral-rs
    # vllm # Fails to build
    claude-code
    codex
    lmstudio
    # stable-diffusion-cpp-cuda
  ];
}
