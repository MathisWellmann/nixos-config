# Shared base for the throwaway desktop VMs in this directory: an
# auto-logged-in XFCE session for the unprivileged `guest` user, tuned for a
# fast KVM guest with host clipboard sharing.
#
# root keeps the NixOS default (no password) and `guest` is not in `wheel`,
# so code running as the guest (e.g. a browser exploit) cannot become root
# and switch off the leak-guard firewall.
{lib, ...}: {
  system.stateVersion = "26.11";

  users.users.guest = {
    isNormalUser = true;
    initialPassword = "guest";
  };

  services = {
    xserver = {
      enable = true;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
      videoDrivers = ["modesetting"];
    };
    displayManager.autoLogin = {
      enable = true;
      user = "guest";
    };
    # For copy/paste to work
    spice-vdagentd.enable = true;
  };

  virtualisation.vmVariant.virtualisation = {
    cores = lib.mkDefault 4;
    memorySize = lib.mkDefault 3072;
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
}
