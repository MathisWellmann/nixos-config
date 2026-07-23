_: let
  global_const = import ../global_constants.nix;
  wallpaper = "~/wallpaper_vertical_animated_1080_1920_25fps_orange_blue.mp4";
in {
  imports = [
    ./home_hyprland.nix
    ./games.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      "exec-once" = ''ashell & hyprctl setcursor 'Banana' 48 && mpvpaper DP-4 ${wallpaper} -o "loop" --fork'';
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        # "WLR_NO_HARDWARE_CURSORS = 1"
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        "DP-6, 1920x1080@60, 6480x1679, 1"
        "DP-5, 1920x1080@60, 6480x2759, 1"
        "DP-4, 3840x2160@144, 4320x0, 1, transform, 1, vrr, 1"
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
        # NOTE: DP-1 is not a real monitor on this host (monitors: DP-6/DP-5/DP-4,
        # and DP-4 is driven by mpvpaper); set `monitor` to DP-5/DP-6 to display it.
        wallpaper = [
          {
            monitor = "DP-1";
            path = "/home/${global_const.username}/acapulco_wallpaper_2.jxl";
          }
        ];
      };
    };
  };
}
