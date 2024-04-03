{pkgs, ...}: {
  imports = [
    ./home.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Desktop
    chromium
    firefox
    vlc
    keepassxc
    mate.eom
    zathura
    halloy # IRC GUI written in Rust

    # Visualize git repo history
    # Command `gource -1920x1080 -c 4 -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b 30000K gource.webm`
    gource # Visualization tool for source control repos
    ffmpeg # Used for encoding the output of `gource`

    # Window manager
    hyprpaper
    waybar
    wofi
    wayland-utils
    wl-clipboard
    wl-gammarelay-rs
    wlr-randr
    wdisplays # GUI to manage displays in wayland

    # Communication
    halloy # IRC GUI written in Rust
    discord

    # Cryptocurrency
    electron-cash # BCH wallet with CashFusion privacy tech.

    # Photo Editing
    hugin # Panorama stitching
    darktable
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    # systemd.enable = true;
    settings = {
      monitor = [
        "DP-1, preferred, 2160x0, 1, transform, 1"
        "DP-2, preferred, 4320x0, 1, transform, 1"
        "DP-3, preferred, 0x0, 1, transform, 1"
      ];
      "exec-once" = "waybar & hyprpaper";
      "$terminal" = "alacritty";
      "$fileManager" = "dolphin";
      "$menu" = "wofi --show drun";
      "$mainMod" = "SUPER";
      bind = [
        "$mainMod, RETURN, exec, $terminal"
        "$mainMod, Q, killactive,"
        "$mainMod, J, exit,"
        "$mainMod, F, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, COMMA, exec, $menu"
        "$mainMod, P, pseudo"
        "$mainMod, S, togglesplit"

        "$mainMod, m, movefocus, l"
        "$mainMod, i, movefocus, r"
        "$mainMod, a, movefocus, u"
        "$mainMod, n, movefocus, d"

        "$mainMod, w, exec, busctl --user -- set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 4500"
      ];
      general = {
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };
    };
  };
}
