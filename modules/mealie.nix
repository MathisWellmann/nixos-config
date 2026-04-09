{port ? 3005}: {
  # Data lives in `/var/lib/mealie`
  services.mealie = {
    enable = true;
    inherit port;
  };
  networking.firewall.allowedTCPPorts = [port];
}
