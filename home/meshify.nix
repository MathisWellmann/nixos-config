{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-4, preferred, 0x0, 1"
        "DP-5, preferred, 0x1080, 1"
      ];
    };
  };
}
