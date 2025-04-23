{
  pkgs,
  inputs,
  ...
}: let
  # Tool for cloning all starred github repos
  solar = pkgs.buildGoModule {
    name = "solar";
    src = builtins.fetchGit {
      url = "https://github.com/gleich/solar";
      rev = "6b271d88f3b85cec06b3894ea775376e733c3fe5";
    };
    vendorHash = "sha256-FIaGChSMHufD+OE9ZP/fgI8TAtVdw/JCuhMAm4vMn/w=";
  };
in {
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
        openai # Not using ClosedAi, but the package allows interacting with locally hosted ai services as well
      ];
    # Will be merged to nixpkgs soon: https://github.com/NixOS/nixpkgs/pull/398406
    codebook = pkgs.rustPlatform.buildRustPackage {
      name = "codebook";
      src = builtins.fetchGit {
        url = "https://github.com/blopker/codebook";
        rev = "d3a636da214f2ca2232413e5b2232532830e74ac";
      };
      cargoHash = "sha256-Olk5SjvJ5598sXjiuAQD/sW6MIfQpK9Q3JnDZWj9J7w=";
      nativeBuildInputs = with pkgs; [
        perl
        pkg-config
      ];
      buildinputs = with pkgs; [
        openssl
      ];
      buildAndTestSubdir = "crates/codebook-lsp";
      useFetchCargoVendor = true;
    };
  in
    with pkgs; [
      # Misc
      terminus_font
      rdfind # Find duplicate files: e.g.: `rdfind .`
      fend # Unit aware calculator
      cmatrix
      glow # Render markdown in the terminal
      iotop
      trippy # Network diagnostics with traceroute and ping
      qmk
      qmk_hid
      appimage-run
      fuse # Required for onekey wallet appimage to recognize the device
      fio # Flexible IO tester: fio --name=seqwrite --ioengine=libaio --direct=1 --bs=1M --numjobs=1 --size=1G --rw=write --filename=/mnt/nfs/testfile
      ueberzugpp # Required to display images in alacritty with yazi
      compose2nix
      cfspeedtest # CLI for speed.cloudflare.com
      ventoy
      solar
      ethtool
      mistral-rs # LLM inference written in Rust
      llama-cpp # LLM inference written in C++
      code2prompt
      natscli
      # For setting fan speed on supermicro BMC: `ipmitool -I lan -U ADMIN -H 192.168.0.31 sensor thresh FAN1 lcr 300`
      # Or `ipmitool -I lan -U ADMIN -H 192.168.0.31 sensor`
      ipmitool
      nvme-cli

      # Nix
      # Package version diff tool. E.g Compare system revision 405 with 420:
      # `nvd diff /nix/var/nix/profiles/system-405-link/ /nix/var/nix/profiles/system-420-link/`
      nvd
      nix-output-monitor # `nom` is a drop in replacement for `nix` that has pretty output
      nix-prefetch-scripts # Is used to obtain source hashes of urls. aka `nix-prefetch-url`
      nurl # CLI to generate nix fetcher calls from repository URLs.
      nh
      nix-tree
      nix-inspect
      deadnix # Dead code detection for nix
      statix # Lints and suggestions for nix code

      # LSPs
      marksman # Markdown LSP
      markdown-oxide # Personal knowledge management system LSP
      nil # Nix LSP
      yaml-language-server
      zls # Zig LSP
      tinymist # Typst markup language with `.typ` file extension
      lsp-ai # language server that serves as a backend for AI-powered functionality
      codebook

      # Terminal
      tokei
      ttyper
      neofetch
      onefetch
      # oxker     # Docker tui
      alejandra # Nix formatter
      # delta     # A syntax-highlighting pager for git
      # diffedit3 # jj helper to edit diffs in 3 panes
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
      parallel
      du-dust

      # Development
      gitui
      cargo-expand # Expands rust macros
      cargo-info
      cargo-wizard
      zig

      # Cryptography
      # sequoia-sq
      safecloset
      gokey # Vault-less password derived from master key.

      # Cryptocurrency
      cointop

      # Bittorrent
      intermodal # Command line BitTorrent metainfo utility, execute `imdl`
    ];

  fonts.fontconfig.enable = true;

  programs = let
    me = "MathisWellmann";
    email = "wellmannmathis@gmail.com";
  in {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;
    helix = {
      enable = true;
      package = inputs.helix;
      languages = {
        language-server.codebook = {
          command = "codebook-lsp";
          args = ["serve"];
        };
        language-server.lsp-ai = let
          max_context = 4096;
        in {
          command = "lsp-ai";
          environment = {LSP_AI_LOG = "debug";};
          timeout = 60;
          config = {
            memory.file_store = {};
            models.gemma3 = {
              type = "ollama";
              model = "gemma3:12b";
            };
            completion = {
              model = "gemma3";
              parameters = {
                max_context = max_context;
                options.num_predict = 32;
              };
            };
            chat = [
              {
                trigger = "!C";
                action_display_name = "chat_gemma3:12b";
                model = "gemma3";
                parameters = {
                  max_context = max_context;
                  max_tokens = 4096;
                  messages = [
                    {
                      role = "system";
                      content = "You are a rust code assistant chatbot. You will give expertly responses and follow best rust coding practices.";
                    }
                  ];
                };
              }
            ];
          };
        };
        language = [
          {
            name = "rust";
            language-servers = ["rust-analyzer" "codebook" "lsp-ai"];
          }
        ];
      };
      settings = {
        theme = "snazzy"; # Dark
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
          # Minimum severity to show a diagnostic after the end of a line.
          end-of-line-diagnostics = "hint";
          inline-diagnostics = {
            cursor-line = "error";
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
        ui = {
          editor = "hx";
          pager = "delta";
          paginate = "never";
          diff.format = "git";
        };
        snapshot.max-new-file-size = "10MB";
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

        # Jujutsu `jj` aliases
        jjl = "jj log";
        jjn = "jj new";
        jjd = "jj describe -m ";
        jjr = "jj rebase";
        jjf = "jj git fetch";
      };
      extraConfig = ''
        $env.config = {
          show_banner: false,
        };
        # using the `fd` command to respect `.gitignore`
        def shx [] { fd --type f --strip-cwd-prefix | sk | xargs hx };
        def fhx [] { fd --type f --strip-cwd-prefix | fzf | xargs hx };

        $env.PATH = ($env.PATH | split row (char esep) |
          append ($env.HOME| path join .cargo/bin) |
          append ($env.HOME| path join .pub-cache/bin));
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
              run = "hx $0";
              block = true;
            }
          ];
          image = [
            {
              run = "gthumb $@";
              block = true;
            }
          ];
          play = [
            {
              run = "mpv \"$@\"";
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
    # to cleanup old nix generations manually: nh clean all --keep 3
    # Its got `nh search`, `nh os switch`
    nh = {
      enable = true;
      clean = {
        enable = true;
        dates = "daily";
        extraArgs = "--keep 5 --keep-since 7d";
      };
    };
  };
}
