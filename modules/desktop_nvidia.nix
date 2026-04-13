{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./desktop_common.nix
  ];
  boot.kernelParams = ["nvidia-drm.modeset=1" "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1"];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  nixpkgs.config.cudaSupport = true;

  services.xserver.videoDrivers = ["nvidia"];

  environment.systemPackages = with pkgs; [
    cudatoolkit
    cudaPackages.libcublas
    cudaPackages.libcufft
    cudaPackages.libcurand
    cudaPackages.libcusparse
    cudaPackages.libcusolver
    cudaPackages.cuda_nvrtc
    cudaPackages.cuda_nvprof
    # cudaPackages.nsight_compute
    # cudaPackages.nsight_systems
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.departure-mono
  ];
  environment.sessionVariables = {
    WLR_DRM_DEVICES = "/dev/dri/by-path/pci-0000:01:00.0-card";
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_DRM_NO_ATOMIC = "1";
  };
}
