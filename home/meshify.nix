{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "HDMI-A-5, preferred, 1920x1080, 1"
        "DP-3, preferred, 1920x0, 1"
        "DP-4, preferred, 0x0, 1"
        "DP-5, preferred, 0x1080, 1"
      ];
    };
  };
}
