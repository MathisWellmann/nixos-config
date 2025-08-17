{...}: {
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
        "DP-1, 1920x1080@60, 0x0, 1"
        "DP-2, 1920x1080@60, 1920x1080, 1"
        "DP-3, 1920x1080@60, 1920x0, 1"
        "DP-4, 1920x1080@60, 0x1080, 1"
      ];
      cursor.no_hardware_cursors = true;
    };
  };
}
