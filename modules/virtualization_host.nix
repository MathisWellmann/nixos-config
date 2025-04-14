{pkgs, ...}: {
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["magewe"];
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [(pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd];
        };
      };
    };
    spiceUSBRedirection.enable = true;
  }; 
  users.users.magewe.extraGroups = [ "libvirtd" ];
}
