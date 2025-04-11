# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  modulesPath,
  ...
}: let
  static_ips = import ../../modules/static_ips.nix;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "ehci_pci" "nvme" "usb_storage" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6e31e996-7785-4949-a995-a04fe9321bba";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/34F2-B359";
    fsType = "vfat";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/469dd412-a5e5-4b20-9605-2c4063ac3617";}
  ];

  networking = {
    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    useDHCP = lib.mkDefault false;

    networkmanager.enable = false;

    defaultGateway = {
      interface = "eno1";
      address = "192.168.0.55";
    };
    nameservers = [
      "192.168.0.55"
      "1.1.1.1"
      "8.8.8.8"
      "9.9.9.9"
    ];

    interfaces = {
      eno1 = {
        name = "eno1";
        useDHCP = false;
        ipv4 = {
          addresses = [
            {
              address = static_ips.elitedesk_ip;
              prefixLength = 24;
            }
          ];
        };
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
