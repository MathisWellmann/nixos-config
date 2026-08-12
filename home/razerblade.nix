{lib, ...}: {
  imports = [
    ./home_hyprland.nix
  ];

  programs.alacritty.settings.font.size = lib.mkForce 10;
  wayland.windowManager.hyprland = {
    settings = {
      # Replaces the old `exec-once`.
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd("waybar")
                hl.exec_cmd("hyprctl setcursor 'Banana' 48")
                hl.exec_cmd("awww-daemon && awww img ~/orange-train-at-sunset.3840x2160.mp4")
              end'')
          ];
        }
      ];
      env = [
        {_args = ["LIBVA_DRIVER_NAME" "nvidia"];}
        {_args = ["XDG_SESSION_TYPE" "wayland"];}
        {_args = ["GBM_BACKEND" "nvidia-drm"];}
        {_args = ["__GLX_VENDOR_LIBRARY_NAME" "nvidia"];}
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        {
          output = "eDP-1";
          mode = "2560x1440@240";
          position = "0x0";
          scale = 1;
        }
      ];
      config.cursor.no_hardware_cursors = true;
    };
  };
}
