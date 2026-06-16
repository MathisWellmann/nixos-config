# Run Mullvad VPN in lockdown (kill-switch) mode while keeping Tailscale usable.
#
# Mullvad's lockdown mode forces ALL traffic through the WireGuard tunnel and
# drops anything that isn't — except a hardcoded list of private "LAN" ranges.
# Tailscale uses the CGNAT range 100.64.0.0/10 (+ IPv6 fd7a:115c:a1e0::/48),
# which is NOT in that list, so the kill switch kills Tailscale connectivity.
#
# Fix: stamp Mullvad's own split-tunnel firewall marks onto Tailscale traffic.
# Mullvad's killswitch (its `inet mullvad` output/input chains, priority 0,
# policy drop) accepts any packet whose conntrack mark is 0x00000f41, and routes
# packets carrying the "mole" fwmark (0x6d6f6c65) via the main table instead of
# the VPN. Per Mullvad's docs these marks are safe to leave set permanently.
#
# Two distinct flows must be excluded, or Tailscale breaks under the killswitch:
#
#   1. Peer (data-plane) traffic to/from the Tailscale CGNAT range. This egresses
#      the tailscale0 interface, which the killswitch would otherwise drop.
#
#   2. tailscaled's OWN control-plane + DERP traffic. tailscaled marks its
#      sockets with fwmark 0x80000 (mask 0xff0000) so its packets don't loop
#      back into the tunnel; Tailscale's ip-rule then routes them out the
#      *physical* interface, where the killswitch drops them — so tailscaled
#      can never reach controlplane.tailscale.com / DERP, the node logs out,
#      and every peer goes unreachable. We must stamp the killswitch's accept
#      ct mark onto this flow too (without touching its routing mark).
#
# Hook priority is load-bearing. Tailscale installs an `ip mangle OUTPUT` rule
# at priority `mangle` (-150) that copies the fwmark into the ct mark
# (`ct mark set mark & 0xff0000`) for any packet with bits set in that mask —
# which includes our mole mark (0x6d6f6c65 & 0xff0000 = 0x6f0000). If our chain
# ran at/under -150 it would set ct mark 0x00000f41 only for Tailscale to
# immediately clobber it, and the killswitch would then reject. So our output
# chain must run AFTER Tailscale's mangle rule (-150) but BEFORE the killswitch
# (0): priority -100 sits cleanly between them. (The original priority 0 tied
# the killswitch's own priority, making the order undefined and boot-dependent.)
#
# Refs:
#   https://mullvad.net/en/help/split-tunneling-with-linux-advanced
#   https://theorangeone.net/posts/tailscale-mullvad/
{pkgs, ...}: let
  # Mullvad's split-tunnel marks (do not change — the daemon matches on these).
  ctMark = "0x00000f41";
  fwMark = "0x6d6f6c65"; # "mole"

  # Tailscale's own socket fwmark for its control-plane/DERP traffic.
  tsMark = "0x00080000";
  tsMarkMask = "0x00ff0000";

  # Tailscale's address ranges.
  ts4 = "100.64.0.0/10";
  ts6 = "fd7a:115c:a1e0::/48";

  rules = pkgs.writeText "mullvad-tailscale.nft" ''
    table inet mullvad_tailscale {
      # Priority -100: after Tailscale's `ip mangle OUTPUT` (-150, which would
      # otherwise overwrite our ct mark) and before Mullvad's killswitch (0).
      chain output {
        type route hook output priority -100; policy accept;
        # (1) Peer traffic: exclude from tunnel + killswitch. The `route` hook
        # re-runs routing after the mark, so it leaves via the main table.
        ip  daddr ${ts4} ct mark set ${ctMark} meta mark set ${fwMark};
        ip6 daddr ${ts6} ct mark set ${ctMark} meta mark set ${fwMark};
        # (2) tailscaled's own egress (control plane + DERP, fwmark 0x80000):
        # let it through the killswitch via the ct mark, but leave its routing
        # mark alone so it still egresses the physical interface as intended.
        meta mark and ${tsMarkMask} == ${tsMark} ct mark set ${ctMark};
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
