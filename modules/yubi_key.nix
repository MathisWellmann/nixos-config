{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    yubikey-manager # `ykman`
  ];
  # Required for `ykman` to be able to communicate with the usb key.
  services.pcscd.enable = true;
}
