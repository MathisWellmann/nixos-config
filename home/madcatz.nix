{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-1, preferred, 1920x1080, 1"
        "DP-2, preferred, 1920x0, 1"
        "DP-3, preferred, 0x0, 1"
        "HDMI-A-1, preferred, 0x1080, 1"
      ];
    };
  };
}
