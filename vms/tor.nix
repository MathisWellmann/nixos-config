# Build and run with `nix-build vms/tor.nix; result/bin/tor-vm`
#
# The disk image (./tor.qcow2 in the current directory) is LUKS-encrypted.
# The first run asks for a new passphrase, later runs ask for it to unlock.
# To keep the state of an old plaintext image (it used to be ./nixos.qcow2):
# `result/bin/tor-vm convert nixos.qcow2`, then delete nixos.qcow2.
let
  pkgs = import <nixpkgs> {};

  tor_vm = {
    imports = [
      ./desktop.nix
      ./encrypted-disk.nix
      ./leak-guard.nix
    ];

    # Names the disk image and launcher. The default "nixos" was shared with
    # waterfox.nix, so both VMs used the same ./nixos.qcow2.
    networking.hostName = "tor";
    leakGuard.allowedUser = "tor";

    services.tor = {
      enable = true;
      client = {
        enable = true;
        # The port and flags Tor Browser gives its bundled tor, so the browser
        # keeps its proxy settings and per-site circuit isolation.
        socksListenAddress = {
          addr = "127.0.0.1";
          port = 9150;
          IPv6Traffic = true;
          PreferIPv6 = true;
          KeepAliveIsolateSOCKSAuth = true;
          flags = ["ExtendedErrors"];
        };
      };
    };
    # Tor Browser would start its bundled tor as `guest`, which leak-guard
    # blocks. "none" makes it use the system tor's SOCKS port instead, with
    # no launcher and no control port. Without the variable it fails closed.
    environment.sessionVariables.TOR_PROVIDER = "none";
    environment.systemPackages = [pkgs.tor-browser];
  };
  vms = pkgs.nixos [
    tor_vm
  ];
in
  vms.config.system.build.encryptedVm
