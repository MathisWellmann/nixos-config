{...}:
let
  const = import ./constants.nix;
  virtHost = "freshrss";
in {
  services = {
    freshrss = {
      enable = true;
      authType = "none";
      baseUrl = "0.0.0.0";
      dataDir = "/SATA_SSD_POOL/freshrss";
      virtualHost = virtHost;
    };
    nginx.virtualHosts.${virtHost} = {
      listen = [{
        addr = "0.0.0.0";
        port = const.freshrss_port;
      }];
    };
  };
}
