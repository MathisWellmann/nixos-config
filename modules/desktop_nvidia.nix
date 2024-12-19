{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./desktop_common.nix
  ];
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = ["nvidia"];

  environment.systemPackages = with pkgs;  [
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
    nerd-fonts.departure-mono
  ];
}
