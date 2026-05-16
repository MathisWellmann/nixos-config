{pkgs, ...}: let
  global_const = import ./../global_constants.nix;
in {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = "${global_const.username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout" # Allow access to serial device (for Arduino dev)
      "tty"
      "input" # Access to /dev/input for chara-opt keylogger
      "audio"
    ];
    packages = [];
    shell = pkgs.nushell;
  };
}
