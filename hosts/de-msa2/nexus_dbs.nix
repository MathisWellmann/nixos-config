{...}: let
  const = import ./constants.nix;
  global_const = import ../../global_constants.nix;
in {
  # Nexus Database
  virtualisation.oci-containers.containers."greptimedb" = let
    version = "v0.15.1";
  in {
    image = "greptime/greptimedb:${version}";
    cmd = [
      "standalone"
      "start"
      "--http-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_http_port}"
      "--rpc-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_rpc_port}"
      "--mysql-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_mysql_port}"
      "--postgres-addr"
      "0.0.0.0:${builtins.toString const.greptimedb_postgres_port}"
    ];
    ports = [
      "${builtins.toString const.greptimedb_http_port}:${builtins.toString const.greptimedb_http_port}"
      "${builtins.toString const.greptimedb_rpc_port}:${builtins.toString const.greptimedb_rpc_port}"
      "${builtins.toString const.greptimedb_mysql_port}:${builtins.toString const.greptimedb_mysql_port}"
      "${builtins.toString const.greptimedb_postgres_port}:${builtins.toString const.greptimedb_postgres_port}"
    ];
    volumes = [
      "/nvme_pool/greptimedb:/greptimedb_data"
    ];
  };
  virtualisation.oci-containers.containers."dragonfly" = {
    image = "docker.dragonflydb.io/dragonflydb/dragonfly";
    ports = [
      "${builtins.toString const.dragonfly_port}:6379"
    ];
    extraOptions = ["--ulimit" "memlock=-1"];
  };
  services.mongodb = {
    enable = true;
    dbpath = "/nvme_pool/mongodb";
    user = "${global_const.username}";
    bind_ip = "0.0.0.0";
  };
  # Raise open file limits for mongodb.
  security.pam.services.mongodb.limits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1000000";
    }
  ];
}
