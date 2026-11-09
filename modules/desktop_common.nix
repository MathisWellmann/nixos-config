{pkgs, ...}: {
  hardware.graphics = {
    enable = true;
  };
  environment.systemPackages = with pkgs; [
    egl-wayland
  ];
  security.rtkit.enable = true;
  # Hyprland 0.57.0 asks rtkit for SCHED_RR and in exchange lowers its
  # RLIMIT_RTTIME to 150 ms soft / 200 ms hard. A single long non-sleeping
  # kernel call on the main thread (NVIDIA DRM connector probes, hybrid
  # Intel+NVIDIA blits) then makes the kernel SIGKILL the compositor without a
  # crash report, coredump or log line, and start-hyprland drops into
  # --safe-mode. Opting out keeps Hyprland on SCHED_OTHER; pipewire still gets
  # realtime from rtkit. Session variables are applied by PAM at login, so this
  # reaches `start-hyprland` from the tty1 shell.
  # Remove once nixpkgs ships Hyprland >= 0.57.2 ("init: stop acquiring
  # realtime scheduling").
  # See https://github.com/hyprwm/Hyprland/discussions/16648 and
  # https://github.com/NixOS/nixpkgs/issues/581510
  environment.sessionVariables.HYPRLAND_NO_RT = "1";

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
