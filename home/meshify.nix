{...}: let
  global_const = import ../global_constants.nix;
in {
  imports = [
    ./home_hyprland.nix
    ./games.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        # "HDMI-A-2, 3840x2160@60, 0x0, 1, transform, 1"
        # "DP-5, 3840x2160@159, 2160x0, 1, transform, 1"
        "DP-1, 3840x2160@159, 0x0, 1, transform, 1"
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
