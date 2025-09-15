{...}: let
  const = import ./constants.nix;
  static_ips = import ./static_ips.nix;
in {
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    port = const.adguardhome_port;
    settings = {
      http = {
        address = "${static_ips.elitedesk_ip}:${const.adguardhome_port}";
      };
      dns = {
        upstream_dns = [
          "9.9.9.9#dns.quand9.net"
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
      };
      filters =
        map (url: {
          enabled = true;
          inherit url;
        }) [
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_0.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt" # The Big List of Hacked Malware Web Sites
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt" # malicious url blocklist
        ];
    };
  };
  networking.firewall.allowedUDPPorts = [
    53 # Adguard DNS
  ];
}
