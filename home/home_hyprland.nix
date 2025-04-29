{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./home.nix
    ./waybar
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Desktop
    firefox
    ladybird
    floorp
    keepassxc
    gthumb # Image viewer with support for ARW files
    geeqie # Better image viewer
    zathura # PDF reader
    qbittorrent
    mongodb-compass
    nemo
    amfora
    clementine
    bitmagnet
    hyprshot
    pavucontrol
    octaveFull
    hwloc
    lux # Video download CLI
    yt-dlp # youtube downloader
    veracrypt

    # Games
    mindustry
    steam
    minetest
    dwarf-fortress
    neverball
    sdlpop
    uchess
    typespeed
    # openarena
    # openspades
    # veloren
    # pokerth

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
    # slack

    # Cryptocurrency
    # electron-cash # BCH wallet with CashFusion privacy tech.
    ledger-live-desktop
    trezor-suite
    monero-gui

    # Photo Editing
    darktable
    digikam
    rawtherapee
    blender
    gimp
    imagemagick

    # Development
    linuxKernel.packages.linux_6_6.perf
    hotspot # GUI for Linux perf
    tracy # A real time, nanosecond resolution profiler
    heaptrack # Heap memory profiler for linux
  ];

  wayland.windowManager.hyprland = let
    system = pkgs.system;
    stable = import inputs.nixpkgs-stable {inherit system;};
  in {
    enable = true;
    # xwayland.enable = true;
    # package = stable.hyprland;
    settings = {
      # monitors should be configured in host specific file
      "exec-once" = "waybar & hyprpaper";
      "$terminal" = "alacritty";
      "$menu" = "fuzzel";
      "$mainMod" = "SUPER";
      env = [
        # TODO: re-enable this for hosts that require it in their own files.
        # NVIDIA specific.
        # "LIBVA_DRIVER_NAME,nvidia"
        # "XDG_SESSION_TYPE,wayland"
        # "GBM_BACKEND,nvidia-drm"
        # "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "HYPRLAND_LOG_WLR=1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
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
        "$mainMod, F, fullscreen"

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
      debug.disable_logs = false;
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
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
}
