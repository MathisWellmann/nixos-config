{pkgs, ...}: {
  imports = [
    ./home.nix
    ./waybar
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "beekeeper-studio-5.3.4"
  ];
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    beekeeper-studio # Database explorer
    # Desktop
    firefox
    # ladybird
    # floorp-bin
    keepassxc
    # Both are disablede because they require `libsoup` which was marked as insecure.
    gthumb # Image viewer with support for ARW files
    # geeqie # Better image viewer
    zathura # PDF reader
    qbittorrent
    nemo
    amfora
    bitmagnet
    hyprshot
    pavucontrol
    octaveFull
    hwloc
    lux # Video download CLI
    yt-dlp # youtube downloader
    veracrypt
    libreoffice
    # affine
    labplot
    mpvpaper # Animated wallpapers `mpvpaper DP-1 wallpaper_vertical_1080_1920.mp4  -o "loop"`

    ##### Cursors #####
    banana-cursor
    # fuchsia-cursor
    # rose-pine-cursor
    # lyra-cursors
    # phinger-cursors

    # Music
    clementine
    musikcube

    # Video
    mpv
    # Visualize git repo history
    # Command `gource -1920x1080 -c 4 -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b 30000K gource.webm`
    gource # Visualization tool for source control repos
    ffmpeg # Used for encoding the output of `gource`

    # Window manager
    wayland-utils
    wl-clipboard
    wlr-randr
    wdisplays

    # Communication
    # halloy # IRC GUI written in Rust
    # discord
    simplex-chat-desktop
    slack

    # Cryptocurrency
    # electron-cash # BCH wallet with CashFusion privacy tech.
    ledger-live-desktop
    trezor-suite
    monero-gui

    # Photo Editing
    # darktable
    digikam
    rawtherapee
    blender
    gimp
    imagemagick

    # Development
    perf
    hotspot # GUI for Linux perf
    tracy # A real time, nanosecond resolution profiler
    heaptrack # Heap memory profiler for linux
    tlaplusToolbox
    redisinsight
    mongodb-compass
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # xwayland.enable = true;
    # package = stable.hyprland;
    settings = {
      # monitors should be configured in host specific file
      "exec-once" = "waybar & hyprpaper & hyprctl setcursor 'Banana' 48";

      "$terminal" = "kitty";
      "$menu" = "fuzzel";
      "$mainMod" = "SUPER";
      env = [
        # TODO: re-enable this for hosts that require it in their own files.
        # NVIDIA specific.
        # "LIBVA_DRIVER_NAME,nvidia"
        # "XDG_SESSION_TYPE,wayland"
        # "GBM_BACKEND,nvidia-drm"
        # "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        # "__GL_GSYNC_ALLOWED,1"
        #
        # "__GL_VRR_ALLOWED,0"
        # "HYPRLAND_LOG_WLR=1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
      ];
      bind = [
        "$mainMod, RETURN, exec, $terminal"
        "$mainMod, Q, killactive,"
        "$mainMod, J, exit,"
        "$mainMod, V, togglefloating,"
        "$mainMod, COMMA, exec, $menu"
        "$mainMod, P, pseudo"
        "$mainMod, S, togglesplit"
        "$mainMod, F, fullscreen"

        # For rsthd layout on corne keyboard
        "$mainMod, m, movefocus, l"
        "$mainMod, i, movefocus, r"

        "$mainMod, ), movefocus, r"
        "$mainMod, l, movefocus, u"
        "$mainMod, w, movefocus, d"

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
      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow" # NOTE: mouse:272 = left click
        "$mainMod, mouse:273, resizewindow" # NOTE: mouse:273 = right click
      ];
      general = {
        "col.active_border" = "rgba(f1c232ee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
        resize_on_border = true;
        border_size = 3;
        gaps_in = 0;
        gaps_out = 0;
      };
      decoration = {
        rounding = 0;
      };
      dwindle = {
        smart_split = true;
      };
      # debug.disable_logs = false;
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
        "jnmbobjmhlngoefaiojfljckilhhlhcj" # OneKey Wallet
      ];
    };
    librewolf.enable = true;
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
    kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = -1;
        shell = "nu";
        font_size = 13;
        background_opacity = 0.7;
      };
    };
    alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.8;
        font = {
          size = 16.0;
          # normal.family = "HackNerdFont";
          normal.family = "Terminus";
          # normal.family = "DepartureMonoNerdFont";
        };
        terminal.shell.program = "nu";
      };
    };
    zed-editor = {
      enable = true;
      extensions = [
        "nix"
        "codebook"
        "docker-compose"
        "marksman"
        "nickel"
        "nu"
      ];
      userSettings = {
        features = {
          copilot = false;
        };
        telemetry = {
          metrics = false;
        };
        vim_mode = false;
        helix_mode = true;
        ui_font_size = 18;
        buffer_font_size = 18;
        lsp = {
          rust-analyzer.binary.path = "rust-analyzer";
          pylsp.binary.path = "pylsp";
        };
        diagnostics.inline = {
          enabled = true;
          max_severity = null;
        };
      };
    };
    # looking-glass-client = {
    #   enable = true;
    #   settings = {
    #     app = {
    #       allowDMA = true;
    #       shmFile = "/dev/kvmfr0";
    #     };
    #     win = {
    #       fullScreen = true;
    #       showFPS = false;
    #       jitRender = true;
    #     };
    #     spice = {
    #       enable = true;
    #       audio = true;
    #     };
    #     input = {
    #       rawMouse = true;
    #       escapeKey = 62;
    #     };
    #   };
    # };
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
    hyprsunset = {
      enable = true;
      settings = {
        max-gamma = 150;

        profile = [
          {
            time = "7:30";
            identity = true;
          }
          {
            time = "20:00";
            temperature = 5000;
            gamma = 0.8;
          }
        ];
      };
    };
  };
  dconf = {
    settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
