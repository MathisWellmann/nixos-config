# Host-network ports of the replicated iggy broker the `nexus` repo deploys
# into k3s (`env/tikr/iggy-server.nix`, `tikr.iggy.cluster` in `env/prod.nix`).
# Its replicas run with `hostNetwork`, so traffic to them goes through this
# host's firewall instead of the CNI (unlike the former LoadBalancer Service,
# whose servicelb DNAT bypassed it). Import on every node of the roster.
#   7090: client TCP (producers, sinks, off-cluster clients)
#   7091: HTTP API, web console and `/metrics`
#   7092: replica-to-replica consensus (authenticated by the cluster PSK)
_: {
  networking.firewall.allowedTCPPorts = [
    7090
    7091
    7092
  ];
}
