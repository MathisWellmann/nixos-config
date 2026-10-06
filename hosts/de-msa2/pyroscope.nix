# Grafana Pyroscope: continuous-profiling backend. The first clients are the
# `agent-symbiont-sliding-*` pods in the nexus repo, which push CPU profiles
# from inside the binary (pyroscope-rs SDK) to
# `http://100.83.142.17:<pyroscope_port>` (de-msa2's tailscale IP, the same
# path `env/logging.nix` uses for VictoriaLogs).
#
# Why here and not in the cluster: same observer/observed split as
# VictoriaMetrics, VictoriaLogs and Grafana. The profiles must survive cluster
# churn, and Grafana reads them over loopback (datasource in grafana.nix).
#
# Single binary (`target=all`) with the default filesystem storage, relative to
# the unit's `WorkingDirectory` -> `/var/lib/pyroscope/data` (root NVMe).
#
# Network exposure: only the HTTP port listens on all interfaces, and it is NOT
# in `allowedTCPPorts`. Tailscale's `ts-input` chain accepts all traffic on
# `tailscale0` before `nixos-fw`, so pods on every node reach it over the
# tailnet (checked from pods on de-msa2 and desg0), while the LAN cannot.
# gRPC, memberlist and the metastore raft port stay on loopback: in single
# binary mode they only talk to this process.
_: let
  const = import ./constants.nix;

  # Pyroscope auto-detects the address it advertises in each hash ring from
  # the "private network interfaces" (here the LAN IP 192.168.0.123). With
  # gRPC bound to loopback, the distributor then dials an address nobody
  # listens on and every push fails with `503 service is unavailable`
  # (reproduced locally with 2.3.1). Pin every ring to loopback instead; this
  # also stops the choice from depending on interface order (cni0, flannel,
  # podman, tailscale0 all exist on this host).
  ringAddrFlags = [
    "compactor.ring.instance-addr"
    "distributor.ring.instance-addr"
    "ingester.lifecycler.addr"
    "overrides-exporter.ring.instance-addr"
    "query-frontend.instance-addr"
    "query-scheduler.ring.instance-addr"
    "segment-writer.lifecycler.addr"
    "store-gateway.sharding-ring.instance-addr"
  ];
in {
  services.pyroscope = {
    enable = true;
    settings = {
      server = {
        http_listen_address = "0.0.0.0";
        http_listen_port = const.pyroscope_port;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = const.pyroscope_grpc_port;
      };
      memberlist.bind_addr = ["127.0.0.1"];
      # Do not report usage statistics to Grafana Labs.
      analytics.reporting_enabled = false;
      # Pyroscope profiles itself by default. That only adds a service nobody
      # looks at to the UI and to the disk.
      self_profiling.disable_push = true;
    };
    extraFlags =
      map (flag: "-${flag}=127.0.0.1") ringAddrFlags
      ++ [
        # Pyroscope's default, written down so the disk budget is visible.
        # Applies to the v2 storage that the default `v1-v2-dual` mode writes.
        "-retention-period=31d"
      ];
  };
}
