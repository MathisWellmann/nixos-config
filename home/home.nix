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

  nixpkgs.config.allowUnfree = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Misc
    typst

    # Terminal
    tokei
    ttyper
    neofetch
    onefetch
    diskonaut
    gitui
    oxker # Docker tui
    nil # Nix LSP
    alejandra # Nix formatter
    delta # A syntax-highlighting pager for git
    yaml-language-server
    helix
    openvpn
    mullvad
    kmon # Linux kernel manager and activity monitor
    mprocs # TUI tool to run multiple commands in parallel

    # Cryptography
    sequoia-sq
    safecloset

    nerdfonts

    # Cryptocurrency
    cointop

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

  fonts.fontconfig.enable = true;

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
        credential.helper = "store";
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
        snapshot.max-new-file-size = "10MB";
      };
    };
    alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.8;
        font = {
          size = 20.0;
          normal.family = "HackNerdFont";
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
      extraConfig = ''
        $env.config = {
          show_banner: false,
        };
        def skhx [] = { sk | xargs hx };

        $env.PATH = ($env.PATH | split row (char esep) | 
          append ($env.HOME| path join .cargo/bin));
      '';
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
    yazi = {
      enable = true;
      settings = {
        log.enable = true;
        opener = {
          edit = [
            {
              run = "hx $@";
              block = true;
            }
          ];
          image = [
            {
              run = "geeqie $@";
              block = true;
            }
          ];
          play = [
            {
              run = "vls $@";
              block = true;
            }
          ];
        };
        open = {
          rules = [
            {
              name = "*.ARW";
              use = "image";
            }
            {
              name = "*.jpg";
              use = "image";
            }
            {
              name = "*.webm";
              use = "play";
            }
            {
              name = "*.mp4";
              use = "play";
            }
          ];
        };
      };
    };
  };
}
