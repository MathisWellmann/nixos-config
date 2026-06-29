{pkgs, ...}: {
  imports = [
    ./home_hyprland.nix
  ];
  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = ''hyprctl setcursor 'Banana' 48 && ashell'';
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
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = true;
        splash_offset = 2;
        # Convert single image into slices using `imagemagick`:
        # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
        # NOTE: hyprpaper >=0.8 uses `wallpaper { }` blocks; the old
        # `preload = ...` + `wallpaper = "monitor,path"` flat syntax is ignored.
        wallpaper = [
          {
            monitor = "DP-6";
            path = "/home/m/acapulco_wallpaper_0.jxl";
          }
          {
            monitor = "HDMI-A-1";
            path = "/home/m/acapulco_wallpaper_1.jxl";
          }
        ];
      };
    };
  };
  home.packages = with pkgs; [
    stripe-cli
    devbox
    claude-code
  ];
}
