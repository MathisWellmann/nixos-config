_: let
  port = 9002;
in {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        inherit port;
        openFirewall = true;
      };
      zfs = {
        enable = true;
        port = 9134;
      };
    };
  };
}
