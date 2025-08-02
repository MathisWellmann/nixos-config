{...}: let
  const = import ./constants.nix;
  global_const = import ../../global_constants.nix;
in {
  # Nexus Database
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
