{pkgs, config, ...}: {
  imports = [
    ./desktop_common.nix
  ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = ["nvidia"];

  environment.systemPackages = with pkgs; [
    cudatoolkit
    cudaPackages.libcublas
    cudaPackages.libcufft
    cudaPackages.libcurand
    cudaPackages.libcusparse
    cudaPackages.libcusolver
    # cudaPackages.nsight_compute
  ];
}
