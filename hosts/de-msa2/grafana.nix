{pkgs, ...}: let
  const = import ./constants.nix;
in {
  services.
    grafana = {
    enable = true;
    # Nix-managed plugins, so the VictoriaLogs datasource below does not depend
    # on a plugin someone once installed by hand. Setting this replaces the
    # writable plugin dir, so the drilldown apps Grafana used to preinstall
    # there must be listed too, or Explore loses them.
    declarativePlugins = with pkgs.grafanaPlugins; [
      victoriametrics-logs-datasource
      grafana-exploretraces-app
      grafana-lokiexplore-app
      grafana-metricsdrilldown-app
      grafana-pyroscope-app
    ];
    settings = {
      security.secret_key = "/etc/secrets/grafana";
      server = {
        # Exposed off-cluster at https://grafana.k3s.lan through the k3s
        # traefik ingress (see env/host_ingress.nix); fleet-trusted
        # `k3s-lan-ca` cert. `root_url` makes the UI emit correct links.
        http_addr = "0.0.0.0";
        http_port = const.grafana_port;
        root_url = "https://grafana.k3s.lan/";
        serve_from_sub_path = false;
      };
    };
    # Declarative (repo-tracked) provisioning: the VictoriaMetrics datasource
    # and the dashboards under `./dashboards`. Provisioned objects are managed
    # by these files (matched by `uid`), so they are recreated on every
    # `nixos-rebuild switch` and cannot be permanently edited in the UI --
    # edits must land in the repo. Coexists with any datasources/dashboards
    # added manually through the UI (those have different uids).
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            # Referenced by dashboards via the `${datasource}` variable, and
            # by this fixed `uid` so dashboard JSON is portable across
            # rebuilds. Same VictoriaMetrics endpoint the vmalert/alerting
            # stack uses (hosts/de-msa2/alerting.nix). VM speaks the
            # Prometheus query API, so `type = "prometheus"`.
            name = "VictoriaMetrics";
            uid = "victoriametrics";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString const.victoriametrics_port}";
            isDefault = true;
            jsonData.timeInterval = "5s";
          }
          {
            # Cluster pod logs, shipped by the collector DaemonSet in the nexus
            # repo (`env/logging.nix`) into `services.victorialogs` (prometheus.nix). Fixed `uid` for
            # the same dashboard-portability reason as above.
            name = "VictoriaLogs";
            uid = "victorialogs";
            type = "victoriametrics-logs-datasource";
            access = "proxy";
            url = "http://127.0.0.1:${toString const.victorialogs_port}";
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "repo-dashboards";
            type = "file";
            # Keep the sidebar organized; matches the "tikr" tag on the CH
            # dashboard. Grafana creates the folder on first load.
            folder = "tikr";
            # `foldersFromFilesStructure` would mirror subdirs as folders;
            # a single flat folder is enough here.
            options.path = ./dashboards;
            # Allow the provider to update dashboards in place on rebuild.
            allowUiUpdates = false;
            disableDeletion = false;
          }
        ];
      };
    };
  };
}
