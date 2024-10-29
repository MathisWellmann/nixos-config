{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-3, preferred, 0x0, 1"
        "DP-4, preferred, 0x1080, 1"
      ];
    };
  };
}
