{...}: {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        port = 9002;
        enabledCollectors = ["systemd" "zfs"];
      };
    };
  };
}
