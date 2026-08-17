{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./home.nix
    ./terminals.nix
    # ./waybar
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    inputs.kopuz.packages.${pkgs.stdenv.hostPlatform.system}.default # Music GUI
    inputs.stochos.packages.${pkgs.stdenv.hostPlatform.system}.default # keyboard driven mouse control
    inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    # Desktop
    firefox
    # ladybird # CVE currently
    brave
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
    obs-studio
    # rerun — provided by rerun-sdk in python.nix (conflict otherwise)

    ##### Cursors #####
    banana-cursor
    rose-pine-cursor
    lyra-cursors
    phinger-cursors

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
    # tlaplusToolbox
    # redisinsight
  ];

  # Notification daemon: serves the org.freedesktop.Notifications D-Bus name.
  # Without one, ghostty (and any libnotify caller) errors with
  # `GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown`.
  services.mako = {
    enable = true;
    defaultTimeout = 5000; # 5s, quiet enough for terminal bells / exit notices
  };

  # NOTE: Since Hyprland 0.55 the hyprlang `hyprland.conf` format is deprecated
  # (removed in 0.57) in favor of Lua (`hyprland.lua`). With
  # `configType = "lua"`, every attribute of `settings` maps to an `hl.<name>(…)`
  # call; lists generate one call per element, `_args` generates multi-argument
  # calls and `lib.generators.mkLuaInline` emits raw Lua.
  # See https://wiki.hypr.land/Configuring/Start/
  wayland.windowManager.hyprland = let
    inherit (lib.generators) mkLuaInline;
    mainMod = "SUPER";
    terminal = "ghostty";
    menu = "fuzzel";
    # `hl.bind(keys, dispatcher, opts?)`
    b = keys: dispatcher: {_args = ["${mainMod} + ${keys}" (mkLuaInline dispatcher)];};
    bm = keys: dispatcher: {_args = ["${mainMod} + ${keys}" (mkLuaInline dispatcher) {mouse = true;}];};
  in {
    enable = true;
    configType = "lua";
    # xwayland.enable = true;
    # package = stable.hyprland;
    settings = {
      env = [
        # NVIDIA specific.
        {_args = ["XDG_CURRENT_DESKTOP" "Hyprland"];}
        {_args = ["XDG_SESSION_DESKTOP" "Hyprland"];}
      ];
      bind = [
        (b "RETURN" ''hl.dsp.exec_cmd("${terminal}")'')
        (b "Q" "hl.dsp.window.close()")
        (b "J" "hl.dsp.exit()")
        (b "V" ''hl.dsp.window.float({ action = "toggle" })'')
        (b "i" ''hl.dsp.exec_cmd("${menu}")'')
        (b "P" "hl.dsp.window.pseudo()")
        (b "F" "hl.dsp.window.fullscreen()")

        # for the charachorder
        (b "m" ''hl.dsp.focus({ direction = "left" })'')
        (b "n" ''hl.dsp.focus({ direction = "right" })'')
        (b "l" ''hl.dsp.focus({ direction = "up" })'')
        (b "w" ''hl.dsp.focus({ direction = "down" })'')

        # Switch workspaces with mainMod + [0-9]
        (b "0" "hl.dsp.focus({ workspace = 10 })")
        (b "1" "hl.dsp.focus({ workspace = 1 })")
        (b "2" "hl.dsp.focus({ workspace = 2 })")
        (b "3" "hl.dsp.focus({ workspace = 3 })")
        (b "4" "hl.dsp.focus({ workspace = 4 })")
        (b "5" "hl.dsp.focus({ workspace = 5 })")
        (b "6" "hl.dsp.focus({ workspace = 6 })")
        (b "7" "hl.dsp.focus({ workspace = 7 })")
        (b "8" "hl.dsp.focus({ workspace = 8 })")
        (b "9" "hl.dsp.focus({ workspace = 9 })")

        (b "a" ''hl.dsp.exec_cmd("stochos")'')

        # Move/resize windows with mainMod + LMB/RMB and dragging
        (bm "mouse:272" "hl.dsp.window.drag()") # NOTE: mouse:272 = left click
        (bm "mouse:273" "hl.dsp.window.resize()") # NOTE: mouse:273 = right click
      ];
      config = {
        general = {
          col = {
            active_border = {
              colors = ["rgb(1ECBE1)" "rgb(E1341E)"];
              angle = 45;
            };
            inactive_border = "rgba(595959aa)";
          };
          layout = "dwindle";
          resize_on_border = true;
          border_size = 2;
          gaps_in = 5;
          gaps_out = 5;
        };
        decoration = {
          rounding = 10;
        };
        dwindle = {
          smart_split = true;
        };
        # debug.disable_logs = false;
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
        "jnmbobjmhlngoefaiojfljckilhhlhcj" # OneKey Wallet
      ];
    };
    # librewolf.enable = true; # Takes way to long to compile (2h)
    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono:size=20";
          dpi-aware = false;
          prompt = "'> '";
          terminal = "ghostty";

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
    # Blue light filter at night.
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
            temperature = 2750;
            gamma = 0.85;
          }
        ];
      };
    };
    hypridle = {
      enable = true;
      settings = {
        listener = [
          {
            timeout = 300;
            on-timeout = "hyprlock";
          }
          {
            timeout = 1200;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
  programs.ashell = {
    enable = true;
    # 0.9.0 renders transparent on Hyprland; remove once fixed upstream.
    package = pkgs.ashell.overrideAttrs (_: rec {
      version = "0.8.0";
      src = pkgs.fetchFromGitHub {
        owner = "MalpenZibo";
        repo = "ashell";
        tag = version;
        hash = "sha256-X9TU866PAzaf52qKsCpeJvwE0suu1lJndHNQdPg51HM=";
      };
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit src;
        name = "ashell-0.8.0-vendor";
        hash = "sha256-nhYbehlgB8pzMoj39G0BHRca9mIT+0QjUaebCx+DDE0=";
      };
    });
    settings = {
      modules = {
        center = [
          "Window Title"
        ];
        left = [
          "Workspaces"
        ];
        right = [
          "SystemInfo"
          [
            "Clock"
            "Privacy"
            "Settings"
          ]
        ];
      };
      workspaces = {
        visibilityMode = "MonitorSpecific";
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
