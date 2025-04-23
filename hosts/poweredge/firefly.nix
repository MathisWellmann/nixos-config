{...}: let
  const = import ./constants.nix;
  virtHost = "firefly";
in {
  services = {
    firefly-iii = {
      enable = true;
      enableNginx = true;
      virtualHost = virtHost;
      dataDir = "/SATA_SSD_POOL/firefly";
      settings = {
        APP_ENV = "local";
        APP_KEY_FILE = "/var/secrets/firefly-iii-app-key.txt";
        SITE_OWNER = "wellmannmathis@gmail.com";
        DB_CONNECTION = "sqlite";
        DB_HOST = "localhost";
        DB_DATABASE = "/SATA_SSD_POOL/firefly/sqlite";
        DB_USERNAME = "firefly";
        APP_URL = "0.0.0.0";
        # LOG_CHANNEL = "stack";
        # LOG_LEVEL = "info";
      };
      user = const.username;
    };
    nginx.virtualHosts.${virtHost} = {
      listen = [ {
        addr = "0.0.0.0";
        port = const.firefly_port;
      }];
    };
  };
}
