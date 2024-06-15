{inputs, ...}: {
  imports = [
    ./home_hyprland.nix
    inputs.lan-mouse.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-1, preferred, 0x0"
      ];
    };
  };

  programs.lan-mouse = {
    enable = true;
    systemd = true;
    settings = {
      left = {
        hostname = "meshify";
      };
    };
  };
}
