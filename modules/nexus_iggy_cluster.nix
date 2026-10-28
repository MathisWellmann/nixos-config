# Host-network ports of the replicated iggy clusters that the `nexus` repo
# deploys into k3s (prod `tikr` and staging `tikr-dev`). Import on every node
# of their rosters.
#
# The replicas run with `hostNetwork`: iggy 0.9 binds each replica's consensus
# listener on its literal roster IP, and only the node IP is stable. So their
# traffic passes this host's firewall, unlike CNI `hostPort`/servicelb traffic
# (DNAT in PREROUTING, then FORWARD), which never reaches `nixos-fw`.
#
# The ports are a copy of nexus' `lib.iggyHostTcpPorts` (derived from its
# `env/tikr/iggy-clusters.nix`), not a flake input: that input is a
# `git+file` checkout under /home/m, which root (no forgejo credentials, the
# repo is private) and the fleet cache builder (0700 home) cannot read. As
# soon as the locked source left the store (store GC), every host that
# imports this module failed to evaluate with
# `getting status of "/home/m/MathisWellmann/nexus": Permission denied` --
# including de-n5, which has no checkout at all. The data is three lists of
# ports, so it is kept here: update it when nexus' roster or ports change.
# (On 2026-10-14 a hand-kept copy of an earlier, hard-coded version had not
# reached desg0, and its replica could not join the cluster.) nexus'
# `iggy-port-probe-*` CronJobs (alerts: `IggyHostPortBlocked*` in
# hosts/de-msa2/alerting.nix) catch a host that was not rebuilt.
{
  config,
  ...
}: let
  # prod `tikr` 7090-7092, staging `tikr-dev` 7190-7192, same three nodes.
  portsByHost = {
    "de-msa2" = [ 7090 7091 7092 7190 7191 7192 ];
    "de-n5" = [ 7090 7091 7092 7190 7191 7192 ];
    "desg0" = [ 7090 7091 7092 7190 7191 7192 ];
  };
  host = config.networking.hostName;
in {
  assertions = [
    {
      assertion = portsByHost ? ${host};
      message = "modules/nexus_iggy_cluster.nix: ${host} runs no iggy replica in nexus (lib.iggyHostTcpPorts has: ${toString (builtins.attrNames portsByHost)})";
    }
  ];
  networking.firewall.allowedTCPPorts = portsByHost.${host} or [];
}
