{pkgs, ...}: {
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Terminal
    wget
    helix
    lsd
    skim
    ripgrep
    zellij
    tmux
    htop
    bottom
    tree
    nvtop
    bat
    # Rust
    cargo
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
  ];
}
