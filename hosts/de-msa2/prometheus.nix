{config, ...}: let
  const = import ./constants.nix {};
  static_ips = import ../../modules/static_ips.nix;

  scrape_interval = "5s";
  scrape_timeout = "2s";

  node_scrape_configs = let
    # Hosts that are INTENTIONALLY powered off most of the time (laptops,
    # desktops, the wake-on-lan backup target de-n5). Their targets get
    # `always_on="false"` so the ScrapeTargetDown alert (alerting.nix) skips
    # them -- before this, their permanently-firing down-alerts re-paged every
    # 4h and buried real alerts. The always-on k3s/infra hosts (this host,
    # desg0, elitedesk) stay covered.
    intermittent_hosts = ["meshify" "superserver" "poweredge" "razerblade" "de-n5" "tensorbook"];
  in
    map (host: {
      job_name = "${host}-node";
      static_configs = [
        {
          targets = ["${host}:${toString config.services.prometheus.exporters.node.port}"];
          labels.always_on =
            if builtins.elem host intermittent_hosts
            then "false"
            else "true";
        }
        {
          targets = ["${host}:${toString config.services.prometheus.exporters.nvidia-gpu.port}"];
          labels.always_on =
            if builtins.elem host intermittent_hosts
            then "false"
            else "true";
        }
      ];
    }) ["127.0.0.1" "meshify" "superserver" "poweredge" "razerblade" "desg0" "de-n5" "elitedesk" "tensorbook"];
  # Scrapes the tikr pods running in the k3s cluster (deployments live in the
  # `nexus` repo, `env/prod.nix`). Pods are discovered through the Kubernetes
  # API: any pod annotated with `prometheus.io/scrape: "true"` is kept and
  # scraped on the port given by its `prometheus.io/port` annotation, so new
  # annotated apps are picked up without further config here. Pod IPs are
  # directly reachable from this host because `de-msa2` is a k3s node.
  #
  # The bearer token belongs to the `victoriametrics-scraper` ServiceAccount
  # (managed by the `nexus` repo, extracted from the
  # `victoriametrics-scraper-token` secret in the `tikr` namespace). Token and
  # k3s CA are exposed to the DynamicUser service via systemd `LoadCredential`
  # below.
  k8s_credentials_dir = "/run/credentials/victoriametrics.service";
  tikr_scrape_configs = [
    {
      job_name = "tikr-k8s-pods";
      inherit scrape_interval scrape_timeout;
      kubernetes_sd_configs = [
        {
          role = "pod";
          api_server = "https://127.0.0.1:6443";
          namespaces.names = ["tikr" "tikr-dev"];
          bearer_token_file = "${k8s_credentials_dir}/k8s_token";
          tls_config.ca_file = "${k8s_credentials_dir}/k8s_ca";
        }
      ];
      relabel_configs = [
        # Only scrape pods that opted in via the annotation.
        {
          source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"];
          action = "keep";
          regex = "true";
        }
        # Scrape the port given in the `prometheus.io/port` annotation.
        {
          source_labels = ["__address__" "__meta_kubernetes_pod_annotation_prometheus_io_port"];
          action = "replace";
          regex = "([^:]+)(?::\\d+)?;(\\d+)";
          replacement = "$1:$2";
          target_label = "__address__";
        }
        # One job per app (e.g. `tikr-binancespot-trade`), mirroring the
        # per-service jobs of the old NixOS module setup.
        {
          source_labels = ["__meta_kubernetes_pod_label_app"];
          target_label = "job";
        }
        {
          source_labels = ["__meta_kubernetes_pod_name"];
          target_label = "pod";
        }
        # Distinguish prod (`tikr`) from dev (`tikr-dev`): the producer/sink app
        # names are identical across environments (e.g. both run
        # `tikr-binancespot-trade`), so without this label their series would
        # collide under one `job`. The `namespace` label keeps them separate.
        {
          source_labels = ["__meta_kubernetes_namespace"];
          target_label = "namespace";
        }
      ];
    }
  ];
  # Scrapes the in-cluster iggy-server brokers (deployed by the `nexus` repo,
  # `env/tikr/iggy-server.nix`, into the `tikr` and `tikr-dev` namespaces).
  # Unlike the
  # producers/sinks the iggy-server pod is not annotated with
  # `prometheus.io/scrape`, so it is discovered here by its `app=iggy-server`
  # pod label instead and scraped on its HTTP API port, which serves the
  # Prometheus `/metrics` endpoint. Reuses the same Kubernetes service
  # discovery + credentials as `tikr_scrape_configs` above (pod IPs are
  # reachable from this host because `de-msa2` is a k3s node).
  iggy_k8s_scrape_configs = [
    {
      job_name = "iggy-server-k8s";
      inherit scrape_interval scrape_timeout;
      kubernetes_sd_configs = [
        {
          role = "pod";
          api_server = "https://127.0.0.1:6443";
          # Both environments' brokers: prod in `tikr`, dev in `tikr-dev`. The
          # dev broker uses the same `app=iggy-server` label and HTTP port, so
          # it is discovered and scraped the same way; the `namespace` relabel
          # below keeps the two apart.
          namespaces.names = ["tikr" "tikr-dev"];
          bearer_token_file = "${k8s_credentials_dir}/k8s_token";
          tls_config.ca_file = "${k8s_credentials_dir}/k8s_ca";
        }
      ];
      relabel_configs = [
        # Only keep the iggy-server broker pod.
        {
          source_labels = ["__meta_kubernetes_pod_label_app"];
          action = "keep";
          regex = "iggy-server";
        }
        # The iggy pod exposes two named container ports (`http` 3011 and
        # `tcp` 3012), so k8s SD role=pod emits one target per port -- two
        # targets per pod. Without this keep, the address rewrite below maps
        # both to <pod_ip>:3011 with identical final labels, and VM logs
        # `skipping duplicate scrape target with identical labels` every
        # scrape interval (pure journal spam -- metrics still flow from the
        # first target). Keep only the `http` port at discovery time so SD
        # emits a single target per pod; the rewrite then no-ops on it.
        # Robust to a port-number change (the http port is identified by name,
        # not number).
        {
          source_labels = ["__meta_kubernetes_pod_container_port_name"];
          action = "keep";
          regex = "http";
        }
        # Scrape the iggy HTTP API port, which serves `/metrics`.
        {
          source_labels = ["__address__"];
          action = "replace";
          regex = "([^:]+)(?::\\d+)?";
          replacement = "$1:${toString const.iggy_http_port}";
          target_label = "__address__";
        }
        {
          source_labels = ["__meta_kubernetes_pod_name"];
          target_label = "pod";
        }
        # Separate the prod (`tikr`) broker from the dev (`tikr-dev`) one: both
        # are scraped under `job=iggy-server-k8s`, so the `namespace` label is
        # what tells their series apart.
        {
          source_labels = ["__meta_kubernetes_namespace"];
          target_label = "namespace";
        }
      ];
    }
  ];
  # Scrapes the in-cluster GreptimeDB (deployed by the `nexus` repo,
  # `env/tikr/greptimedb.nix`, into the `tikr` and `tikr-dev` namespaces).
  # Replaces the former host-local podman GreptimeDB pruned from `nexus_dbs.nix`:
  # the database now runs in the cluster, pinned to this host by its node-local
  # ZFS data dir. Like the iggy broker its pod carries no `prometheus.io/scrape`
  # annotation, so it is discovered here by its `app=greptimedb` pod label and
  # scraped on its HTTP API port -- GreptimeDB standalone serves the Prometheus
  # `/metrics` endpoint on the HTTP port (4000) by default. Reuses the same
  # Kubernetes service discovery + credentials as the jobs above (pod IPs are
  # reachable from this host because `de-msa2` is a k3s node).
  greptimedb_k8s_scrape_configs = [
    {
      job_name = "greptimedb-k8s";
      inherit scrape_interval scrape_timeout;
      kubernetes_sd_configs = [
        {
          role = "pod";
          api_server = "https://127.0.0.1:6443";
          # Both environments' databases: prod in `tikr`, dev in `tikr-dev`. The
          # dev DB uses the same `app=greptimedb` label and HTTP port, so it is
          # discovered and scraped the same way; the `namespace` relabel below
          # keeps the two apart.
          namespaces.names = ["tikr" "tikr-dev"];
          bearer_token_file = "${k8s_credentials_dir}/k8s_token";
          tls_config.ca_file = "${k8s_credentials_dir}/k8s_ca";
        }
      ];
      relabel_configs = [
        # Only keep the GreptimeDB pod.
        {
          source_labels = ["__meta_kubernetes_pod_label_app"];
          action = "keep";
          regex = "greptimedb";
        }
        # The pod exposes two named container ports (`grpc` 4001 and `http`
        # 4000), so k8s SD role=pod emits one target per port -- two per pod.
        # Keep only the `http` port at discovery time so SD emits a single
        # target per pod; otherwise the address rewrite below maps both to
        # <pod_ip>:4000 with identical labels and VM logs `skipping duplicate
        # scrape target` every interval. Identified by name, so robust to a
        # port-number change.
        {
          source_labels = ["__meta_kubernetes_pod_container_port_name"];
          action = "keep";
          regex = "http";
        }
        # Scrape the GreptimeDB HTTP API port, which serves `/metrics`.
        {
          source_labels = ["__address__"];
          action = "replace";
          regex = "([^:]+)(?::\\d+)?";
          replacement = "$1:${toString const.greptimedb_http_port}";
          target_label = "__address__";
        }
        {
          source_labels = ["__meta_kubernetes_pod_name"];
          target_label = "pod";
        }
        # Separate the prod (`tikr`) DB from the dev (`tikr-dev`) one: both are
        # scraped under `job=greptimedb-k8s`, so the `namespace` label is what
        # tells their series apart.
        {
          source_labels = ["__meta_kubernetes_namespace"];
          target_label = "namespace";
        }
      ];
    }
  ];
  # Per-pod CPU/memory via cAdvisor. cAdvisor is built into every k3s
  # kubelet and exposes container resource metrics at
  # `https://<node>:10250/metrics/cadvisor` (series like
  # `container_cpu_usage_seconds_total`,
  # `container_memory_working_set_bytes`,
  # `container_cpu_cfs_throttled_periods_total`). Discovered via k8s SD
  # `role: node` so every node's kubelet is scraped once, and the resulting
  # series are labelled by namespace/pod/container -- filter `namespace=tikr`
  # (or `tikr-dev`) in Grafana for the per-service resource view, including
  # the producers/sinks whose `memoryLimit` was the subject of the 2026-06-12
  # node-wide OOM.
  #
  # Reuses the same `victoriametrics-scraper` ServiceAccount token as the pod
  # jobs above: that ClusterRole (managed in the `nexus` repo,
  # `env/tikr/victoriametrics-scraper.nix`) grants `nodes/stats` so the kubelet
  # authorizes the bearer token. No metrics-server, node-exporter or extra
  # DaemonSet -- the kubelet already emits everything needed for long-term
  # per-pod resource time series.
  # ponytail: scrapes the whole node's cAdvisor rather than per-pod sidecars;
  # if you ever want only tikr pods, drop a metric_relabel keep on
  # namespace=tikr instead of deploying per-pod exporters.
  cadvisor_scrape_configs = [
    {
      job_name = "kubernetes-cadvisor";
      inherit scrape_interval scrape_timeout;
      scheme = "https";
      bearer_token_file = "${k8s_credentials_dir}/k8s_token";
      # k3s kubelet serves a per-node cert, not the API server CA, so verify
      # would fail against `k8s_ca`. The kubelet is on the LAN behind the same
      # API authn, so skip verify (same trade-off the k3s docs make for
      # `kubectl --insecure-skip-tls-verify` against kubelet stats).
      tls_config.insecure_skip_verify = true;
      kubernetes_sd_configs = [
        {
          role = "node";
          api_server = "https://127.0.0.1:6443";
          bearer_token_file = "${k8s_credentials_dir}/k8s_token";
          tls_config.ca_file = "${k8s_credentials_dir}/k8s_ca";
        }
      ];
      relabel_configs = [
        # k8s SD role=node returns `<node_ip>:10250` (default kubelet port),
        # so this is a no-op -- but it pins the path explicitly in case a node
        # advertises a non-default port, and documents that we scrape the
        # kubelet, not the API.
        {
          source_labels = ["__address__"];
          regex = "([^:]+):.*";
          replacement = "$1:10250";
          target_label = "__address__";
        }
        # Surface the node's own labels (e.g. kubernetes.io/hostname) as
        # Prometheus labels so per-node filtering works in Grafana.
        {
          action = "labelmap";
          regex = "__meta_kubernetes_node_label_(.+)";
        }
        {
          source_labels = ["__meta_kubernetes_node_name"];
          target_label = "node";
        }
      ];
      metric_relabel_configs = [
        # cAdvisor emits a series for the pod-level aggregate (container="POD")
        # and the node-level aggregate (container=""); the per-container
        # series (container!="POD" && container!="") is what you chart. Drop
        # the POD aggregate to halve the series count -- the per-container
        # numbers already cover everything you'd compute from it.
        {
          source_labels = ["container"];
          regex = "POD";
          action = "drop";
        }
      ];
    }
  ];
  scrapeConfigs =
    node_scrape_configs
    ++ tikr_scrape_configs
    ++ iggy_k8s_scrape_configs
    ++ greptimedb_k8s_scrape_configs
    ++ cadvisor_scrape_configs
    ++ [
      {
        job_name = "zfs";
        static_configs = [
          {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}"];}
        ];
      }
      # The legacy host-local iggy-server (see `nexus_dbs.nix`,
      # `services.iggy-server`). The in-cluster broker is scraped by
      # `iggy_k8s_scrape_configs` above.
      {
        job_name = "iggy-server-host";
        static_configs = [
          {targets = ["127.0.0.1:${toString const.iggy_http_port}"];}
        ];
      }
      {
        job_name = "mongodb";
        static_configs = [
          {targets = ["${static_ips.de-msa2_ip}:${toString const.mongodb_port}"];}
        ];
      }
      {
        job_name = "dragonflydb";
        static_configs = [
          {targets = ["${static_ips.de-msa2_ip}:${toString const.dragonfly_port}"];}
        ];
      }
      {
        job_name = "ups";
        static_configs = [
          {targets = ["localhost:${toString const.prometheus_exporter_nut_port}"];}
        ];
      }
    ];
in {
  # Drop in replacement for `prometheus`, but more efficient.
  services = {
    # defaults to storing data in `/var/lib/victoriametrics`
    victoriametrics = {
      enable = true;
      listenAddress = "0.0.0.0:${toString const.victoriametrics_port}";
      retentionPeriod = "5y";
      prometheusConfig = {
        scrape_configs = scrapeConfigs;
      };
    };
    # defaults to storing data in `/var/lib/victorialogs`
    victorialogs = {
      enable = true;
      listenAddress = ":${toString const.victorialogs_port}";
    };
  };

  # Kube API credentials for the tikr pod discovery above. `LoadCredential`
  # because the service runs as a `DynamicUser` and can read neither the
  # agenix secret nor the root-owned k3s CA directly.
  age.secrets.vm_k8s_token.file = ../../secrets/vm_k8s_token.age;
  systemd.services.victoriametrics.serviceConfig.LoadCredential = [
    "k8s_token:${config.age.secrets.vm_k8s_token.path}"
    "k8s_ca:/var/lib/rancher/k3s/server/tls/server-ca.crt"
  ];
}
