{config, ...}: let
  const = import ./constants.nix {};
  static_ips = import ../../modules/static_ips.nix;
  node_scrape_configs = map (host: {
    job_name = "${host}-node";
    static_configs = [
      {
        targets = ["${host}:${toString config.services.prometheus.exporters.node.port}"];
      }
      {
        targets = ["${host}:${toString config.services.prometheus.exporters.nvidia-gpu.port}"];
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
      scrape_interval = "5s";
      scrape_timeout = "2s";
      kubernetes_sd_configs = [
        {
          role = "pod";
          api_server = "https://127.0.0.1:6443";
          namespaces.names = ["tikr"];
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
      ];
    }
  ];
  # Scrapes the in-cluster iggy-server broker (deployed by the `nexus` repo,
  # `env/tikr/iggy-server.nix`, into the `tikr` namespace). Unlike the
  # producers/sinks the iggy-server pod is not annotated with
  # `prometheus.io/scrape`, so it is discovered here by its `app=iggy-server`
  # pod label instead and scraped on its HTTP API port, which serves the
  # Prometheus `/metrics` endpoint. Reuses the same Kubernetes service
  # discovery + credentials as `tikr_scrape_configs` above (pod IPs are
  # reachable from this host because `de-msa2` is a k3s node).
  iggy_k8s_scrape_configs = [
    {
      job_name = "iggy-server-k8s";
      scrape_interval = "5s";
      scrape_timeout = "2s";
      kubernetes_sd_configs = [
        {
          role = "pod";
          api_server = "https://127.0.0.1:6443";
          namespaces.names = ["tikr"];
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
      ];
    }
  ];
  scrapeConfigs =
    node_scrape_configs
    ++ tikr_scrape_configs
    ++ iggy_k8s_scrape_configs
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
        job_name = "postgres-greptimedb";
        static_configs = [
          {targets = ["${static_ips.de-msa2_ip}:${toString const.greptimedb_postgres_port}"];}
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
  services.victoriametrics = {
    enable = true;
    listenAddress = "0.0.0.0:${toString const.victoriametrics_port}";
    retentionPeriod = "5y";
    prometheusConfig = {
      scrape_configs = scrapeConfigs;
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
