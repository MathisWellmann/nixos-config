_: let
  port = 9002;
in {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        inherit port;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    port
  ];
}
