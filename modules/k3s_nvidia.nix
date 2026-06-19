# GPU enablement for the k3s node on desg0 (NVIDIA RTX A4000, 16 GB).
#
# Two independent layers are needed before Kubernetes can run GPU pods on this
# node. This module provides both; the k8s device plugin that advertises
# `nvidia.com/gpu` is a cluster workload and lives in the GitOps repo, not here.
#
# 1. A container runtime that can inject the GPU into containers. On NixOS the
#    driver lives under /nix/store with no FHS layout, so the legacy
#    nvidia-container-cli discovery fails; the reliable mechanism is the NVIDIA
#    Container Toolkit's CDI spec, which records the exact store paths.
#    `hardware.nvidia-container-toolkit.enable` provisions the toolkit and a
#    `nvidia-container-toolkit-cdi-generator.service` that writes the CDI spec to
#    /var/run/cdi; containerd v2 (k3s 1.35) auto-loads CDI specs from there.
#
# 2. containerd must learn an `nvidia` runtime handler. Instead of hand-writing a
#    containerd-v3 config template (the upstream nixpkgs example targets the old
#    `io.containerd.grpc.v1.cri` schema, which no longer applies to containerd
#    2.x), we let k3s auto-detect it: at startup k3s scans its own $PATH and, on
#    finding `nvidia-container-runtime`, emits the correct runtime stanza into
#    config.toml and creates the cluster-scoped `nvidia` RuntimeClass. The k3s
#    unit runs with a minimal PATH, so the toolkit is placed on it explicitly.
#    A changed toolkit store path rewrites the unit, so `nixos-rebuild switch`
#    restarts k3s and re-runs detection.
{pkgs, ...}: {
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.k3s.path = [pkgs.nvidia-container-toolkit];

  environment.systemPackages = [pkgs.nvidia-container-toolkit];
}
