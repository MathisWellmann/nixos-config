# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/39a24096-bef9-4bc1-8c36-f44383cc337d";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/240d462d-19e8-472b-86bf-654cd379c683";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4A0C-90FB";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp199s0f4u1u2.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = false;
  networking.interfaces.enp1s0f0np0 = {
    name = "mellanox-100G-0";
    useDHCP = false;
    mtu = 9000;
    ipv4 = {
      addresses = [
        {
          address = "169.254.3.1";
          prefixLength = 16;
        }
      ];
    };
  };
  networking.interfaces.enp1s0f1np1 = {
    name = "mellanox-100G-1";
    useDHCP = false;
    mtu = 9000;
    ipv4 = {
      addresses = [
        {
          address = "169.254.3.2";
          prefixLength = 16;
        }
      ];
    };
  };
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.tailscale0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
