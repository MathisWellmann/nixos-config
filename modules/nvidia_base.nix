{
  config,
  pkgs,
  ...
}: {
  boot.kernelParams = ["nvidia-drm.modeset=1" "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1"];
  hardware.nvidia = {
    # Blackwell (e.g. RTX PRO 6000 GB202) is only supported by the open kernel
    # module. The closed module loads but RmInitAdapter fails with 0x22:0x56:1017
    # ("requires use of the NVIDIA open kernel modules"), so nvidia-smi finds
    # no devices. Other hosts using this module have pre-Blackwell GPUs that
    # also work with the open module on recent driver versions.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  nixpkgs.config.cudaSupport = true;
  environment.systemPackages = with pkgs; [
    cudatoolkit
    nvtopPackages.full
    cudaPackages.libcublas
    cudaPackages.libcufft
    cudaPackages.libcurand
    cudaPackages.libcusparse
    cudaPackages.libcusolver
    cudaPackages.cuda_nvrtc
    cudaPackages.cuda_nvprof
  ];
}
