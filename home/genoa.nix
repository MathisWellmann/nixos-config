{inputs, ...}: {
  imports = [
    ./home_hyprland.nix
    inputs.lan-mouse.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    settings = {
      monitor = [
        "DP-1, 1920x1080@60, 0x0, 1"
        "DP-2, 1920x1080@60, 0x1080, 1"
        "DP-3, 3840x2160@60, 1920x0, 1, transform, 1"
        "DP-4, 3840x2160@60, 4080x0, 1, transform, 1"
        "DP-5, 3840x2160@60, 6240x0, 1, transform, 1"
      ];
    };
  };

  # programs = {
  #   lan-mouse = {
  #     enable = true;
  #     systemd = true;
  #     settings = {
  #       left = {
  #         hostname = "meshify";
  #       };
  #     };
  #   };
  # };
}
