{
  config,
  lib,
  ...
}: let
  const = import ./constants.nix;
  static_ips = import ../../modules/static_ips.nix;
  node_scrape_configs = map (host: {
    job_name = "${host}-node";
    static_configs = [
      {
        targets = ["${host}:${toString config.services.prometheus.exporters.node.port}"];
      }
    ];
  }) ["127.0.0.1" "meshify" "superserver" "poweredge" "razerblade" "desg0" "de-n5" "elitedesk" "tensorbook"];
  n_tikr_services =
    builtins.length config.services.tikr.exchanges
    + builtins.length config.services.tikr.data-types;
  tikr_max_port = const.tikr_base_port + n_tikr_services;
  tikr_ports = lib.range const.tikr_base_port tikr_max_port;
  tikr_scrape_configs =
    map (local_tikr_port: {
      job_name = "tikr-${toString local_tikr_port}";
      scrape_interval = "5s";
      scrape_timeout = "2s";
      static_configs = [
        {
          targets = ["127.0.0.1:${toString local_tikr_port}"];
        }
      ];
    })
    tikr_ports;
  scrapeConfigs =
    node_scrape_configs
    ++ tikr_scrape_configs
    ++ [
      {
        job_name = "zfs";
        static_configs = [
          {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}"];}
        ];
      }
      # {
      #   job_name = "restic";
      #   static_configs = [
      #     {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.restic.port}"];}
      #   ];
      # }
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
  # TODO: slowly transition to this as storage over prometheus.
  services.victoriametrics = {
    enable = true;
    listenAddress = "0.0.0.0:${toString const.victoriametrics_port}";
    retentionPeriod = "5y";
    prometheusConfig = {
      scrape_configs = scrapeConfigs;
    };
  };
  services.prometheus = {
    enable = true;
    listenAddress = "0.0.0.0";
    retentionTime = "5y";
    port = const.prometheus_port;
    # TODO: clean up exporter ports.
    exporters = {
      mongodb = {
        enable = true;
        collectAll = true;
        uri = "mongodb://localhost:${toString const.mongodb_port}";
        port = 9216;
      };
      # postgres = {
      #   enable = true;
      #   dataSourceName = "username=postgres dbname=public host=localhost port=4003 sslmode=disable";
      #   port = 9215;
      # };
      # restic = {
      #   enable = true;
      #   port = 9753;
      #   repository = config.services.restic.backups.zfs_sata_ssd_pool.repository;
      #   passwordFile = "/etc/nixos/secrets/restic/password";
      # };
    };
    inherit scrapeConfigs;
  };
}
