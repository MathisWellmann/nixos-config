# Host-network ports of the replicated iggy clusters that the `nexus` repo
# deploys into k3s (prod `tikr` and staging `tikr-dev`). Import on every node
# of their rosters.
#
# The replicas run with `hostNetwork`: iggy 0.9 binds each replica's consensus
# listener on its literal roster IP, and only the node IP is stable. So their
# traffic passes this host's firewall, unlike CNI `hostPort`/servicelb traffic
# (DNAT in PREROUTING, then FORWARD), which never reaches `nixos-fw`.
#
# The ports come from nexus (`lib.iggyHostTcpPorts`, derived from its
# `env/tikr/iggy-clusters.nix`), not from a copy here: on 2026-10-14 a
# hand-kept copy had not reached desg0, and its replica could not join the
# cluster. A roster change in nexus reaches this host with the next
# `nix flake update nexus` and rebuild. nexus' `iggy-port-probe-*` CronJobs
# (alerts: `IggyHostPortBlocked*` in hosts/de-msa2/alerting.nix) catch a host
# that was not rebuilt.
{
  config,
  inputs,
  ...
}: let
  portsByHost = inputs.nexus.lib.iggyHostTcpPorts;
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
