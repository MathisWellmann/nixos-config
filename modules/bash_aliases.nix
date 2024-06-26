{...}: {
  programs.bash.shellAliases = {
    ns = "nix-shell";
    la = "lsd -la";
    skhx = "sk | xargs hx"; # Fuzzy search and open the selected file with `helix`
    fhx = "fzf | xargs hx"; # Same as above but with `fzf`
    night = "redshift -P -O 5000";
    bright = "sudo xbacklight -set 100";
    # Rust
    cu = "cargo update";
    cc = "cargo check";
    cb = "cargo build";
    cbr = "cargo build --release";
    cr = "cargo run";
    crr = "cargo run --release";
    cte = "cargo test";
    fmt = "cargo +nightly fmt";
    tfmt = "taplo fmt";
    udeps = "cargo +nightly udeps --all-targets";
  };
}
