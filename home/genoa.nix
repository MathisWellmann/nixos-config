{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        # "DP-1, 1920x1080@60, 0x1080, 1"
        "DP-4, 3840x2160@144, 1920x0, 1, transform, 1"
        "DP-3, 3840x2160@144, 4080x0, 1, transform, 1"
        "DP-2, 3840x2160@144, 6240x0, 1, transform, 1"
        # "DP-2, 3840x2160@144, 6240x0, 1"
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
        "DP-4,/home/magewe/wallpaper_rolls-royce-phantom_monitor_0.jpg"
        "DP-3,/home/magewe/wallpaper_rolls-royce-phantom_monitor_1.jpg"
        "DP-2,/home/magewe/wallpaper_rolls-royce-phantom_monitor_2.jpg"
      ];
    };
  };
}
