# Build and run with `nix-build vms/waterfox.nix; result/bin/run-nixos-vm`
let
  pkgs = import <nixpkgs> {};

  tor_vm = {...}: {
    users.extraUsers.root.password = "test";
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
        videoDrivers = ["qxl"];
      };
      # For copy/paste to work
      spice-vdagentd.enable = true;
      tor.enable = true;
    };
    environment.systemPackages = with pkgs; [
      tor-browser
    ];
    virtualisation.vmVariant = {
      virtualisation.resolution = {
        x = 1920;
        y = 1080;
      };
      virtualisation.qemu.options = [
        # Better display option
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
  vms = pkgs.nixos [
    tor_vm
  ];
in
  vms.config.system.build.vm
