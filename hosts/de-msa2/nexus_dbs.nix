# Rename to `nexus_infra.nix`
{inputs, ...}: let
  const = import ./constants.nix;
in {
  imports = [
    inputs.iggy.nixosModules.default
    inputs.nexus.nixosModules.default
  ];

  # Nexus Database
  virtualisation.oci-containers.containers."greptimedb" = let
    version = "v1.0.0-rc.2";
  in {
    image = "greptime/greptimedb:${version}";
    cmd = [
      "standalone"
      "start"
      "--http-addr"
      "0.0.0.0:${toString const.greptimedb_http_port}"
      "--rpc-addr"
      "0.0.0.0:${toString const.greptimedb_rpc_port}"
      "--mysql-addr"
      "0.0.0.0:${toString const.greptimedb_mysql_port}"
      "--postgres-addr"
      "0.0.0.0:${toString const.greptimedb_postgres_port}"
    ];
    ports = [
      "${toString const.greptimedb_http_port}:${toString const.greptimedb_http_port}"
      "${toString const.greptimedb_rpc_port}:${toString const.greptimedb_rpc_port}"
      "${toString const.greptimedb_mysql_port}:${toString const.greptimedb_mysql_port}"
      "${toString const.greptimedb_postgres_port}:${toString const.greptimedb_postgres_port}"
    ];
    volumes = [
      "/nvme_pool/greptimedb:/greptimedb_data"
    ];
  };
  virtualisation.oci-containers.containers."dragonfly" = {
    image = "docker.dragonflydb.io/dragonflydb/dragonfly";
    ports = [
      "${toString const.dragonfly_port}:6379"
    ];
    extraOptions = ["--ulimit" "memlock=-1"];
  };
  # services.mongodb = {
  #   enable = true;
  #   dbpath = "/nvme_pool/mongodb";
  #   user = "${global_const.username}";
  #   bind_ip = "0.0.0.0";
  # };
  # # Raise open file limits for mongodb.
  # security.pam.services.mongodb.limits = [
  #   {
  #     domain = "*";
  #     type = "soft";
  #     item = "nofile";
  #     value = "1000000";
  #   }
  # ];
  networking.firewall.allowedTCPPorts = [
    const.greptimedb_http_port
    const.greptimedb_rpc_port
    const.greptimedb_mysql_port
    const.greptimedb_postgres_port
    const.mongodb_port
    const.dragonfly_port
  ];

  services = {
    tikr-iggy = {
      enable = true;
      iggy-addr = "127.0.0.1:${toString const.iggy_tcp_port}";
      exchanges = [
        "BinanceUsdMargin"
        "BinanceCoinMargin"
        "BinanceSpot"
      ];
      data-types = [
        "Trade"
        "Quotes"
      ];
      prometheus_exporter_base_port = const.tikr_base_port;
      environment-file = "/etc/secrets/tikr-iggy";
    };
    # Check your journal for the generated password:
    # journalctl -u iggy-server | grep "Generated root user password"
    # Or set these environment variables for the systemd service
    # IGGY_ROOT_USERNAME = "iggy";
    # IGGY_ROOT_PASSWORD = "your-password-here";
    iggy-server = {
      enable = true;
      dataDir = "/nvme_pool/iggy";
      openFirewall = true;
      settings = {
        http = {
          enabled = true;
          address = "0.0.0.0:${toString const.iggy_http_port}";
          web_ui = true;
        };
        tcp = {
          enabled = true;
          address = "0.0.0.0:${toString const.iggy_tcp_port}";
        };
        quic = {
          enable = true;
          address = "0.0.0.0:${toString const.iggy_quic_port}";
        };
        websocket = {
          enable = true;
          address = "0.0.0.0:${toString const.iggy_websocket_port}";
        };
        telemetry = {
          enable = true;
        };
      };
    };
  };
}
