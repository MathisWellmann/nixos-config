_: let
  shared = import ../../modules/ports.nix;
in {
  # Constants regarding the `poweredge` host.
  hostname = "poweredge";
  # NOTE: `backup_host` / `backup_target_dir` were removed 2026-08-08 when
  # `elitedesk` (the restic target) was decommissioned. Re-add them together
  # with the restic job in ./configuration.nix once a new target is chosen.
  nfs_port = shared.nfs;
  photoprism_port = 3008;
  firefly_port = 3015;
  ncps_port = 3501;
  nats_port = 4222;
  iperf_port = shared.iperf;
}
