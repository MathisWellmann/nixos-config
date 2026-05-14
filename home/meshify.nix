_: let
  global_const = import ../global_constants.nix;
in {
  imports = [
    ./home_hyprland.nix
    ./games.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = ''ashell & hyprctl setcursor 'Banana' 48 && awww-daemon && awww img ~/orange-train-at-sunset.3840x2160.mp4'';
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        # "WLR_NO_HARDWARE_CURSORS = 1"
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        "DP-6, 1920x1080@60, 6480x1679, 1"
        "DP-5, 1920x1080@60, 6480x2759, 1"
        "DP-4, 3840x2160@159, 4320x0, 1, transform, 1, vrr, 1"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = true;
        splash_offset = 2.0;
        preload = [
          # "/home/magewe/acapulco_wallpaper.jxl"
          "/home/${global_const.username}/acapulco_wallpaper_0.jxl"
          "/home/${global_const.username}/acapulco_wallpaper_1.jxl"
          "/home/${global_const.username}/acapulco_wallpaper_2.jxl"
        ];
        # Convert single image into slices using `imagemagick`:
        # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
        wallpaper = [
          # "HDMI-A-5,/home/${global_const.username}/acapulco_wallpaper_0.jxl"
          # "DP-5,/home/${global_const.username}/acapulco_wallpaper_1.jxl"
          "DP-1,/home/${global_const.username}/acapulco_wallpaper_2.jxl"
          # "HDMI-A-5,/home/${global_const.username}/acapulco_wallpaper.jxl"
        ];
      };
    };
  };
}
