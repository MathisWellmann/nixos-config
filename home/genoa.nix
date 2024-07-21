{inputs, ...}: {
  imports = [
    ./home_hyprland.nix
    inputs.lan-mouse.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-3, 3840x2160@60, 0x0, 1, transform, 1"
        "DP-2, 3840x2160@60, 2160x0, 1, transform, 1"
        "DP-1, 3840x2160@60, 4320x0, 1, transform, 1"
      ];
    };
  };

  programs = {
    lan-mouse = {
      enable = true;
      systemd = true;
      settings = {
        left = {
          hostname = "meshify";
        };
      };
    };
  };
}
