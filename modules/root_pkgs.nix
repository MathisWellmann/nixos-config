{
  pkgs,
  inputs,
  ...
}: {
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Terminal
    wget
    helix
    lsd
    skim # Fuzzy finder written in Rust
    fzf # Fuzzy finder written in Go
    ripgrep
    zellij
    tmux
    htop
    bottom
    tree
    nvtopPackages.full
    bat
    # Rust
    rustup
    rustfmt
    cargo-flamegraph
    cargo-outdated
    crate2nix
    taplo-cli
    # Dev
    git
    gcc
    docker-compose
    # Misc
    killall
    iperf
    lshw
    nmap
    inputs.agenix.packages."${system}".default
  ];
}
