{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.forge
    # mistral-rs
    # vllm # Fails to build
    claude-code
    codex
    lmstudio
    # stable-diffusion-cpp-cuda
  ];
}
