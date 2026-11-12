# Host-network ports of the replicated iggy clusters that the `nexus` repo
# deploys into k3s (prod `tikr` and staging `tikr-dev`). Import on every node
# of their rosters.
#
# The replicas run with `hostNetwork`: iggy 0.9 binds each replica's consensus
# listener on its literal roster IP, and only the node IP is stable. So their
# traffic passes this host's firewall, unlike CNI `hostPort`/servicelb traffic
# (DNAT in PREROUTING, then FORWARD), which never reaches `nixos-fw`.
#
# The ports are a copy of nexus' `lib.iggyHostTcpPorts`
# (`env/tikr/iggy-host-ports.nix`, derived from `env/tikr/iggy-clusters.nix`).
# This flake used to read them from a `nexus` input, but that input could only
# be the local checkout under /home/m (nexus is private on forgejo, and root has
# no credentials there). Only `m` can read that path, so every other builder
# (the cache builder on desg0, root without the locked source in its store)
# failed to evaluate these hosts as soon as the lock moved to a new nexus rev.
# The input also never kept the ports in sync by itself: a roster change needed
# a manual `nix flake update nexus` and a rebuild, as an edit here does now.
#
# If nexus changes the roster or the ports, update this copy and rebuild the
# nodes. To compare with nexus:
#   nix eval --json -f ~/MathisWellmann/nexus/env/tikr/iggy-host-ports.nix
# nexus' `iggy-port-probe-*` CronJobs (alerts: `IggyHostPortBlocked*` in
# hosts/de-msa2/alerting.nix) catch a node whose firewall misses a port.
{
  config,
  lib,
  ...
}: let
  # Each cluster runs one replica on every node, on the same ports:
  # tcp, http and replica (consensus).
  clusterPorts = {
    tikr = [7090 7091 7092];
    tikr-dev = [7190 7191 7192];
  };
  nodePorts = lib.concatLists (lib.attrValues clusterPorts);
  portsByHost = lib.genAttrs ["de-msa2" "de-n5" "desg0"] (_: nodePorts);
  host = config.networking.hostName;
in {
  assertions = [
    {
      assertion = portsByHost ? ${host};
      message = "modules/nexus_iggy_cluster.nix: ${host} runs no iggy replica (the roster has: ${toString (builtins.attrNames portsByHost)})";
    }
  ];
  networking.firewall.allowedTCPPorts = portsByHost.${host} or [];
}
