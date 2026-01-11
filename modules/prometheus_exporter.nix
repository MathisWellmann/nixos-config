_: let
  global_const = import ./../global_constants.nix;
in {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        port = global_const.prometheus_exporter_port;
        openFirewall = true;
      };
      zfs = {
        enable = true;
        port = 9134;
      };
    };
  };
}
