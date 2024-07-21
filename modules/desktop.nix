{
  config,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.systemPackages = with pkgs; [
    egl-wayland
  ];

  # Sound
  # Some tricks:
  # systemctl --user restart pipewire.service
  # systemctl --user restart pipewire-pulse.service
  security.rtkit.enable = true;
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    xserver = {
      enable = true;
      autorun = false;
      videoDrivers = ["nvidia"];
      displayManager.startx.enable = true;
      xkb.variant = ",qwerty";
    };
  };
}
