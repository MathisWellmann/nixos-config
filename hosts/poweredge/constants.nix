{...}: let
  shared = import ../../modules/ports.nix;
in {
  # Constants regarding the `poweredge` host.
  hostname = "poweredge";
  backup_host = "elitedesk";
  backup_target_dir = "/mnt/backup_hdd";
  nfs_port = shared.nfs;
  photoprism_port = 3008;
  firefly_port = 3015;
  ncps_port = 3501;
  nats_port = 4222;
  iperf_port = shared.iperf;
  mongodb_port = shared.mongodb;
}
