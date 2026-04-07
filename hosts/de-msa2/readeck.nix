{
  dir,
  port ? 8080,
}: {...}: {
  virtualisation.oci-containers.containers = {
    "readeck" = {
      image = "codeberg.org/readeck/readeck:latest";
      ports = [
        "${builtins.toString port}:8000"
      ];
      volumes = [
        "${dir}:/readeck"
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [
    port
  ];
}
