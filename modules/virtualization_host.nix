{pkgs, ...}: let
  global_const = import ../global_constants.nix;
in {
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["${global_const.username}"];
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [
            (pkgs.OVMF.override {
              secureBoot = true;
              tpmSupport = true;
            })
            .fd
          ];
        };
      };
    };
    spiceUSBRedirection.enable = true;
  };
  users.users.${global_const.username}.extraGroups = ["libvirtd"];
}
