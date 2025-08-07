{pkgs, ...}: {
  programs = {
    nushell = {
      enable = true;
      shellAliases = {
        ns = "nix-shell";
        la = "lsd -la --group-directories-first -g --header";
        dt = "date now";
        night = "redshift -P -O 5000";
        bright = "sudo ${pkgs.brillo}/bin/brillo -u 150000 -A 10";
        dim = "sudo ${pkgs.brillo}/bin/brillo -u 150000 -U 10";

        todos = "rg --glob='*.{rs,nix,typst}' --line-number --color=always TODO";

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
        cte = "cargo nextest run";

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
        def shx [] { ${pkgs.fd}/bin/fd --type f --strip-cwd-prefix | ${pkgs.skim}/bin/sk | xargs ${pkgs.helix}/bin/hx };
        def fhx [] { ${pkgs.fd}/bin/fd --type f --strip-cwd-prefix | ${pkgs.fzf}/bin/fzf | xargs ${pkgs.helix}/bin/hx };

        # Find all the TODO comments in my codebases
        def todo [] { ${pkgs.ripgrep}/bin/rg --glob='*.{rs,nix,typst}' --line-number --color=always TODO | lines };

        $env.PATH = ($env.PATH | split row (char esep) |
          append ($env.HOME| path join .cargo/bin) |
          append ($env.HOME| path join .npm-global/bin) |
          append ($env.HOME| path join .pub-cache/bin));
      '';
    };
    # Terminal multiplexing
    zellij = {
      enable = true;
      settings = {
        pane_frames = false;
        theme = "dracula";
      };
    };
    # Fancy prompt.
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
    # Navigate with ease to commonly used directories.
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
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
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
