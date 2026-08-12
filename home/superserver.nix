{...}: {
  imports = [
    ./home_hyprland.nix
  ];
  wayland.windowManager.hyprland = {
    settings = {
      env = [
        {_args = ["LIBVA_DRIVER_NAME" "nvidia"];}
        {_args = ["XDG_SESSION_TYPE" "wayland"];}
        {_args = ["GBM_BACKEND" "nvidia-drm"];}
        {_args = ["__GLX_VENDOR_LIBRARY_NAME" "nvidia"];}
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        {
          output = "DP-1";
          mode = "3840x2160@160";
          position = "960x0";
          scale = 1.5;
          transform = 1;
        }
        {
          output = "DP-2";
          mode = "1920x1080@60";
          position = "2400x0";
          scale = 1;
        }
        {
          output = "DP-3";
          mode = "1920x1080@60";
          position = "2400x1080";
          scale = 1;
        }
      ];
      config.cursor.no_hardware_cursors = true;
    };
  };
}
