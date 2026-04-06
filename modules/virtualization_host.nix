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
      };
    };
    spiceUSBRedirection.enable = true;
  };
  users.users.${global_const.username}.extraGroups = ["libvirtd"];
}
