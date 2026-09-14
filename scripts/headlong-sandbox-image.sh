#!/usr/bin/env bash
# Build & load the headlong sandbox docker image. See flake.nix:
#   packages.x86_64-linux.headlong-sandbox-image  (the NixOS rootfs tarball)
#   nixosConfigurations.headlong-sandbox          (the NixOS system inside it)
# Run on the host that runs the agents (desg0); the image tag is what
# SHELLM_DOCKER_IMAGE in ~/.headlong/.env points at (home/headlong.nix).
set -euo pipefail
cd "$(dirname "$0")/.."

IMG=$(nix build --accept-flake-config --print-out-paths .#packages.x86_64-linux.headlong-sandbox-image)
docker import "$IMG" headlong-sandbox-base:latest
# Nix strips setuid from build outputs, so sudo's bit is set in a docker
# layer: cp makes a new inode (the image layer is read-only on this
# container runtime, so chmodding the store path in place is not possible).
# /usr/local/bin comes before /usr/sbin in the default PATH.
docker build -t headlong-sandbox:latest - <<'EOF'
FROM headlong-sandbox-base:latest
# the rootfs has no /bin/sh; give BuildKit the NixOS bash
SHELL ["/run/current-system/sw/bin/bash", "-c"]
RUN cp /nix/store/*-sudo-*/bin/sudo /usr/local/bin/sudo && chmod 4755 /usr/local/bin/sudo
EOF
docker rmi headlong-sandbox-base:latest >/dev/null
echo "headlong-sandbox:latest ready: $(docker image inspect headlong-sandbox:latest --format '{{.Id}}')"
