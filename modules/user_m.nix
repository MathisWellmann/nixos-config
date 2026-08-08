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

    # Declarative peer SSH keys. These merge with (rather than replace) any
    # hand-maintained `~/.ssh/authorized_keys`, since NixOS appends
    # /etc/ssh/authorized_keys.d/%u to sshd's AuthorizedKeysFile.
    #
    # Why: authorized_keys used to be hand-copied per host, so reinstalling a
    # machine wiped it and key auth from every peer silently broke (hit on
    # 2026-08-08 after the de-n5 reinstall). Keeping the list here means a
    # freshly installed host is reachable from the whole fleet immediately.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTrWy6E9iG8lVS1LjISAczHxRHN34mdT9bF1zg6Yh6p m@meshify"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtbndl4uPNgCcQFyffE6yD0sUzp96bhaCQdMHUR6iqN m@desg0"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9KGI7L08vgpSrbArGJk3JDW2jq/T6t3/NmJOxGmQhe m@de-msa2"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlTXHIQW0+zj+XOq4V21ti6HyCQFb/gUMYpAW67MPew m@razerblade"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjfqwBPaXyCe0UlgMqAcKful0hZz3Vu3e/aNk2XSe6n m@tensorbook"
    ];
  };
}
