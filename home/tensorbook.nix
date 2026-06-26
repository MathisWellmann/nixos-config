{pkgs, ...}: let
  # Animated wallpaper baked into the Nix store so the path is reproducible.
  wallpaper = ../wallpapers/wallpaper_vertical_animated-uhd_2160_3840_60fps_water_blue.mp4;
in {
  imports = [
    ./home_hyprland.nix
  ];
  wayland.windowManager.hyprland = {
    settings = {
      # Play the animated video wallpaper with mpvpaper, looping and forked into the background.
      "exec-once" = ''hyprctl setcursor 'Banana' 48 && ashell & mpvpaper HDMI-A-1 ${wallpaper} -o "loop" --fork & mpvpaper DP-6 ${wallpaper} -o "loop" --fork'';
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        # London
        "DP-6, 3840x2160@60, 0x0, 1, transform, 1"
        "HDMI-A-1, 3840x2160@60, 2160x0, 1, transform, 1"
        "eDP-1, 1920x1200@60, 4320x2760, 1"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
  home.packages = with pkgs; [
    stripe-cli
    devbox
    claude-code
  ];
}
