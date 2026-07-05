# Build and run with `nix-build vms/tor.nix; result/bin/run-nixos-vm`
let
  pkgs = import <nixpkgs> {};

  tor_vm = _: {
    users = {
      users.root.initialPassword = "test";
      users.guest = {
        isNormalUser = true;
        initialPassword = "guest";
      };
    };
    boot = {
      loader.systemd-boot.enable = true;
      loader.efi.canTouchEfiVariables = true;
      initrd.systemd.enable = true;
    };

    services = {
      xserver = {
        enable = true;
        displayManager.autoLogin.user = "guest";
        desktopManager.xfce.enable = true;
        desktopManager.xfce.enableScreensaver = false;
        videoDrivers = ["modesetting"];
      };
      # For copy/paste to work
      spice-vdagentd.enable = true;
      tor.enable = true;
    };
    environment.systemPackages = with pkgs; [
      tor-browser
    ];
    virtualisation.vmVariant = {
      virtualisation = {
        cores = 4;
        memorySize = 3072;
        resolution = {
          x = 1920;
          y = 1080;
        };
        qemu.options = [
        # Enable KVM hardware acceleration - biggest performance win
        "-enable-kvm"
        # Use host CPU features for near-native speed
        "-cpu host"
        # VirtIO GPU for accelerated 2D/3D graphics
        "-vga virtio"
        "-display gtk,zoom-to-fit=false"
        # Enable copy/paste
        # https://www.kraxel.org/blog/2021/05/qemu-cut-paste/
        "-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on"
        "-device virtio-serial-pci"
          "-device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
        ];
      };
    };
  };
  vms = pkgs.nixos [
    tor_vm
  ];
in
  vms.config.system.build.vm
