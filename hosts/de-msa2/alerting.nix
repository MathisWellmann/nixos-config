# Cluster-health alerting stack for de-msa2.
#
# Pipeline:
#   victoriametrics (services in `prometheus.nix`, scrapes nodes + k3s pods)
#     -> vmalert        evaluates the rule groups below against VM's HTTP API
#     -> alertmanager   groups / dedups / routes firing alerts
#     -> alertmanager-ntfy   bridge: turns alertmanager webhooks into ntfy pushes
#     -> ntfy-sh        push-notification server you subscribe to from the
#                       ntfy phone/desktop app (topic `cluster-alerts`)
#
# Everything is declared in Nix and rendered to config by the modules, so the
# whole stack -- including the alert rules -- is reproducible. Adding/editing an
# alert is just editing `ruleGroups` below and rebuilding.
#
# Motivating incident (2026-06-27): in-cluster greptimedb had no CPU limit on
# the 192-core desg0 node, sized its worker pools to all cores, pegged ~33 of
# them (load avg 177) and starved its own `/health` handler into liveness-probe
# timeouts. The `NodeLoadHigh` + `ContainerCPUNearLimit` rules fire on that
# signature from node/cadvisor metrics; the `PodRestartLooping` rule (from
# kube-state-metrics, see `kubernetes-pods` group) catches it once the failing
# probe restarts the pod.
_: let
  const = import ./constants.nix {};

  vmUrl = "http://127.0.0.1:${toString const.victoriametrics_port}";
  alertmanagerUrl = "http://127.0.0.1:${toString const.alertmanager_port}";

  # ── Alert rules ───────────────────────────────────────────────────────────
  # Sources: node_exporter (`node_*`), cadvisor (`container_*`), and
  # kube-state-metrics (`kube_*`, the `kubernetes-pods` group) -- all scraped by
  # the victoriametrics jobs in `prometheus.nix`.
  ruleGroups = [
    {
      name = "node-health";
      # 30s eval is plenty for slow-moving host metrics and keeps load on VM low.
      interval = "30s";
      rules = [
        {
          alert = "NodeLoadHigh";
          # load5 normalised by core count: > 0.8 means the run queue is ~80% of
          # the machine's CPUs for 10m. `count(node_cpu_seconds_total{mode=idle})`
          # is one series per core, so it equals nproc per instance.
          #
          # `on(instance)` is REQUIRED: without it the vector division matches
          # on the full label set, and node_load5 carries a `job` label the
          # `count by (instance)` side lacks -- the expression silently
          # evaluated to an empty vector and this alert could NEVER fire
          # (found during the 2026-07-02 desg0 CI-overload incident).
          expr = ''
            node_load5
              / on (instance) count by (instance) (node_cpu_seconds_total{mode="idle"})
              > 0.8
          '';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = ''High load on {{ $labels.instance }} (load5 {{ printf "%.0f" $value }}x cores)'';
            description = ''node_load5 has exceeded 80% of the core count for 10m. Check for a CPU-bound pod/process (cf. the 2026-06-27 greptimedb incident).'';
          };
        }
        {
          alert = "NodeLoadCritical";
          expr = ''
            node_load5
              / on (instance) count by (instance) (node_cpu_seconds_total{mode="idle"})
              > 2
          '';
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = ''Severe load on {{ $labels.instance }} (load5 {{ printf "%.1f" $value }}x cores)'';
            description = ''Run queue is more than 2x the core count -- the node is overloaded and may become unresponsive.'';
          };
        }
        {
          alert = "NodeLoadSpike";
          # load1 peak over the last 10m exceeding the core count. Complements
          # NodeLoadHigh two ways (2026-07-02 incident, where load1 hit 242 on
          # 192 cores but load5 stayed under the 0.8 bar):
          #   * load1 reacts in seconds where load5 smooths a burst away, and
          #   * `max_over_time` LATCHES the peak for 10m, so a short spike
          #     cannot dodge the alert by receding before an eval tick --
          #     no `for:` timer to reset (`for: 0m`).
          # A many-core host can starve latency-critical daemons (etcd fsync,
          # kubelet lease) during exactly such bursts.
          expr = ''
            max_over_time(node_load1[10m])
              / on (instance) count by (instance) (node_cpu_seconds_total{mode="idle"})
              > 1
          '';
          for = "0m";
          labels.severity = "warning";
          annotations = {
            summary = ''Load spike on {{ $labels.instance }} (load1 peaked at {{ printf "%.1f" $value }}x cores)'';
            description = ''node_load1 exceeded the core count within the last 10m. Bursts like this starve etcd/kubelet even when load5 stays under the NodeLoadHigh bar (cf. the 2026-07-02 CI-overload incident).'';
          };
        }
        {
          alert = "NodeDiskFillingUp";
          # Root/data filesystems above 90% used.
          expr = ''
            (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay"}
                 / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|overlay"})
            > 0.9
          '';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''Disk {{ $labels.mountpoint }} on {{ $labels.instance }} > 90% full'';
            description = "Disk usage is above 90%. Free space or expand the volume.";
          };
        }
        {
          alert = "NodeMemoryPressure";
          expr = ''
            (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.92
          '';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = ''Memory > 92% used on {{ $labels.instance }}'';
            description = ''Available memory is under 8% -- a node-wide OOM is possible (cf. 2026-06-12).'';
          };
        }
      ];
    }
    {
      name = "workload-health";
      interval = "30s";
      rules = [
        {
          alert = "ContainerCPUNearLimit";
          # Container burning > 90% of its cgroup CPU quota for 10m. The cadvisor
          # `container_spec_cpu_*` series expose the quota; usage is the rate of
          # cpu seconds. This is the direct "a pod is pegged against its limit"
          # signal the greptimedb incident lacked (it had NO limit then).
          # Only evaluated for containers that actually set a quota
          # (`container_spec_cpu_quota > 0`), so unlimited pods don't divide-by-zero.
          expr = ''
            sum by (namespace, pod, container) (rate(container_cpu_usage_seconds_total{container!="",container!="POD"}[5m]))
              / on (namespace, pod, container)
            (container_spec_cpu_quota{container!="",container!="POD"} / container_spec_cpu_period{container!="",container!="POD"})
              > 0.9
          '';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) CPU > 90% of limit'';
            description = ''The container has been throttled near its CPU limit for 10m. Either it is overloaded or the limit is too low.'';
          };
        }
        {
          alert = "ContainerCPUVeryHighNoLimit";
          # A container with NO cgroup quota burning > 16 cores for 10m -- the
          # exact greptimedb-on-desg0 footprint (no limit, ~33 cores). Catches
          # runaway unlimited pods before they take down a node, until every
          # workload has a proper limit.
          expr = ''
            sum by (namespace, pod, container) (rate(container_cpu_usage_seconds_total{container!="",container!="POD"}[5m]))
            > 16
            unless on (namespace, pod, container) (container_spec_cpu_quota{container!="",container!="POD"} > 0)
          '';
          for = "10m";
          labels.severity = "critical";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} burning {{ printf "%.0f" $value }} cores with NO CPU limit'';
            description = ''An unlimited container is consuming >16 cores. Add a `resources.limits.cpu` (cf. the 2026-06-27 greptimedb fix).'';
          };
        }
      ];
    }
    {
      name = "monitoring-meta";
      interval = "30s";
      rules = [
        {
          # If a scrape target disappears we'd otherwise go silent on its alerts.
          # Scoped to `always_on!="false"`: the node_exporter jobs for hosts
          # that are INTENTIONALLY powered off most of the time (laptops,
          # lab boxes, the wake-on-lan backup target -- labelled in
          # `prometheus.nix`) are excluded. Before this, 10+ dead-host
          # ScrapeTargetDown alerts had been firing continuously since
          # 2026-06-28, re-paging every 4h and drowning real signal (nobody
          # noticed the 2026-07-02 desg0 incident pages). K8s-discovered jobs
          # carry no `always_on` label and so are always covered.
          alert = "ScrapeTargetDown";
          expr = ''up{always_on!="false"} == 0'';
          for = "5m";
          labels.severity = "warning";
          annotations = {
            summary = ''Scrape target {{ $labels.job }} ({{ $labels.instance }}) is down'';
            description = ''victoriametrics has not been able to scrape this target for 5m.'';
          };
        }
      ];
    }

    # ── Kubernetes object-state alerts (from kube-state-metrics) ──────────────
    # These are the highest-signal alerts for the greptimedb incident class --
    # pod restart loops, not-ready pods, OOMKills, and pods stuck pending. They
    # derive from kube-state-metrics (`kube_*`), deployed in the `nexus` repo
    # (`env/tikr/kube-state-metrics.nix`, prod `tikr` namespace) and scraped by
    # the existing `tikr-k8s-pods` job. The 2026-06-27 greptimedb incident would
    # have surfaced here as `PodRestartLooping` once the failing liveness probe
    # restarted the pod.
    {
      name = "kubernetes-pods";
      interval = "30s";
      rules = [
        {
          alert = "PodRestartLooping";
          # More than 2 container restarts in 15m -- a probe-kill or OOM loop.
          expr = ''increase(kube_pod_container_status_restarts_total[15m]) > 2'';
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} restart looping'';
            description = ''Container {{ $labels.container }} restarted {{ printf "%.0f" $value }}x in 15m -- likely a failing liveness probe or OOM (cf. the 2026-06-27 greptimedb liveness-timeout incident).'';
          };
        }
        {
          alert = "ContainerOOMKilled";
          # Fire immediately on any OOMKill -- it is always worth knowing.
          expr = ''increase(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}[15m]) > 0'';
          for = "0m";
          labels.severity = "critical";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} OOMKilled'';
            description = ''Container {{ $labels.container }} was OOMKilled -- it hit its memory limit. Raise the limit or fix the leak (cf. the node-wide OOM on 2026-06-12).'';
          };
        }
        {
          alert = "PodNotReady";
          # A pod that exists but is not Ready for 15m (excludes terminal
          # Succeeded/Failed pods so completed jobs don't alert). Catches a
          # workload wedged un-Ready without necessarily restart-looping -- e.g.
          # a readiness probe failing because a dependency is down.
          expr = ''
            sum by (namespace, pod) (kube_pod_status_ready{condition="true"}) == 0
            and on (namespace, pod)
            sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Running|Unknown"}) > 0
          '';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} not Ready for 15m'';
            description = ''The pod is not passing its readiness check. Check the pod events and logs.'';
          };
        }
        {
          alert = "PodReadyFlapping";
          # Same flap-proof pattern as K3sNodeReadyFlapping, per pod: Ready
          # less than 90% of the last 15m. PodNotReady's 15m `for:` resets on
          # every brief Ready blip, so a pod bouncing in and out of Ready
          # (node flaps, crashlooping dependency, marginal readiness probe)
          # never fires it. Guards: only Running pods (completed Jobs don't
          # alert) that have existed longer than the window (a fresh rollout's
          # startup un-readiness is not a flap).
          expr = ''
            avg_over_time(kube_pod_status_ready{condition="true"}[15m]) < 0.9
              and on (namespace, pod)
            kube_pod_status_phase{phase="Running"} == 1
              and on (namespace, pod)
            (time() - kube_pod_start_time) > 900
          '';
          for = "0m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} readiness flapping (Ready {{ $value | humanizePercentage }} of the last 15m)'';
            description = ''The pod bounced in and out of Ready over the last 15m -- too briefly each time to trip PodNotReady. Look for node flapping, a marginal readiness probe, or an unstable dependency.'';
          };
        }
        {
          alert = "PodStuckPending";
          expr = ''sum by (namespace, pod) (kube_pod_status_phase{phase="Pending"}) > 0'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.pod }} stuck Pending for 15m'';
            description = ''The pod cannot schedule (no node fits its requests/affinity, or it is waiting on a volume).'';
          };
        }
        {
          alert = "DeploymentReplicasMismatch";
          # Desired != available for 15m -- a rollout that never converges.
          expr = ''
            kube_deployment_spec_replicas
              != kube_deployment_status_replicas_available
          '';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.namespace }}/{{ $labels.deployment }} has unavailable replicas'';
            description = ''Available replicas have not matched the desired count for 15m -- a stuck or failing rollout.'';
          };
        }
        {
          alert = "K3sNodeReadyFlapping";
          # Ready < 90% of the time over 15m -- catches a node OSCILLATING
          # NotReady<->Ready, which K3sNodeNotReady structurally cannot: its
          # 10m `for:` timer resets on every Ready blip, and during the
          # 2026-07-02 desg0 incident (1-2m NotReady episodes every few
          # minutes) it sat in `pending` for hours without firing. The same
          # reset also happens when kube-state-metrics itself runs on the sick
          # node and its scrape gaps produce no-data evals. `avg_over_time`
          # over the raw condition sidesteps both: the damage accumulates in
          # the window instead of a timer, so `for: 0m`.
          expr = ''
            avg_over_time(kube_node_status_condition{condition="Ready",status="true"}[15m]) < 0.9
          '';
          for = "0m";
          labels.severity = "critical";
          annotations = {
            summary = ''k3s node {{ $labels.node }} is flapping NotReady (Ready {{ $value | humanizePercentage }} of the last 15m)'';
            description = ''The node has been NotReady for more than 10% of the last 15m -- an intermittent kubelet stall (overload, I/O starvation) that the sustained K3sNodeNotReady alert misses. Check node load and what is starving the kubelet/etcd (cf. the 2026-07-02 CI-overload incident).'';
          };
        }
        {
          alert = "K3sNodeNotReady";
          # A cluster node that is not Ready for 10m. The pod alerts above only
          # catch workloads; this catches a whole node dropping out (kubelet
          # down, network partition, host crash) -- which would otherwise only
          # surface indirectly as the pods on it going un-Ready/Pending.
          expr = ''
            kube_node_status_condition{condition="Ready",status="true"} == 0
          '';
          for = "10m";
          labels.severity = "critical";
          annotations = {
            summary = ''k3s node {{ $labels.node }} is NotReady'';
            description = ''The node has not reported Ready for 10m -- kubelet down, host crashed, or a network partition. Pods on it will be evicted/rescheduled.'';
          };
        }
      ];
    }

    # ── Storage health (ZFS pools + filesystem/inode capacity + PVCs) ─────────
    # The existing `NodeDiskFillingUp` (node-health) catches a filesystem past
    # 90% used; these cover the blind spots around it: a degraded ZFS pool
    # (silent data-loss risk), inode exhaustion (writes fail while `df` still
    # shows free bytes), a *predicted* fill before the 90% cliff, and the
    # in-cluster PVCs (iggy/greptimedb data volumes).
    {
      name = "storage-health";
      interval = "30s";
      rules = [
        {
          alert = "ZpoolDegraded";
          # `node_zfs_zpool_state{state=...}` is 1 for the pool's CURRENT state.
          # Any active state other than `online` (degraded/faulted/offline/
          # removed/suspended/unavail) means a vdev/disk dropped -- the silent
          # failure the weekly autoScrub + de-n5 replication exist to survive.
          # Covers both this host's `nvme_pool` and de-n5's `hdd_pool` (the
          # off-site replica), since node-exporter on both is scraped.
          expr = ''node_zfs_zpool_state{state!="online"} == 1'';
          for = "1m";
          labels.severity = "critical";
          annotations = {
            summary = ''ZFS pool {{ $labels.zpool }} is {{ $labels.state }} on {{ $labels.instance }}'';
            description = ''The pool left the `online` state -- a disk likely faulted. Run `zpool status -v {{ $labels.zpool }}`, replace/resilver the device, and check the de-n5 replica.'';
          };
        }
        {
          alert = "NodeInodeFillingUp";
          # Inode exhaustion fails writes (ENOSPC) while `df` still shows free
          # bytes, so the byte-based NodeDiskFillingUp misses it. Fires under
          # 20% free inodes on a real (non-virtual) filesystem.
          expr = ''
            (node_filesystem_files_free{fstype!~"tmpfs|ramfs|overlay"}
               / node_filesystem_files{fstype!~"tmpfs|ramfs|overlay"})
            < 0.20
            and node_filesystem_files{fstype!~"tmpfs|ramfs|overlay"} > 0
          '';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''Inodes < 20% free on {{ $labels.mountpoint }} ({{ $labels.instance }})'';
            description = ''The filesystem is running out of inodes (lots of small files); writes will fail with ENOSPC even though free space remains. Delete files or recreate the FS with more inodes.'';
          };
        }
        {
          alert = "NodeDiskFillPredicted";
          # Linear-extrapolate the last 6h of free space: if it trends to empty
          # within 24h, warn now -- before the 90%-used NodeDiskFillingUp cliff,
          # giving time to act on a steady leak rather than paging at the edge.
          expr = ''
            predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay"}[6h], 24*3600) < 0
            and (node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay"}
                   / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|overlay"}) < 0.30
          '';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = ''Disk {{ $labels.mountpoint }} on {{ $labels.instance }} predicted full within 24h'';
            description = ''At the current fill rate this filesystem runs out of space in under 24h. Free space or expand the volume before it hits the hard limit.'';
          };
        }
        {
          alert = "PersistentVolumeFillingUp";
          # The kubelet exports per-PVC usage (already scraped for cadvisor).
          # Catches the iggy/greptimedb data volumes filling before they wedge
          # the workload. Under 10% free.
          expr = ''
            (kubelet_volume_stats_available_bytes
               / kubelet_volume_stats_capacity_bytes)
            < 0.10
          '';
          for = "15m";
          labels.severity = "critical";
          annotations = {
            summary = ''PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} < 10% free'';
            description = ''The persistent volume is nearly full. Expand the PVC or free data before writes fail and the workload wedges.'';
          };
        }
        {
          alert = "PersistentVolumeInodesFillingUp";
          expr = ''
            (kubelet_volume_stats_inodes_free
               / kubelet_volume_stats_inodes)
            < 0.10
          '';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = ''PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} < 10% inodes free'';
            description = ''The persistent volume is running out of inodes; writes will fail with ENOSPC even with free bytes remaining.'';
          };
        }
      ];
    }

    # ── Host integrity (systemd units, reboots, clock, NIC, host OOM) ─────────
    {
      name = "host-integrity";
      interval = "30s";
      rules = [
        {
          alert = "SystemdUnitFailed";
          # Requires the `systemd` collector (enabled in
          # modules/prometheus_exporter.nix). Catches any unit in the `failed`
          # state -- e.g. nfs-server, the zfs autoreplication timer, the NUT
          # services -- that would otherwise go unnoticed until something breaks.
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
          for = "5m";
          labels.severity = "warning";
          annotations = {
            summary = ''systemd unit {{ $labels.name }} failed on {{ $labels.instance }}'';
            description = ''The unit is in the `failed` state. Inspect with `systemctl status {{ $labels.name }}` / `journalctl -u {{ $labels.name }}`.'';
          };
        }
        {
          alert = "HostUnexpectedReboot";
          # The host booted within the last 10m. A planned `nixos-rebuild switch`
          # does NOT reboot, so this firing means a crash, panic, or power event
          # (the UPS exists to prevent the last one). `for: 0m` -- report it as
          # soon as the freshly-booted node is scraped.
          expr = ''(node_time_seconds - node_boot_time_seconds) < 600'';
          for = "0m";
          labels.severity = "warning";
          annotations = {
            summary = ''{{ $labels.instance }} rebooted recently (up {{ printf "%.0f" $value }}s)'';
            description = ''The host booted in the last 10 minutes. If you did not plan this, it crashed or lost power -- check `journalctl -b -1 -e` for the cause.'';
          };
        }
        {
          alert = "NodeClockSkew";
          # NTP offset over 0.5s. Clock skew breaks TLS handshakes, k3s leader
          # election, and corrupts the timestamp ordering of the tikr market
          # data this fleet exists to capture.
          expr = ''abs(node_timex_offset_seconds) > 0.5'';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = ''Clock skew on {{ $labels.instance }} ({{ printf "%.2f" $value }}s offset)'';
            description = ''The system clock is more than 0.5s off NTP for 10m. Check `timedatectl` / the NTP service -- skew breaks TLS, k3s, and market-data timestamps.'';
          };
        }
        {
          alert = "NodeNetworkReceiveErrors";
          # Sustained RX errors point at a flaky NIC, cable, or driver.
          expr = ''rate(node_network_receive_errs_total{device!~"lo|veth.*|cni.*|flannel.*|cali.*"}[5m]) > 1'';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = ''Network RX errors on {{ $labels.instance }} ({{ $labels.device }})'';
            description = ''The interface is logging receive errors -- likely a failing NIC, cable, or driver issue.'';
          };
        }
        {
          alert = "NodeOOMKill";
          # Host-level OOM kills (from /proc/vmstat). Distinct from the k8s
          # `ContainerOOMKilled` alert, which only catches cgroup-limited
          # containers -- this is the node-wide signature of the 2026-06-12 OOM.
          expr = ''increase(node_vmstat_oom_kill[15m]) > 0'';
          for = "0m";
          labels.severity = "critical";
          annotations = {
            summary = ''OOM kill on {{ $labels.instance }}'';
            description = ''The host kernel OOM-killed a process in the last 15m -- memory pressure at the node level (cf. the 2026-06-12 node-wide OOM). Check `dmesg`/`journalctl -k` for the victim.'';
          };
        }
      ];
    }

    # ── Core tikr datastores: named, higher-severity down alerts ──────────────
    # `ScrapeTargetDown` (monitoring-meta) already catches any target's `up==0`
    # as a warning, but iggy-server and GreptimeDB are the heart of the trading
    # pipeline, so they get dedicated `critical` alerts that page rather than
    # warn. Scoped to the prod (`tikr`) namespace so a dev outage stays a warning
    # via ScrapeTargetDown (and routes to the dev ntfy topic) rather than paging.
    {
      name = "tikr-datastores";
      interval = "30s";
      rules = [
        {
          alert = "GreptimeDBDown";
          expr = ''up{job="greptimedb-k8s",namespace="tikr"} == 0'';
          for = "2m";
          labels.severity = "critical";
          annotations = {
            summary = ''GreptimeDB (prod) is down'';
            description = ''The in-cluster GreptimeDB has been unscrapeable for 2m -- the sinks cannot write and the dashboard cannot read. Check the `greptimedb` pod in the `tikr` namespace.'';
          };
        }
        {
          alert = "IggyServerDown";
          expr = ''up{job="iggy-server-k8s",namespace="tikr"} == 0'';
          for = "2m";
          labels.severity = "critical";
          annotations = {
            summary = ''iggy-server (prod) is down'';
            description = ''The in-cluster iggy broker has been unscrapeable for 2m -- producers cannot publish and sinks cannot consume. Check the `iggy-server` pod in the `tikr` namespace.'';
          };
        }
      ];
    }
  ];
