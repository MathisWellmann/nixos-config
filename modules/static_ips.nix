let
  prefix = "192.168";
in {
  # Contains static IPv4 addresses for the primary NICs of each host.

  # In server rack
  poweredge_ip = "192.168.0.10";
  elitedesk_ip = "192.168.0.11";
  superserver_ip = "192.168.0.12";
  desg0_ip = "192.168.0.13";

  # In shack.
  genoa_ip = "192.168.0.20";
  meshify_ip = "192.168.0.21";

  # Infiniband in /16 subnet
  poweredge_mellanox_0 = "${prefix}.0.30";
  poweredge_mellanox_1 = "${prefix}.0.31";
  desg0_mellanox_0 = "${prefix}.0.32";
  desg0_mellanox_1 = "${prefix}.0.33";
  meshify_mellanox_0 = "${prefix}.0.34";
  meshify_mellanox_1 = "${prefix}.1.35";
  de-rosen_mellanox_0 = "${prefix}.0.34";
  de-rosen_mellanox_1 = "${prefix}.1.35";
}
