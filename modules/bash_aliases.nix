_: {
  programs.bash = {
    enable = true;
    shellAliases = {
      ns = "nix-shell";
      la = "lsd -la --group-directories-first -g --header";
      shx = "fd --type f --strip-cwd-prefix | sk | xargs hx"; # Fuzzy search and open the selected file with `helix`
      fhx = "fd --type f --strip-cwd-prefix | fzf | xargs hx"; # Same as above but with `fzf`
      night = "redshift -P -O 5000";
      bright = "sudo xbacklight -set 100";
      # Rust
      cu = "cargo update";
      cc = "cargo check";
      cb = "cargo build";
      cbr = "cargo build --release";
      cr = "cargo run";
      crr = "cargo run --release";
      cte = "cargo nextest run";
      fmt = "cargo +nightly fmt";
      tfmt = "taplo fmt";
      udeps = "cargo +nightly udeps --all-targets";
      todos = "rg --glob='*.{rs,nix,typst}' --line-number --color=always TODO";
    };
  };
}
