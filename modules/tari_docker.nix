{...}: let
  port = 18142;
in {
  virtualisation.oci-containers.containers."minotari_node" = {
    image = "quay.io/tarilabs/minotari_node:latest-nextnet";
    ports = [
      "${builtins.toString port}:18142"
    ];
    volumes = [
      "/var/minotari:/root/.tari"
    ];
  };
}
