# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "meshify"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    # package = config.boot.kernelPackages.nvidiaPackages.stable;
  };


  services.xserver = {
    enable = true;
    autorun = false;
    videoDrivers = ["nvidia"];
  };

  programs.hyprland = {
    enable = true;
    xwayland = {
      hidpi = true;
      enable = true;
    };
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # environment.sessionVariables = {
  #   WLR_NO_HARDWARE_CURSORS = "1";
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # CLI
    wget
    helix
    lsd
    skim
    ripgrep
    nushell
    zoxide
    starship
    tokei
    zellij
    ttyper
    taplo-cli
    lfs
    htop
    bottom
    neofetch
    onefetch
    tree 
    nvtop
    alacritty
    hyprland
    hyprpaper
    waybar
    wofi

    # Dev
    rustup
    git
    gitui
    oxker
    gcc
    cargo-flamegraph
    cargo-outdated
    delta
    crate2nix

    # Misc
    chromium
    firefox
    vlc
    keepassxc
    mate.eom
    typst
    zathura
    mongodb
    killall
    home-manager
  ];

  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    terminus_font
  ];

  nix.settings.trusted-users = [ "root" "magewe" ];

  services.openssh.enable = true;

  services.mongodb = {
    enable = true;
    dbpath = "/home/magewe/mongodb";
    user = "root";
    bind_ip = "0.0.0.0";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 27017 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.nameservers = [ "192.168.0.165" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
