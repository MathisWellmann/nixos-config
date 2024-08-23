{...}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  nixpkgs.config.allowUnfree = true;

  security = {
    polkit.enable = true;
    pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "8192";
      }
    ];
  };

  services.openssh.enable = true;
  services.tailscale.enable = true;
  # To not run out of memory in the tmpfs created by nix-shell
  services.logind.extraConfig = ''
    RuntimeDirectorySize=64G
    HandleLidSwitchDocked=ignore
  '';

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "magewe"];

  # From: https://kokada.capivaras.dev/blog/an-unordered-list-of-hidden-gems-inside-nixos/
  networking.nftables.enable = true;
  # Essentially re-writes the script for changing the configuration to rust.
  system.switch = {
    enable = false;
    enableNg = true;
  };
}
