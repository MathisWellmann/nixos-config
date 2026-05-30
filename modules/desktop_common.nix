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
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.extraConfig = {
        "99-fiio-m15s" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                {"device.name" = "~alsa_card\\.usb-FiiO_FiiO_M15S.*";}
              ];
              actions.update-props = {
                "api.acp.auto-profile" = true;
                "api.acp.auto-port" = true;
              };
            }
          ];

          # Prefer the normal stereo sink over "off"/"pro-audio" for the FiiO M15S.
          # The M15S exposes:
          #   1: output:analog-stereo
          #   2: output:iec958-stereo
          #   3: pro-audio
          "device.profile.priority.rules" = [
            {
              matches = [
                {"device.name" = "~alsa_card\\.usb-FiiO_FiiO_M15S.*";}
              ];
              actions.update-props = {
                priorities = [
                  "output:analog-stereo"
                  "output:iec958-stereo"
                  "pro-audio"
                ];
              };
            }
          ];
        };
      };
    };
    xserver = {
      enable = true;
      autorun = false;
      displayManager.startx.enable = true;
      xkb.variant = ",qwerty";
    };
  };
}
