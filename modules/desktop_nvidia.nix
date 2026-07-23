{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./desktop_common.nix
    ./nvidia_base.nix
  ];
  services.xserver.videoDrivers = ["nvidia"];

  # Build issues currently
  # environment.systemPackages = with pkgs; [
  #   cudaPackages.nsight_compute
  #   cudaPackages.nsight_systems
  # ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.departure-mono
  ];
  environment.sessionVariables = {
    AQ_DRM_DEVICES = lib.mkDefault "/dev/dri/card1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # AQ_NO_ATOMIC = "1"; # Do not use Linux DRM/KMS atomic modesetting; use the legacy display path instead.
  };
}
