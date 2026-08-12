{...}: {
  imports = [
    ./home_hyprland.nix
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        {
          output = "HDMI-A-1";
          mode = "preferred";
          position = "1920x1080";
          scale = 1;
        }
        {
          output = "DP-1";
          mode = "preferred";
          position = "1920x0";
          scale = 1;
        }
        {
          output = "DP-2";
          mode = "preferred";
          position = "0x0";
          scale = 1;
        }
        {
          output = "DP-3";
          mode = "preferred";
          position = "0x1080";
          scale = 1;
        }
      ];
    };
  };
}
