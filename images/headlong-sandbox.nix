# Docker sandbox for headlong's shellm agent (see home/headlong.nix and
# scripts/headlong-sandbox-image.sh). Two things live here:
#
# - `sandbox`: a minimal NixOS system used as the container rootfs. shellm
#   runs the container as host uid 1001 and execs `sleep infinity` (no
#   systemd), so nix runs in client mode; the docker-image.nix module makes
#   the system tarball docker-importable and leaves `/init` so the full
#   system can be booted manually (`docker run ... /init`) if ever needed.
# - `image`: the docker-importable rootfs tarball built from that system,
#   with the flake itself baked in so the agent can `nix build
#   nixos-config#...` from inside the container. The load script adds the
#   setuid-sudo layer on top (nix strips setuid from build outputs, so that
#   bit can only be set outside the build).
{
  system,
  nixpkgs-unstable,
  flakeSrc,
}: let
  pkgs = import nixpkgs-unstable {inherit system;};
  sandbox = nixpkgs-unstable.lib.nixosSystem {
    inherit system;
    specialArgs = {
      # docker-importable system tarball; recipe documented in its header
      docker-image-module = nixpkgs-unstable.outPath + "/nixos/modules/virtualisation/docker-image.nix";
    };
    modules = [
      ({
        pkgs,
        docker-image-module,
        ...
      }: {
        imports = [docker-image-module];
        system.stateVersion = "25.05";
        # headless: no root device, no boot loader
        fileSystems."/" = {
          device = "nodev";
          fsType = "none";
        };
        boot.loader.grub.enable = false;
        # shellm starts the container with `--user $(id -u):$(id -g)` (uid 1001)
        users.users.m = {
          uid = 1001;
          isNormalUser = true;
        };
        # trusted inside the sandbox: the container is the trust boundary
        nix.settings.trusted-users = ["m"];
        # `nix build nixos-config#...` needs the flake CLI in client mode
        nix.settings.experimental-features = ["nix-command" "flakes"];
        # no kernel namespaces in this container runtime for nix's inner
        # build sandbox; the container itself is the trust boundary
        nix.settings.sandbox = false;
        # headlong's ubuntu sandbox gives the agent passwordless sudo;
        # mirror that (the container is the trust boundary either way)
        security.sudo.extraRules = [
          {
            users = ["m"];
            commands = [
              {
                command = "ALL";
                options = ["NOPASSWD"];
              }
            ];
          }
        ];
        # system-wide flake registry entry -> `nix build nixos-config#...`
        nix.registry.nixos-config.to = {
          type = "path";
          path = "/opt/flake";
        };
        # shellm's apt-get setup step is a no-op on non-Debian images, so
        # these tools must be in the image itself
        environment.systemPackages = with pkgs; [
          bash
          jq
          curl
          python3
          tmux
          sudo
          nix
          git
        ];
      })
    ];
  };
in {
  inherit sandbox;
  image =
    pkgs.runCommand "headlong-sandbox-image.tar.gz" {
      src = flakeSrc;
      # nix for `nix-store --load-db` below; gnutar/gzip for the repack
      nativeBuildInputs = [pkgs.nix pkgs.gnutar pkgs.gzip];
      systemTarball = sandbox.config.system.build.tarball;
      toplevel = sandbox.config.system.build.toplevel;
    } ''
      set -e
      mkdir rootfs
      tar -xJf "$systemTarball"/tarball/*.tar.xz -C rootfs
      # the image module strips the system /etc; restore it (nix.conf,
      # /etc/nix/registry.json, profile, ...)
      rm -rf rootfs/etc
      mkdir rootfs/etc
      # $toplevel/etc is a symlink into the store; copy its contents
      cp -a "$toplevel/etc/." rootfs/etc
      chmod u+w rootfs/etc
      # register the baked-in store paths in the store db so client-mode
      # nix (no daemon) sees them as valid instead of trying to rebuild
      nix-store --store "$PWD/rootfs" --load-db < rootfs/nix-path-registration
      # keep only the db; the other runtime dirs (profiles, gcroots, ...)
      # nix created while loading would be root-owned in the image and EPERM
      # for the agent, and nix recreates them as needed
      find rootfs/nix/var/nix -mindepth 1 -maxdepth 1 ! -name db -exec rm -rf {} +
      # db & lock files are created by the build user; the agent's nix
      # (client mode, no daemon) must read the db and take the lock
      chmod -R a+rwX rootfs/nix/var/nix
      # client-mode nix (shellm execs `sleep infinity`, so no daemon runs)
      # builds as the agent's uid and writes the store & build logs itself
      chmod 1777 rootfs/nix/var rootfs/nix/store rootfs/nix/var/nix
      mkdir -p rootfs/tmp && chmod 1777 rootfs/tmp
      # runtime links NixOS would normally create at boot
      mkdir -p rootfs/run rootfs/usr/local/bin
      ln -s "$toplevel" rootfs/run/current-system
      ln -s /run/current-system/sw/bin rootfs/usr/bin
      ln -s /run/current-system/sw/sbin rootfs/usr/sbin
      ln -s /run/current-system/sw/sbin rootfs/sbin
      # NixOS PAM execs the shadow helper from /run/wrappers (created at
      # boot by suid-sgid-wrappers, which never runs in the container);
      # the helper needs no setuid bit itself (its parent has euid 0)
      mkdir -p rootfs/run/wrappers/bin
      ln -s /run/current-system/sw/bin/unix_chkpwd rootfs/run/wrappers/bin/unix_chkpwd
      # /etc/passwd & /etc/group are only materialised at activation; the
      # agent runs as uid:gid 1001:100 (m on the host, `users` gid is 100)
      printf 'root:x:0:0:root:/root:/run/current-system/sw/bin/bash\nm:x:1001:100:m:/home/m:/run/current-system/sw/bin/bash\n' > rootfs/etc/passwd
      printf 'root:x:0:\nusers:x:100:m\n' > rootfs/etc/group
      # PAM's account phase (pam_unix in /etc/pam.d/sudo) needs shadow
      # entries even for NOPASSWD; NixOS only materialises /etc/shadow
      # for users with a password hash
      printf 'root:*:19000:0:99999:7:::\nm:!:19000:0:99999:7:::\n' > rootfs/etc/shadow
      chmod 640 rootfs/etc/shadow
      # the flake inside the image; the system-wide registry
      # (nix.registry option in the sandbox config) points here
      mkdir -p rootfs/opt/flake
      cp -a "$src/." rootfs/opt/flake
      # normalise ownership to root (the build user would otherwise leak
      # into the image)
      tar --owner=0 --group=0 --numeric-owner -czf $out -C rootfs .
    '';
}
