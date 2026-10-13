_: let
  global_const = import ./../global_constants.nix;
in {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        port = global_const.prometheus_exporter_ports.node;
        openFirewall = true;
        # `systemd` is not in node-exporter's default collector set; enable it so
        # the `SystemdUnitFailed` alert (see de-msa2/alerting.nix) can fire on a
        # failed unit (e.g. nfs-server, zfs autoreplication, the NUT services).
        # Emits `node_systemd_unit_state{name,state}`.
        enabledCollectors = ["systemd"];
      };
      zfs = {
        enable = true;
        port = global_const.prometheus_exporter_ports.zfs;
        openFirewall = true;
      };
      nvidia-gpu = {
        enable = true;
        port = global_const.prometheus_exporter_ports.nvidia-gpu;
        openFirewall = true;
      };
      # SMART health (NVMe wear, media errors, critical warnings) is not visible
      # through hwmon, so node-exporter cannot see a drive that is dying.
      # Autodiscovers all disks. The default `--smartctl.powermode-check=standby`
      # skips spun-down HDDs, so scrapes do not wake them up.
      smartctl = {
        enable = true;
        port = global_const.prometheus_exporter_ports.smartctl;
        openFirewall = true;
      };
    };
  };
}
