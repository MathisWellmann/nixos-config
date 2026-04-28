{...}: let
  shared = import ../../modules/ports.nix;
in {
  nfs_port = shared.nfs;
}
