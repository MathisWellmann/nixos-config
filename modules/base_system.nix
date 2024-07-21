{lib, ...}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.allowUnfree = true;

  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

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
}
