{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.
      monitor = [
        # Triple Vertical
        "DP-3, 3840x2160@144, 0x1080, 1, transform, 1"
        "DP-2, 3840x2160@144, 2160x1080, 1, transform, 1"
        "DP-1, 3840x2160@144, 4320x1080, 1, transform, 1"
        "HDMI-A-1, 1920x1080@60, 3240x0, 1"

        # Middle monitor horizontal
        # "DP-3, 3840x2160@144, 0x0, 1, transform, 1"
        # "DP-2, 3840x2160@144, 2160x0, 1"
        # "DP-1, 3840x2160@144, 6000x0, 1, transform, 1"
      ];
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];
      cursor.no_hardware_cursors = true;
      # env = [
      #   "AQ_DRM_DEVICES,/dev/dri/card3" # Use AMD GPU.
      # ];
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = true;
      splash_offset = 2.0;
      preload = [
        "/home/magewe/acapulco_wallpaper.jxl"
        "/home/magewe/acapulco_wallpaper_0.jxl"
        "/home/magewe/acapulco_wallpaper_1.jxl"
        "/home/magewe/acapulco_wallpaper_2.jxl"
      ];
      # Convert single image into slices using `imagemagick`:
      # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
      wallpaper = [
        "DP-3,/home/magewe/acapulco_wallpaper_0.jxl"
        "DP-2,/home/magewe/acapulco_wallpaper_1.jxl"
        "DP-1,/home/magewe/acapulco_wallpaper_2.jxl"
        "HDMI-A-1,/home/magewe/acapulco_wallpaper.jxl"
      ];
    };
  };
}
