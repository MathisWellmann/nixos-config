{pkgs, ...}: {
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
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
    # Dev
    rustup
    git
    gcc
    cargo-flamegraph
    cargo-outdated
    delta
    crate2nix
    taplo-cli
    # Misc
    typst
    killall
    iperf
    lshw
    nmap
    docker-compose
  ];
}
