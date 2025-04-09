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
      splash = false;
      splash_offset = 2.0;
      preload = [
        "/home/magewe/wallpaper_rolls-royce-phantom_monitor_0.jpg"
        "/home/magewe/wallpaper_rolls-royce-phantom_monitor_1.jpg"
        "/home/magewe/wallpaper_rolls-royce-phantom_monitor_2.jpg"
      ];
      # Convert single image into slices using `imagemagick`:
      # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
      wallpaper = [
        "DP-3,/home/magewe/wallpaper_rolls-royce-phantom_monitor_0.jpg"
        "DP-2,/home/magewe/wallpaper_rolls-royce-phantom_monitor_1.jpg"
        "DP-1,/home/magewe/wallpaper_rolls-royce-phantom_monitor_2.jpg"
      ];
    };
  };
}
