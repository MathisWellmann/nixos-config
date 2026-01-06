{pkgs, ...}: let
  global_const = import ../global_constants.nix;
in {
  imports = [
    ./home_hyprland.nix
  ];
  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = ''waybar & hyprctl setcursor 'Banana' 48 && awww-daemon && awww img ~/MathisWellmann/nixos-config/wallpapers/wallpaper_vertical_animated_1080_1920_25fps_blurry_plants.mp4'';
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        # London
        "DP-6, 3840x2160@60, 0x0, 1, transform, 1"
        "HDMI-A-1, 3840x2160@60, 2160x0, 1, transform, 1"
        "eDP-1, 1920x1200@60, 4320x2760, 1"
        # SF
        # "HDMI-A-1, 3840x2160@60, 0x0, 1, transform, 1"
        # "eDP-1, 1920x1200@60, 2160x2760, 1"
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
          "/home/${global_const.username}/wallpaper_vertical_mountain.jpg"
          "/home/${global_const.username}/Wallpaper.jpg"
        ];
        # Convert single image into slices using `imagemagick`:
        # magick convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
        wallpaper = [
          "HDMI-A-1,/home/${global_const.username}/wallpaper_vertical_mountain.jpg"
          "DP-6,/home/${global_const.username}/wallpaper_vertical_mountain.jpg"
          "eDP-1,/home/${global_const.username}/Wallpaper.jpg"
        ];
      };
    };
  };
  home.packages = with pkgs; [
    stripe-cli
  ];
}
