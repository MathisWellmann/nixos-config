# Shared port definitions used across multiple hosts.
# Host-specific `constants.nix` files import this and extend as needed.
{
  nfs = 2049;
  iperf = 5201;
  mongodb = 27017;
}
