let
  prefix = "10.0.1.";
in {
  # Contains static IPv4 addresses for the primary NICs of each host.

  # In server rack
  poweredge_ip = "192.168.0.10";
  elitedesk_ip = "192.168.0.11";
  superserver_ip = "192.168.0.12";
  desg0_ip = "192.168.0.13";

  # In shack.
  de-rosen_ip = "192.168.0.20";
  meshify_ip = "192.168.0.21";
  meshify_ip_10Gbit_0 = "192.168.0.22";

  poweredge_mellanox_0 = "${prefix}1";
  poweredge_mellanox_1 = "${prefix}2";
  desg0_mellanox_0 = "${prefix}3";
  desg0_mellanox_1 = "${prefix}4";
  meshify_mellanox_0 = "${prefix}5";
  meshify_mellanox_1 = "${prefix}6";
  de-rosen_mellanox_0 = "${prefix}7";
  de-rosen_mellanox_1 = "${prefix}8";
}
