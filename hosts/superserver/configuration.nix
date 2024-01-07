# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Enable ip forwarding for exposing tailscale subnet routes.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."ipv6.conf.all.forwarding" = 1;

  networking.hostName = "superserver"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "de";
    xkbVariant = "";
    videoDrivers = ["nvidia"];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
  };

  # Configure console keymap
  console.keyMap = "de";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.magewe = {
    isNormalUser = true;
    description = "magewe";
    extraGroups = ["networkmanager" "wheel"];
    packages = [];
    shell = pkgs.nushell;
  };

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # CLI
    nushell
    wget
    helix
    nil # Nix LSPA
    alejandra # Nix formatter
    lsd
    skim
    ripgrep
    zellij
    tmux
    htop
    bottom
    tree
    nvtop
    alacritty
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
    killall
    iperf
    lshw
    nmap
    docker-compose
  ];

  services.openssh.enable = true;
  services.tailscale.enable = true;
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd"];
        port = 9002;
      };
    };
  };
  # To not run out of memory in the tmpfs created by nix-shell
  services.logind.extraConfig = ''
    RuntimeDirectorySize=64G
    HandleLidSwitchDocked=ignore
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "magewe"];

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "magewe" = import ./../home.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
