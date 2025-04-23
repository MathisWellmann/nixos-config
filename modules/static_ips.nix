let
  prefix = "10.10";
in {
  # Contains static IPv4 addresses for the primary NICs of each host.

  # In server rack
  poweredge_ip = "192.168.0.10";
  elitedesk_ip = "192.168.0.11";
  superserver_ip = "192.168.0.12";

  # In shack.
  genoa_ip = "192.168.0.20";
  meshify_ip = "192.168.0.21";

  # Infiniband in /16 subnet
  poweredge_mellanox_0 = "${prefix}.0.1";
  poweredge_mellanox_1 = "${prefix}.0.2";
  dell_r710_mellanox_0 = "${prefix}.0.3";
  dell_r710_mellanox_1 = "${prefix}.0.4";
  genoa_mellanox_0 = "${prefix}.0.5";
  genoa_mellanox_1 = "${prefix}.0.6";
  meshify_mellanox_0 = "${prefix}.0.7";
  meshify_mellanox_1 = "${prefix}.1.8";
}
