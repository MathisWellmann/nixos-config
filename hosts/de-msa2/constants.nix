{
  gitea_state_dir = "/nvme_pool/gitea";

  nfs_port = 2049;
  gitea_port = 3000;
  grafana_port = 3001;
  freshrss_port = 3002;
  uptime_kuma_port = 3003;
  bitmagnet_port = 3004;
  vikunja_port = 3005;
  searx_port = 3006;
  home-assistant_port = 3006;
  greptimedb_http_port = 4000;
  greptimedb_rpc_port = 4001;
  greptimedb_mysql_port = 4002;
  greptimedb_postgres_port = 4003;
  iperf_port = 5201;
  minidlna_port = 8200;
  prometheus_port = 9001;
  # prometheus_exporter_port = 9002; # Defined in global_const
  victoriametrics_port = 9003;
  mongodb_port = 27017;
  dragonfly_port = 27018;
  prometheus_exporter_nut_port = 9199;
}
