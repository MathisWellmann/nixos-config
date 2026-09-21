_: let
  const = import ./constants.nix;
  in {
  services.
    grafana = {
      enable = true;
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
