{inputs, ...}: {
  imports = [
    ./home_hyprland.nix
    inputs.lan-mouse.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-3, preferred, 0x0, 1, transform, 1"
        "DP-2, preferred, 2160x0, 1, transform, 1"
      ];
    };
  };

  programs.lan-mouse = {
    enable = true;
    systemd = true;
    settings = {
      left = {
        hostname = "madcatz";
      };
      right = {
        hostname = "genoa";
      };
    };
  };
}
