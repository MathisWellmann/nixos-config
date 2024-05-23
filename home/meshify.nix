
{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-1, preferred, 2160x0, 1, transform, 1"
        "DP-2, preferred, 2160x0, 1, transform, 1"
        "DP-3, preferred, 0x0, 1, transform, 1"
      ];
    };
  };
}
