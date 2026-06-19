# Rename to `nexus_infra.nix`
{inputs, ...}: let
  const = import ./constants.nix {};
in {
  imports = [
    inputs.iggy.nixosModules.default
  ];

  # TODO: bring into kubernetes cluster deployment in nexus.
  virtualisation.oci-containers.containers."dragonfly" = {
    image = "docker.dragonflydb.io/dragonflydb/dragonfly";
    ports = [
      "${toString const.dragonfly_port}:6379"
    ];
    extraOptions = ["--ulimit" "memlock=-1"];
  };
  networking.firewall.allowedTCPPorts = [
    const.dragonfly_port
  ];
}
