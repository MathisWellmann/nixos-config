{lib, ...}: {
  imports = [
    ./home_hyprland.nix
  ];

  programs.alacritty.settings.font.size = lib.mkForce 16;
}
