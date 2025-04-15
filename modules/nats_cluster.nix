{...}:
let
  nats_port = 4222;
  nats_cluster_port = 4223;
  # static_ips = import ../../modules/static_ips.nix;
  hostname = builtins.getEnv "HOSTNAME";
in {
  services.nats = {
    enable = true;
    jetstream = true;
    port = nats_port;
    serverName = "nats-${hostname}";
    settings = {
      jetstream = {
        max_mem = "1G";
        max_file = "10G";
      };
      cluster = {
        name = "nats-cluster";
        host = "0.0.0.0";
        port = nats_cluster_port;
        routes = [
          # Its not possible to use `static_ips.nix` here unless using impore evaluation mode. annoying
          "nats://192.168.0.10:${toString nats_cluster_port}"
          "nats://192.168.0.12:${toString nats_cluster_port}"
          "nats://192.168.0.20:${toString nats_cluster_port}"
          "nats://192.168.0.21:${toString nats_cluster_port}"
        ];
      };
    };
  };

}
