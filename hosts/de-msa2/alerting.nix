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
          expr = ''
            node_load5
              / count by (instance) (node_cpu_seconds_total{mode="idle"})
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
              / count by (instance) (node_cpu_seconds_total{mode="idle"})
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
            description = ''{{ printf "%.0f" (mul $value 100) }}% used. Free space or expand the volume.'';
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
          alert = "ScrapeTargetDown";
          expr = ''up == 0'';
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
            # The topic is effectively a password (anyone who knows it can read
            # the alerts). Fine on the tailnet/LAN; if you ever expose ntfy
            # publicly, move this to `extraConfigFiles` (an agenix secret) and
            # enable ntfy auth.
            topic = "cluster-alerts";
            # Firing -> phone-waking "high" priority; resolved -> quiet "default".
            priority = ''status == "firing" ? "high" : "default"'';
            tags = [
              {
                tag = "rotating_light";
                condition = ''status == "firing"'';
              }
              {
                tag = "white_check_mark";
                condition = ''status == "resolved"'';
              }
            ];
            templates = {
              title = ''{{ if eq .Status "resolved" }}Resolved: {{ end }}{{ index .Annotations "summary" }}'';
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
        # Reachable on the LAN/tailnet; the ntfy app subscribes to
        # `http://de-msa2:${toString const.ntfy_port}/cluster-alerts`.
        base-url = "http://de-msa2:${toString const.ntfy_port}";
        listen-http = ":${toString const.ntfy_port}";
        behind-proxy = false;
      };
    };
  };

  # Open ntfy so the phone/desktop app can reach it over the LAN/tailnet.
  # vmalert, alertmanager and the bridge all bind to 127.0.0.1 and need no
  # firewall holes.
  networking.firewall.allowedTCPPorts = [const.ntfy_port];
}
