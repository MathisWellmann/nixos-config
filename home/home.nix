{pkgs, ...}: let
  # Tool for cloning all starred github repos
  solar = pkgs.buildGoModule {
    name = "solar";
    src = builtins.fetchGit {
      url = "https://github.com/gleich/solar";
      rev = "6b271d88f3b85cec06b3894ea775376e733c3fe5";
    };
    vendorHash = "sha256-FIaGChSMHufD+OE9ZP/fgI8TAtVdw/JCuhMAm4vMn/w=";
  };
  const = import ../global_constants.nix;
in {
  imports = [
    ./helix.nix
    ./vcs.nix
    ./shell.nix
    ./yazi.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "${const.username}";
  home.homeDirectory = "/home/${const.username}";
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
        # pymc3 # markov chain monte carlo methods.
        matplotlib # Plotting
      ];
  in
    with pkgs; [
      # Misc
      viu # View images in the terminal, best with `kitty`
      unsure # Calculate with numbers you are unsure about.
      jq # Json toolkit
      terminus_font
      rdfind # Find duplicate files: e.g.: `rdfind .`
      fend # Unit aware calculator
      cmatrix
      glow # Render markdown in the terminal
      iotop
      trippy # Network diagnostics with traceroute and ping
      qmk
      qmk_hid
      hid-listen # Prints debugging information from usb HID devices
      appimage-run
      fuse # Required for onekey wallet appimage to recognize the device
      fio # Flexible IO tester: fio --name=seqwrite --ioengine=libaio --direct=1 --bs=1M --numjobs=1 --size=1G --rw=write --filename=/mnt/nfs/testfile
      ueberzugpp # Required to display images in alacritty with yazi
      compose2nix
      cfspeedtest # CLI for speed.cloudflare.com
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
      cloudflared
      jjui # terminal user interface for working with jujutsu VSC
      typespeed
      # lazyjj # Broken
      sops # Secrets for NixOs
      sequoia # `sq` re-implementation of gpg

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
      openvpn
      kmon # Linux kernel manager and activity monitor
      mprocs # TUI tool to run multiple commands in parallel
      cloak # CLI OTP Authentication
      unzip
      (python311.withPackages my-python-packages)
      systeroid # More powerful alternative to `sysctl` with a tui
      hwinfo
      dmidecode
      iperf
      parallel
      du-dust
      ouch # Obvious unified compression helper
      rage # Modern encryption implemented in rust. Go reference is `age`
      bend # A massively parallel, high-level programming language
      futhark # A data-parallel functional programming language

      # Development
      gitui
      lazygit
      cargo-expand # Expands rust macros
      cargo-info
      cargo-wizard
      cargo-nextest
      devenv

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

  programs = {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;
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
