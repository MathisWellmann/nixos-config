{pkgs, ...}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "magewe";
  home.homeDirectory = "/home/magewe";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    helix
    # Desktop
    chromium
    firefox
    vlc
    keepassxc
    mate.eom
    zathura
    # Misc
    redshift
    typst
    # Terminal
    tokei
    ttyper
    lfs
    neofetch
    onefetch
    diskonaut
    gitui
    oxker # Docker tui
    nil # Nix LSP
    alejandra # Nix formatter
    delta # A syntax-highlighting pager for git
    halloy # IRC GUI written in Rust
    sequoia-sq

    # Visualize git repo history
    # Command `gource -1920x1080 -c 4 -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b 30000K gource.webm`
    gource # Visualization tool for source control repos
    ffmpeg # Used for encoding the output of `gource`

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/magewe/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  programs = let
    me = "MathisWellmann";
    email = "wellmannmathis@gmail.com";
  in {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;
    helix = {
      enable = true;
      settings = {
        theme = "ayu_mirage";
        editor = {
          scroll-lines = 1;
          cursorline = true;
          auto-save = false;
          completion-trigger-len = 1;
          true-color = true;
          auto-pairs = true;
          rulers = [120];
          idle-timeout = 0;
          bufferline = "always";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          lsp = {
            display-messages = true;
            display-inlay-hints = false;
          };
          statusline = {
            left = ["mode" "spinner" "file-name" "file-type" "total-line-numbers" "file-encoding"];
            center = [];
            right = ["selections" "primary-selection-length" "position" "position-percentage" "spacer" "diagnostics" "workspace-diagnostics" "version-control"];
          };
        };
      };
    };
    git = {
      enable = true;
      userName = "${me}";
      userEmail = "${email}";
      extraConfig = {
        push = {autoSetupRemote = true;};
        init = {
          defaultBranch = "main";
        };
        core.editor = "hx";
        pull.rebase = true;
      };
    };
    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "${me}";
          email = "${email}";
        };
        ui.editor = "hx";
      };
    };
    alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.8;
        font = {
          size = 12.0;
          normal.family = "Terminus";
        };
        shell.program = "nu";
      };
    };
    nushell = {
      enable = true;
      shellAliases = {
        ns = "nix-shell";
        la = "lsd -la";
        dt = "date now";
        night = "redshift -P -O 5000";
        bright = "sudo xbacklight -set 100";
        # Cargo
        udeps = "cargo +nightly udeps --all-targets";
        fmt = "cargo +nightly fmt --all";
        tfmt = "taplo fmt";
        cu = "cargo update";
        cc = "cargo check";
        cb = "cargo build";
        cbr = "cargo build --release";
        cr = "cargo run";
        crr = "cargo run --release";
        cte = "cargo test";

        jjl = "jj log -r main::mine()";
        jjlo = "jj log -r main@origin::mine()";
      };
      extraConfig = "$env.config = {
          show_banner: false,
        }";
    };
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        character = {
          error_symbol = "[✗](bold red)";
        };
        directory = {
          read_only = " ";
          truncation_length = 10;
          truncate_to_repo = true; # truncates directory to root folder if in github repo
          style = "bold italic blue";
        };
      };
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
