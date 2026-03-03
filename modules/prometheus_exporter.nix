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
    };
  };
}
