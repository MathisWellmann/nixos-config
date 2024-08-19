{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-1, 1920x1080@60, 0x0, 1"
        "DP-2, 1920x1080@60, 0x1080, 1"
        "DP-3, 3840x2160@60, 1920x0, 1, transform, 1"
        "DP-4, 3840x2160@60, 4080x0, 1, transform, 1"
        "DP-5, 3840x2160@60, 6240x0, 1, transform, 1"
      ];
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
        "DP-4,/home/magewe/wallpaper_rolls-royce-phantom_monitor_1.jpg"
        "DP-5,/home/magewe/wallpaper_rolls-royce-phantom_monitor_2.jpg"
      ];
    };
  };
}
