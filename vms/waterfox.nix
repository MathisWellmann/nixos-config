# Build and run with `nix-build vms/waterfox.nix; result/bin/run-nixos-vm`
let
  pkgs = import <nixpkgs> {};

  waterfox_vm = {
    users.extraUsers.root.password = "test";

    services.xserver = {
      enable = true;
      desktopManager.lxqt.enable = true;
      displayManager.lightdm.enable = true;
      displayManager.defaultSession = "lxqt";
    };
    environment.systemPackages = with pkgs; [
      firefox
    ];
  };
  vms = pkgs.nixos [
    waterfox_vm
  ];
in
  vms.config.system.build.vm
