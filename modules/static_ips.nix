{
  # Contains static IPv4 addresses for the primary NICs of each host.

  # In server rack
  poweredge_ip = "192.168.0.10";
  elitedesk_ip = "192.168.0.11";
  superserver_ip = "192.168.0.12";

  # In shack.
  genoa_ip = "192.168.0.20";
  meshify_ip = "192.168.0.21";
  madcatz_ip = "192.168.0.22";

  # Infiniband in /16 subnet
  poweredge_mellanox_0 = "169.254.1.1";
  poweredge_mellanox_1 = "169.254.1.2";
  dell_r710_mellanox_0 = "169.254.1.3";
  dell_r710_mellanox_1 = "169.254.1.4";
  genoa_mellanox_0 = "169.254.1.5";
  genoa_mellanox_1 = "169.254.1.6";
  meshify_mellanox_0 = "169.254.1.7";
  meshify_mellanox_1 = "169.254.1.8";
}
