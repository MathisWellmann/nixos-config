{...}: let
  port = 9002;
in {
  ### Monitoring ###
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        port = port;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    port
  ];
}
