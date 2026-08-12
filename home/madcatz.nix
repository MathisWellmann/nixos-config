{inputs, ...}: {
  imports = [
    ./home_hyprland.nix
    inputs.lan-mouse.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        {
          output = "DP-1";
          mode = "preferred";
          position = "1920x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "preferred";
          position = "1920x1080";
          scale = 1;
        }
        {
          output = "DP-3";
          mode = "preferred";
          position = "0x0";
          scale = 1;
        }
        {
          output = "HDMI-A-1";
          mode = "preferred";
          position = "0x1080";
          scale = 1;
        }
      ];
    };
  };

  programs.lan-mouse = {
    enable = true;
    systemd = true;
    settings = {
      right = {
        hostname = "meshify";
      };
    };
  };
}
