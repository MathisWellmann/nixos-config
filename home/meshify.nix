{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = true;
      splash_offset = 2.0;
      preload = [
        # "/home/magewe/acapulco_wallpaper.jxl"
        "/home/magewe/acapulco_wallpaper_0.jxl"
        "/home/magewe/acapulco_wallpaper_1.jxl"
        "/home/magewe/acapulco_wallpaper_2.jxl"
      ];
      # Convert single image into slices using `imagemagick`:
      # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
      wallpaper = [
        "DP-5,/home/magewe/acapulco_wallpaper_0.jxl"
        "DP-4,/home/magewe/acapulco_wallpaper_1.jxl"
        "DP-3,/home/magewe/acapulco_wallpaper_2.jxl"
        # "HDMI-A-5,/home/magewe/acapulco_wallpaper.jxl"
      ];
    };
  };
}
