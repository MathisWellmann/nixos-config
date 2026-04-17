{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mistral-rs
    # vllm # Fails to build
    claude-code
    codex
    lmstudio
    stable-diffusion-cpp-cuda
  ];
}
