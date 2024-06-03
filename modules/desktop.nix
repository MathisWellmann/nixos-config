{lib, ...}: {
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    # package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Sound
  # Some tricks:
  # systemctl --user restart pipewire.service
  # systemctl --user restart pipewire-pulse.service
  sound.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.xserver = {
    enable = true;
    autorun = false;
    videoDrivers = ["nvidia"];
    displayManager.startx.enable = true;
  };
}