in {
  services = {
    # ── vmalert: evaluate the rules above against victoriametrics ────────────
    vmalert.instances.cluster-health = {
      enable = true;
      settings = {
        "datasource.url" = vmUrl;
        "notifier.url" = [alertmanagerUrl];
        # Persist the synthetic `ALERTS`/`ALERTS_FOR_STATE` series back into VM
        # so alert state survives a vmalert restart (avoids re-firing `for:`
        # alerts from scratch on every rebuild).
        "remoteWrite.url" = vmUrl;
      };
      # Rendered to a rules YAML file by the module -- the reproducible bit.
      rules.groups = ruleGroups;
    };

    # ── alertmanager: group / dedup / route to the ntfy bridge ───────────────
    prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = const.alertmanager_port;
      configuration = {
        route = {
          receiver = "ntfy";
          # Collapse a storm of the same alert into one notification, then send
          # follow-ups sparingly.
          group_by = ["alertname" "namespace"];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
        };
        receivers = [
          {
            name = "ntfy";
            webhook_configs = [
              {
                url = "http://127.0.0.1:${toString const.alertmanager_ntfy_port}/hook";
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    # ── alertmanager-ntfy: webhook -> ntfy push, with templated title/priority ─
    prometheus.alertmanager-ntfy = {
      enable = true;
      settings = {
        http.addr = "127.0.0.1:${toString const.alertmanager_ntfy_port}";
        ntfy = {
          baseurl = "http://127.0.0.1:${toString const.ntfy_port}";
          notification = {
            # Split prod vs dev by the alert's `namespace` label (set by KSM /
            # cadvisor on every pod alert). Dev (`tikr-dev`) alerts go to a
            # SEPARATE ntfy topic so a dev hiccup never looks like a prod page
            # and can be muted independently -- but they are still delivered, so
            # any dev problem (which should block a rollout) is visible.
            #
            # gval scope is the alert's JSON map (see alertmanager-ntfy's
            # `Alert.Map()`): `status` plus the `labels`/`annotations` maps.
            # Guard the map lookup with `in` so node-level alerts that carry no
            # `namespace` label (e.g. NodeLoadHigh) don't error -- they fall
            # through to the prod topic, which is correct (a node problem is
            # everyone's problem).
            #
            # Topics are de-facto passwords; both live on the tailnet/LAN. If you
            # ever expose ntfy publicly, move these to `extraConfigFiles` (an
            # agenix secret) + ntfy auth.
            topic = ''("namespace" in labels && labels["namespace"] == "tikr-dev") ? "cluster-alerts-dev" : "cluster-alerts"'';
            # Prod firing -> phone-waking "high"; dev firing -> quiet "default"
            # (notify, don't page); anything resolved -> "min".
            priority = ''
              status == "resolved" ? "min"
                : (("namespace" in labels && labels["namespace"] == "tikr-dev") ? "default" : "high")
            '';
            tags = [
              {
                tag = "rotating_light";
                condition = ''status == "firing" && !("namespace" in labels && labels["namespace"] == "tikr-dev")'';
              }
              {
                tag = "construction";
                condition = ''status == "firing" && ("namespace" in labels && labels["namespace"] == "tikr-dev")'';
              }
              {
                tag = "white_check_mark";
                condition = ''status == "resolved"'';
              }
            ];
            templates = {
              # Prefix dev alerts so they're unmistakable in the notification list.
              title = ''{{ if eq .Status "resolved" }}Resolved: {{ end }}{{ if eq (index .Labels "namespace") "tikr-dev" }}[dev] {{ end }}{{ index .Annotations "summary" }}'';
              description = ''{{ index .Annotations "description" }}'';
            };
          };
        };
      };
    };

    # ── ntfy: the push-notification server you subscribe to ──────────────────
    ntfy-sh = {
      enable = true;
      settings = {
        # Exposed off-cluster at https://ntfy.k3s.lan through the k3s traefik
        # ingress (see env/ntfy.nix); the ntfy app subscribes to BOTH topics:
        #   prod: https://ntfy.k3s.lan/cluster-alerts
        #   dev:  https://ntfy.k3s.lan/cluster-alerts-dev
        # with the fleet-trusted `k3s-lan-ca` cert. Topics are created
        # implicitly on first publish -- no server-side config per topic.
        # Mute/unsubscribe `cluster-alerts-dev` independently when you don't
        # want dev noise; prod pages keep coming.
        # `behind-proxy = true` so ntfy trusts the X-Forwarded-* headers
        # traefik sets.
        base-url = "https://ntfy.k3s.lan";
        listen-http = ":${toString const.ntfy_port}";
        behind-proxy = true;
      };
    };
  };

  # Open ntfy so the phone/desktop app can reach it over the LAN/tailnet.
  # vmalert, alertmanager and the bridge all bind to 127.0.0.1 and need no
  # firewall holes.
  networking.firewall.allowedTCPPorts = [const.ntfy_port];
}
