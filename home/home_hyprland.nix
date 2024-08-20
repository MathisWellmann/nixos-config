{pkgs, ...}: {
  imports = [
    ./home.nix
    ./waybar
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Desktop
    firefox
    # ladybird
    keepassxc
    mate.eom # Image viewer
    geeqie # Better image viewer
    zathura # PDF reader
    qbittorrent
    mongodb-compass
    virtualbox
    nemo
    amfora
    clementine
    bitmagnet

    # Games
    mindustry
    steam
    minetest
    dwarf-fortress
    hyperrogue
    neverball
    sdlpop
    uchess
    typespeed
    openarena
    openspades

    # Video
    mpv
    vlc
    # Visualize git repo history
    # Command `gource -1920x1080 -c 4 -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b 30000K gource.webm`
    gource # Visualization tool for source control repos
    ffmpeg # Used for encoding the output of `gource`

    # Window manager
    wayland-utils
    wl-clipboard
    wlr-randr
    wdisplays
    input-leap

    # Communication
    halloy # IRC GUI written in Rust
    # discord
    # slack

    # Cryptocurrency
    # electron-cash # BCH wallet with CashFusion privacy tech.

    # Photo Editing
    hugin # Panorama stitching
    darktable
    blender
    gimp
    imagemagick

    # Development
    tracy
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # xwayland.enable = true;
    settings = {
      # monitors should be configured in host specific file
      "exec-once" = "waybar & hyprpaper";
      "$terminal" = "alacritty";
      "$menu" = "fuzzel";
      "$mainMod" = "SUPER";
      env = [
        "HYPRLAND_LOG_WLR=1"
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_CURRENT_DESKPOT,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "__GL_GSYNC_ALLOWED,1"
        "__GL_VRR_ALLOWED,0"
      ];
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
        "col.active_border" = "rgba(f1c232ee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
        resize_on_border = true;
      };
      decoration = {
        rounding = "20";
      };
      dwindle = {
        smart_split = true;
      };
    };
  };

  programs = {
    chromium = {
      enable = true;
      commandLineArgs = [
        "--ozone-platform=wayland"
      ];
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # ublock origin
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark reader
        "fijngjgcjhjmmpcmkeiomlglpeiijkld" # Talisman
        "onhogfjeacnfoofkfgppdlbmlmnplgbn" # SubWallet
      ];
    };
    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono:size=20";
          dpi-aware = false;
          prompt = "'> '";
          terminal = "alacritty";

          lines = 20;
          width = 60;
          horizontal-pad = 8;
          vertical-pad = 4;
          inner-pad = 4;

          exit-on-keyboard-focus-loss = false;
        };
        colors = {
          background = "282828e0";
          text = "ebdbb2ff";
          match = "98971aff";
          selection = "ebdbb2ff";
          selection-text = "282828ff";
          border = "8ec07cff";
        };
        border = {
          width = 5;
          radius = 10;
        };
      };
    };
    wpaperd = {
      enable = true;
      settings = {
        any = {
          path = "/home/magewe/wallpaper.jpg";
        };
      };
    };
  };

  services = {
    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 50.0;
      longitude = 10.0;
      temperature = {
        day = 5000;
        night = 3000;
      };
    };
  };
}
