{pkgs, ...}: {
  hardware.graphics = {
    enable = true;
  };
  environment.systemPackages = with pkgs; [
    egl-wayland
  ];
  security.rtkit.enable = true;

  # Sound
  # Some tricks:
  # systemctl --user restart pipewire.service
  # systemctl --user restart pipewire-pulse.service
  nixpkgs.config.pulseaudio = true;
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
      displayManager.startx.enable = true;
      xkb.variant = ",qwerty";
    };
  };
}
