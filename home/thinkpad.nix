{...}: {
  imports = [
    ./home_hyprland.nix
  ];
  wayland.windowManager.hyprland = {
    settings = {
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        "DP-3, 3840x2160@60, 0x0, 1"
        "eDP-1, 1920x1200@60, 1051x2160, 1"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
  # services.hyprpaper = {
  #   enable = true;
  #   settings = {
  #     ipc = "on";
  #     splash = true;
  #     splash_offset = 2.0;
  #     preload = [
  #       # "/home/magewe/acapulco_wallpaper.jxl"
  #       "/home/${global_const.username}/acapulco_wallpaper_0.jxl"
  #       "/home/${global_const.username}/acapulco_wallpaper_1.jxl"
  #       "/home/${global_const.username}/acapulco_wallpaper_2.jxl"
  #     ];
  #     # Convert single image into slices using `imagemagick`:
  #     # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
  #     wallpaper = [
  #       "HDMI-A-5,/home/${global_const.username}/acapulco_wallpaper_0.jxl"
  #       "DP-5,/home/${global_const.username}/acapulco_wallpaper_1.jxl"
  #       "DP-4,/home/${global_const.username}/acapulco_wallpaper_2.jxl"
  #       # "HDMI-A-5,/home/${global_const.username}/acapulco_wallpaper.jxl"
  #     ];
  #   };
  # };
}
