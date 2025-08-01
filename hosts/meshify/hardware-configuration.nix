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
  iperf_port = 5201;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "uas" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/80816c50-393a-44ea-94e7-fc02db3a6ff7";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/16B7-0345";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/c792f5a1-1c4a-4fba-a2f4-976b4fc7a384";}
  ];

  networking = {
    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    useDHCP = lib.mkDefault false;

    networkmanager.enable = false;

    defaultGateway = {
      interface = "enp6s0f0";
      address = "192.168.0.55";
    };
    nameservers = [
      # "192.168.0.10"
      "192.168.0.55"
      # "1.1.1.1"
      # "8.8.8.8"
      # "9.9.9.9"
    ];

    interfaces = {
      # enp4s0 = {
      #   name = "enp4s0";
      #   useDHCP = false;
      #   ipv4 = {
      #     addresses = [
      #       {
      #         address = static_ips.meshify_ip;
      #         prefixLength = 24;
      #       }
      #     ];
      #   };
      # };
      # enp6s0 = {
      #   name = "enp6s0";
      #   useDHCP = false;
      #   mtu = 9000;
      #   ipv4 = {
      #     addresses = [
      #       {
      #         address = static_ips.meshify_mellanox_0;
      #         prefixLength = 16;
      #       }
      #     ];
      #   };
      # };
      enp6s0f0 = {
        name = "enp6s0f0";
        useDHCP = false;
        mtu = 9000;
        ipv4 = {
          addresses = [
            {
              address = static_ips.meshify_ip_10Gbit_0;
              prefixLength = 24;
            }
          ];
        };
      };
    };
    firewall.allowedTCPPorts = [
      iperf_port # iperf server
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
