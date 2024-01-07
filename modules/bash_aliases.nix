{...}: {
  programs.bash.shellAliases = {
    la = "lsd -la";
    cu = "cargo update";
    cc = "cargo check";
    cb = "cargo build";
    cbr = "cargo build --release";
    cr = "cargo run";
    crr = "cargo run --release";
    cte = "cargo test";
    fmt = "cargo +nightly fmt";
    tfmt = "taplo fmt";
  };
}
