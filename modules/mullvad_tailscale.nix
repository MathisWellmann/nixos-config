# Run Mullvad VPN in lockdown (kill-switch) mode while keeping Tailscale usable.
#
# Mullvad's lockdown mode forces ALL traffic through the WireGuard tunnel and
# drops anything that isn't — except a hardcoded list of private "LAN" ranges.
# Tailscale uses the CGNAT range 100.64.0.0/10 (+ IPv6 fd7a:115c:a1e0::/48),
# which is NOT in that list, so the kill switch kills Tailscale connectivity.
#
# Fix: stamp Mullvad's own split-tunnel firewall marks onto traffic to/from the
# Tailscale ranges. Mullvad routes packets carrying the "mole" mark (0x6d6f6c65)
# via the main routing table instead of the VPN, and uses the conntrack mark
# (0x00000f41) to keep return packets excluded too. Per Mullvad's docs these
# marks are safe to leave set permanently and let the excluded IPs through even
# when the tunnel is in its blocked/lockdown state.
#
# Refs:
#   https://mullvad.net/en/help/split-tunneling-with-linux-advanced
#   https://theorangeone.net/posts/tailscale-mullvad/
{pkgs, ...}: let
  # Mullvad's split-tunnel marks (do not change — the daemon matches on these).
  ctMark = "0x00000f41";
  fwMark = "0x6d6f6c65"; # "mole"

  # Tailscale's address ranges.
  ts4 = "100.64.0.0/10";
  ts6 = "fd7a:115c:a1e0::/48";

  rules = pkgs.writeText "mullvad-tailscale.nft" ''
    table inet mullvad_tailscale {
      # Mark locally-generated packets headed for Tailscale peers. The `route`
      # hook re-runs the routing decision after the mark is applied, so they
      # leave via the main table instead of the Mullvad tunnel.
      chain output {
        type route hook output priority 0; policy accept;
        ip  daddr ${ts4} ct mark set ${ctMark} meta mark set ${fwMark};
        ip6 daddr ${ts6} ct mark set ${ctMark} meta mark set ${fwMark};
      }

      # Mark inbound Tailscale traffic so replies stay excluded too.
      chain input {
        type filter hook input priority -100; policy accept;
        ip  saddr ${ts4} ct mark set ${ctMark} meta mark set ${fwMark};
        ip6 saddr ${ts6} ct mark set ${ctMark} meta mark set ${fwMark};
      }
    }
  '';
in {
  # Mullvad needs systemd-resolved for DNS.
  services.mullvad-vpn.enable = true;
  services.resolved.enable = true;
  # services.tailscale.enable is already set in modules/base_system.nix.

  # `nft` on PATH so `sudo nft list table inet mullvad_tailscale` works.
  environment.systemPackages = [pkgs.nftables];

  # Tailscale return traffic carries marks/uses a separate interface; strict
  # reverse-path filtering can drop it. "loose" is what Tailscale recommends.
  networking.firewall.checkReversePath = "loose";

  # DNS: Mullvad and Tailscale both try to manage /etc/resolv.conf in "direct"
  # mode, and Mullvad's lockdown wins — it points resolv.conf straight at its own
  # resolver (10.64.0.1), so Tailscale's MagicDNS never registers and names like
  # `de-msa2` stop resolving (routing to the IP still works via the marks above).
  # Rather than fight that race declaratively, pin the Tailscale hosts we reach
  # by name to their stable Tailscale IPs. systemd-resolved answers from
  # /etc/hosts, so this works regardless of who owns resolv.conf, and the nft
  # marks make these IPs reachable through the kill switch.
  # Add more peers here as needed (see `tailscale status` for their IPs).
  networking.hosts = {
    "100.83.142.17" = ["de-msa2"]; # NFS exports + k3s ingress (*.k3s.lan)
    "100.75.100.6" = ["de-n5"];
    "100.74.91.37" = ["desg0"];
    "100.85.196.111" = ["elitedesk"];
    "100.64.102.10" = ["poweredge"];
    "100.105.178.16" = ["razerblade"];
    "100.89.173.74" = ["superserver"];
  };

  # Load the exclusion table at boot. It lives in its own nftables table,
  # independent of the NixOS firewall and of Mullvad's own ruleset, so it
  # coexists with whichever firewall backend is in use.
  systemd.services.mullvad-tailscale-excludes = {
    description = "Exclude Tailscale (CGNAT) traffic from the Mullvad tunnel/killswitch";
    wantedBy = ["multi-user.target"];
    after = ["network-pre.target" "mullvad-daemon.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.nftables}/bin/nft -f ${rules}";
      ExecStop = "${pkgs.nftables}/bin/nft delete table inet mullvad_tailscale";
    };
  };
}
