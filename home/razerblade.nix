{lib, ...}: let
  global_const = import ../global_constants.nix;
in {
  imports = [
    ./home_hyprland.nix
  ];

  programs.alacritty.settings.font.size = lib.mkForce 10;
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      splash_offset = 2.0;
      preload = ["/home/${global_const.username}/wallpaper.jpg"];
      wallpaper = [
        "eDP-1,/home/${global_const.username}/wallpaper.jpg"
      ];
    };
  };
}
