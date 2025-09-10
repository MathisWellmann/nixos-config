{...}: let
  const = import ../global_constants.nix;
in {
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
        value = "65536";
      }
    ];
  };

  services.openssh.enable = true;
  services.tailscale.enable = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "${const.username}"];

  system.switch = {
    enable = true;
  };

  hardware.keyboard.qmk.enable = true;

  programs.dconf.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Don't ask for user password for main user.
  security.sudo.extraRules = [
    {
      users = ["${const.username}"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
