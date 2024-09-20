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
  home.packages = let
    my-python-packages = ps:
      with ps; [
        numpy
      ];
  in
    with pkgs; [
      # Misc
      typst
      zola # Static site generator that I want to use for my blog.
      lux # Video download CLI
      yt-dlp # youtube downloader
      terminus_font
      rdfind # Find duplicate files: e.g.: `rdfind .`
      fend # Unit aware calculator

      # Nix
      # Package version diff tool. E.g Compare system revision 405 with 420:
      # `nvd diff /nix/var/nix/profiles/system-405-link/ /nix/var/nix/profiles/system-420-link/`
      nvd
      nix-output-monitor # `nom` is a drop in replacement for `nix` that has pretty output
      nix-prefetch-scripts # Is used to obtain source hashes of urls. aka `nix-prefetch-url`
      nurl # CLI to generate nix fetcher calls from repository URLs.
      nh

      # LSPs
      marksman # Markdown LSP
      nil # Nix LSP
      yaml-language-server
      libclang # Includes `clangd`
      zls # Zig LSP

      # Terminal
      tokei
      ttyper
      neofetch
      onefetch
      diskonaut
      oxker # Docker tui
      alejandra # Nix formatter
      delta # A syntax-highlighting pager for git
      openvpn
      kmon # Linux kernel manager and activity monitor
      mprocs # TUI tool to run multiple commands in parallel
      cloak # CLI OTP Authentication
      unzip
      (python3.withPackages my-python-packages)
      systeroid # More powerful alternative to `sysctl` with a tui
      hwinfo
      dmidecode
      iperf
      iperf2
      iperf3
      hyperfine # Benchmarking of terminal commands
      parallel

      # Development
      gitui
      cargo-expand # Expands rust macros
      cargo-info
      cargo-semver-checks # A tool to scan your rust crate for semver violations
      cargo-wizard
      gdb
      zig
      hvm # A massively parallel, optimal functional runtime

      # Cryptography
      # sequoia-sq
      safecloset
      gokey # Vault-less password derivation from master key

      # Misc
      nerdfonts

      # Cryptocurrency
      cointop

      # Bittorrent
      intermodal # Command line BitTorrent metainfo utility, execute `imdl`

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
        theme = "everforest_dark"; # Dark
        # theme = "ayu_light";
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
          # normal.family = "HackNerdFont";
          normal.family = "Terminus";
        };
        shell.program = "nu";
      };
    };
    nushell = {
      enable = true;
      shellAliases = {
        ns = "nix-shell";
        la = "lsd -la --group-directories-first -g --header";
        dt = "date now";
        night = "redshift -P -O 5000";
        bright = "sudo ${pkgs.brillo}/bin/brillo -u 150000 -A 10";
        dim = "sudo ${pkgs.brillo}/bin/brillo -u 150000 -U 10";
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
      };
      extraConfig = ''
        $env.config = {
          show_banner: false,
        };
        def skhx [] = { sk | xargs hx };
        def fhx [] = { fzf | xargs hx };

        $env.PATH = ($env.PATH | split row (char esep) |
          append ($env.HOME| path join .cargo/bin));
      '';
    };
    zellij = {
      enable = true;
      settings = {
        pane_frames = false;
        theme = "dracula";
      };
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
              run = "vlc $@";
              block = true;
            }
          ];
          document = [
            {
              run = "zathura $@";
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
              name = "*.png";
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
            {
              name = "*.pdf";
              use = "document";
            }
            {
              name = "*.flac";
              use = "musikcube";
            }
          ];
        };
      };
    };
    # When a directory has a `.envrc` file configured with ``, it will automatically enter the `nix develop` environment.
    # `echo "use flake" >> .envrc && direnv allow`
    direnv = {
      enable = true;
      enableNushellIntegration = true;
      config = {
        global = {
          hide_env_diff = true;
        };
      };
    };
  };
}
