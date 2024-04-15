{pkgs, ...}: {
  imports = [
    ./home.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Desktop
    firefox
    keepassxc
    mate.eom # Image viewer
    geeqie # Better image viewer
    zathura # PDF reader
    lan-mouse
    qbittorrent
    mongodb-compass

    # Video
    vlc
    # Visualize git repo history
    # Command `gource -1920x1080 -c 4 -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b 30000K gource.webm`
    gource # Visualization tool for source control repos
    ffmpeg # Used for encoding the output of `gource`

    # Window manager
    hyprpaper
    waybar
    fuzzel
    wayland-utils
    wl-clipboard
    wl-gammarelay-rs
    wlr-randr
    wdisplays # GUI to manage displays in wayland

    # Communication
    halloy # IRC GUI written in Rust
    discord
    slack

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
        "DP-2, preferred, 0x0, 1, transform, 1"
        "DP-3, preferred, 6000x0, 1"
        "HDMI-A-1, preferred, 4320x0, 1, transform, 1"
      ];
      "exec-once" = "waybar & hyprpaper";
      "$terminal" = "alacritty";
      "$menu" = "fuzzel";
      "$mainMod" = "SUPER";
      bind = [
        "$mainMod, RETURN, exec, $terminal"
        "$mainMod, Q, killactive,"
        "$mainMod, J, exit,"
        "$mainMod, V, togglefloating,"
        "$mainMod, COMMA, exec, $menu"
        "$mainMod, P, pseudo"
        "$mainMod, S, togglesplit"

        "$mainMod, m, movefocus, l"
        "$mainMod, i, movefocus, r"
        "$mainMod, a, movefocus, u"
        "$mainMod, n, movefocus, d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 0, workspace, 10"
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"

        "$mainMod, w, exec, busctl --user -- set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 4500"
      ];
      general = {
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };
      dwindle = {
        smart_split = true;
      };
    };
  };

  programs = {
    chromium = {
       enable = true;
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # ublock origin
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark reader
        "fijngjgcjhjmmpcmkeiomlglpeiijkld" # Talisman
        "onhogfjeacnfoofkfgppdlbmlmnplgbn" # SubWallet
      ];
    };
  };
}
