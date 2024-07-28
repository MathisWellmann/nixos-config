{...}: {
  imports = [
    ./desktop_common.nix
  ];

  services.xserver.videoDrivers = ["amdgpu"];
}
