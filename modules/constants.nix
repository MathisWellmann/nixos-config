{...}: let
  ports = import ./ports.nix;
in {
  adguardhome_port = 5000;
}
