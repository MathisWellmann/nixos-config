{lib, ...}: let
  global_const = import ../global_constants.nix;
in {
  imports = [
    ./home_hyprland.nix
  ];

  programs.alacritty.settings.font.size = lib.mkForce 10;
  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = ''waybar & hyprctl setcursor 'Banana' 48 & mpvpaper -vs -o "no-audio loop" eDP-1 ~/orange-train-at-sunset.3840x2160.mp4'';
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        # "HDMI-A-2, 3840x2160@60, 0x0, 1, transform, 1"
        "DP-3, 1920x1080@60, 4720x1679, 1"
        "DP-4, 1920x1080@60, 4720x2760, 1"
        "eDP-1, 2560x1440@120, 0x2400, 1"
        "HDMI-A-1, 3840x2160, 2560x0, 1, transform, 1"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
      preload = ["/home/${global_const.username}/wallpaper.jpg"];
      wallpaper = [
        "eDP-1,/home/${global_const.username}/wallpaper.jpg"
      ];
    };
  };
}
