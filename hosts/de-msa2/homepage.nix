_: let
  const = import ./constants.nix;
in {
  networking.firewall.allowedTCPPorts = [
    const.homepage_port
  ];
  services.homepage-dashboard = {
    enable = true;
    listenPort = const.homepage_port;
    openFirewall = true;
    allowedHosts = "localhost:${toString const.homepage_port},de-msa2:${toString const.homepage_port}";
    settings = {
      title = "de-msa2 Dashboard";
      logo = "/homepage/logo.png";
      hideFooter = true;
      theme = "dark";
      layout = {
        columns = 4;
        rows = 6;
      };
    };
    bookmarks = [
      {
        DevOps = [
          {
            Forgejo = [
              {
                href = "http://localhost:${toString const.forgejo_port}";
                icon = "fa-brands:fa-code-branch";
              }
            ];
          }
        ];
      }
      {
        Monitoring = [
          {
            Grafana = [
              {
                href = "http://localhost:${toString const.grafana_port}";
                icon = "fa-solid:fa-chart-line";
              }
            ];
          }
          {
            "Uptime Kuma" = [
              {
                href = "http://localhost:${toString const.uptime_kuma_port}";
                icon = "fa-solid:fa-heart-pulse";
              }
            ];
          }
        ];
      }
      {
        Productivity = [
          {
            Vikunja = [
              {
                href = "http://localhost:${toString const.vikunja_port}";
                icon = "fa-solid:fa-list-check";
              }
            ];
          }
          {
            HabitTrove = [
              {
                href = "http://localhost:${toString const.habit_trove_port}";
                icon = "fa-solid:fa-heart-circle-plus";
              }
            ];
          }
        ];
      }
      {
        Utilities = [
          {
            SearXNG = [
              {
                href = "http://localhost:${toString const.searx_port}";
                icon = "fa-solid:fa-magnifying-glass";
              }
            ];
          }
          {
            Bencher = [
              {
                href = "http://localhost:${toString const.bencher_ui_port}";
                icon = "fa-solid:fa-trophy";
              }
            ];
          }
        ];
      }
    ];
    services = [
      {
        Monitoring = [
          {
            VictoriaMetrics = [
              {
                href = "http://localhost:${toString const.victoriametrics_port}";
                icon = "fa-solid:fa-server";
                description = "Time Series Database";
              }
            ];
          }
        ];
      }
      {
        Databases = [
          {
            Dragonfly = [
              {
                href = "http://localhost:${toString const.dragonfly_port}";
                icon = "fa-solid:fa-database";
                description = "In-memory Datastore";
              }
            ];
          }
          {
            GreptimeDB = [
              {
                href = "http://localhost:${toString const.greptimedb_http_port}";
                icon = "fa-solid:fa-database";
                description = "Time Series DB";
              }
            ];
          }
        ];
      }
    ];
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
  };
}
