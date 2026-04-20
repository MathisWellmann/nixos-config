{
  model,
  port ? 9000,
}: {
  pkgs,
  lib,
  ...
}: {
  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    inherit port;
    openFirewall = true;
    extraFlags = [
      "-hf"
      model
    ];
  };
  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
  # Fix: llama.cpp with -hf needs HUGGINGFACE_HUB_CACHE to find models
  # under the dynamic user.
  systemd.services.llama-cpp.serviceConfig.Environment =
    lib.mkAfter ["HUGGINGFACE_HUB_CACHE=/var/cache/llama-cpp/huggingface"];
}
