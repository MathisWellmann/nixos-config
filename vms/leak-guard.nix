# Egress allowlist for the anonymity VMs in this directory.
#
# Only the router daemon (`leakGuard.allowedUser`) may open connections that
# leave the VM. Everything else (browser, desktop, root services) reaches
# loopback only, so a proxy bypass (WebRTC, a local DNS lookup, an app that
# ignores the proxy settings) is dropped instead of leaking the real IP.
{
  config,
  lib,
  ...
}: let
  cfg = config.leakGuard;
  # Matched by number: user names cannot be resolved when the ruleset is
  # checked in the build sandbox, and a static uid cannot drift.
  uid = config.users.users.${cfg.allowedUser}.uid or null;
in {
  options.leakGuard.allowedUser = lib.mkOption {
    type = lib.types.str;
    example = "tor";
    description = "The only user that may open connections beyond loopback. It needs a static uid.";
  };

  config = {
    assertions = [
      {
        assertion = uid != null;
        message = "leakGuard.allowedUser `${cfg.allowedUser}` must exist with a static uid.";
      }
    ];

    # nscd resolves names in its own process, so a lookup by any user would
    # leave the VM as nscd's DNS query and pass the per-user rule below.
    # Without nscd, glibc resolves in-process and the query is filtered as the
    # user who made it.
    services.nscd.enable = false;
    system.nssModules = lib.mkForce [];

    # The router daemons correct their own clocks (I2P has a built-in SNTP
    # client) and timesyncd would be dropped by the firewall anyway.
    services.timesyncd.enable = false;

    networking.nftables = {
      enable = true;
      tables.leak-guard = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority filter; policy drop;
            oifname "lo" accept
            ct state established,related accept
            meta skuid ${toString uid} accept
            # dhcpcd lease renewals; the initial lease uses a raw socket that
            # bypasses this hook.
            udp sport 68 udp dport 67 accept
            # IPv6 neighbour discovery and SLAAC.
            icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert, mld2-listener-report } accept
            limit rate 10/minute log prefix "leak-guard drop: "
            counter
          }
        '';
      };
    };
  };
}
