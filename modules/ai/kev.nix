# Kev (github:jaredpalmer/kev): a self-hosted Jev-like decision model.
#
# Serves `model` (default: the Kev-4B LoRA adapter + pointer head on
# Qwen3.5-4B-Base) through its TypeSafe System One API: POST /v1/systemone
# (choice / score / noul questions over a state), GET /v1/models, plus the
# TypeSafe Python SDK pointed at http://<host>:<port> works unchanged.
# Inference runs on the host's NVIDIA GPU in bf16 with CUDA graphs (the
# serving defaults); the ~9 GB of weights land in the service user's
# Hugging Face cache on first activation via the `kev-weights` oneshot.
{
  model ? "jaredpalmer/kev-4b",
  port ? 8009,
  # The k3s ingress (env/host_ingress.nix) reaches this port over the host's
  # tailscale IP, so the server must bind beyond loopback.
  host ? "0.0.0.0",
  # Bearer key required on /v1/*; null = open server (the local default, same
  # as the other fleet inference endpoints).
  apiKey ? null,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  global_const = import ../../global_constants.nix;
  user = global_const.username;
  kev = pkgs.callPackage ../../pkgs/kev.nix {};

  # Keep kev's hub cache out of the desktop user's default huggingface cache
  # (same pattern as llama-cpp's ~/.cache/llama-cpp).
  hfHome = "/home/${user}/.cache/kev";

  # NixOS deliberately keeps the NVIDIA userland driver (libcuda.so.1 & co.)
  # out of the default ld cache; torch only finds CUDA through
  # LD_LIBRARY_PATH. Without it the server silently falls back to CPU.
  cudaLib = config.hardware.nvidia.package or null;

  env =
    ["HF_HOME=${hfHome}"]
    ++ lib.optional (apiKey != null) "KEV_API_KEY=${apiKey}"
    ++ lib.optional (cudaLib != null) "LD_LIBRARY_PATH=${cudaLib}/lib";
in {
  environment.systemPackages = [
    # `hf` for manual weight downloads/inspection
    (pkgs.callPackage ../../pkgs/hf.nix {})
  ];

  networking.firewall.allowedTCPPorts = [port];

  # First activation only (idempotent afterwards): downloads the checkpoint
  # and its pinned base into $HF_HOME so the server's start stays seconds, not
  # the download time of ~9 GB.
  systemd.services."kev-weights" = {
    description = "Kev model weights (Hugging Face cache)";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      # A cold ~9 GB download may take well past systemd's 90 s default.
      TimeoutStartSec = "1h";
      User = user;
      Group = "users";
      # Writes into the user's home cache.
      ProtectHome = lib.mkForce false;
      Environment = env;
      ExecStart = "${kev}/bin/kev-prefetch ${model}";
    };
  };

  systemd.services.kev = {
    description = "Kev decision model server (TypeSafe System One API)";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "kev-weights.service"];
    # kev-weights is idempotent: a `systemctl start kev` in a running system
    # re-runs it and skips already-cached files.
    wants = ["network-online.target" "kev-weights.service"];
    serviceConfig = {
      User = user;
      Group = "users";
      # Weights are read from the user's home cache.
      ProtectHome = lib.mkForce false;
      Environment = env;
      ExecStart = "${kev}/bin/kev-serve --run ${model} --host ${host} --port ${toString port}";
      Restart = "on-failure";
    };
  };
}
