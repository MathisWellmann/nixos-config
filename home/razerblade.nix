{lib, ...}: {
  imports = [
    ./home_hyprland.nix
  ];

  programs.alacritty.settings.font.size = lib.mkForce 13;
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
      preload = ["/home/magewe/wallpaper.jpg"];
      wallpaper = [
        "eDP-1,/home/magewe/wallpaper.jpg"
      ];
    };
  };
}
