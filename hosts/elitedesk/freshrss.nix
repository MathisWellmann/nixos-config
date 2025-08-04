{...}: let
  const = import ./constants.nix;
  virtHost = "freshrss";
in {
  services = {
    freshrss = {
      enable = true;
      authType = "none";
      baseUrl = "0.0.0.0";
      dataDir = "/var/lib/freshrss";
      virtualHost = virtHost;
    };
    nginx.virtualHosts.${virtHost} = {
      listen = [
        {
          addr = "0.0.0.0";
          port = const.freshrss_port;
        }
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [
    const.freshrss_port
  ];
}
