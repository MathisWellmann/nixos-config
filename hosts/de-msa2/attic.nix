# attic (https://github.com/zhaofengli/attic): the fleet's nix binary cache.
# Every host substitutes from it (modules/base_system.nix); the
# cache builder on desg0 (modules/nixos_cache_builder.nix) pushes freshly
# built system closures into it. Public cache: pulls need no token, only the
# per-cache signing key, which attic generates server-side.
#
# Exposed off-cluster at https://attic.k3s.lan through the k3s traefik
# ingress (see env/host_ingress.nix); fleet-trusted `k3s-lan-ca` cert. The
# firewall port stays open as a plain-HTTP fallback and as the direct path
# for bulk pushes, which bypass the proxy.
#
# One-time setup:
#   # Storage dataset. The cache is fully regenerable and churns on GC, so
#   # keep it out of the pool's hourly/daily snapshots and their replication.
#   sudo zfs create -o com.sun:auto-snapshot=false nvme_pool/attic
#   # JWT signing secret (the only secret the server needs):
#   printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=%s\n' \
#     "$(openssl genrsa -traditional 4096 | base64 -w0)" \
#     | (cd secrets && agenix -e attic-server-env.age)
#   # After the first `nixos-rebuild switch`: an admin token, the cache and
#   # its signing key. `attic cache info` prints the public key that goes
#   # into modules/base_system.nix and flake.nix.
#   sudo atticd-atticadm make-token --sub admin --validity 10y \
#     --pull '*' --push '*' --delete '*' --create-cache '*' \
#     --configure-cache '*' --configure-cache-retention '*' --destroy-cache '*'
#   attic login de-msa2 https://attic.k3s.lan <token>
#   attic cache create nixos --public
#   attic cache info nixos
{
  config,
  pkgs,
  ...
}: let
  const = import ./constants.nix {};
  storage_path = "/nvme_pool/attic";
in {
  age.secrets.attic-server-env.file = ../../secrets/attic-server-env.age;

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.attic-server-env.path;
    settings = {
      listen = "[::]:${toString const.attic_port}";
      # Canonical endpoint handed to clients in cache-config responses; must
      # end with a slash.
      api-endpoint = "https://attic.k3s.lan/";
      # attic recommends postgres over sqlite for anything beyond toy use;
      # sqlite locks up under the parallel uploads of a `attic push`.
      # Peer auth over the unix socket, so the OS user must be `atticd`. The
      # user is spelled out because the sandbox (PrivateUsers) hides the
      # process identity from sqlx, which then falls back to `anonymous`.
      database.url = "postgresql:///atticd?host=/run/postgresql&user=atticd";
      storage = {
        type = "local";
        path = storage_path;
      };
      garbage-collection = {
        interval = "12 hours";
        # Objects neither created nor accessed within this period are
        # collected; whatever the hosts keep pulling stays.
        default-retention-period = "3 months";
      };
    };
  };

  # The module runs atticd with `DynamicUser`; a static user of the same
  # name takes precedence (systemd.exec(5)), giving the storage directory
  # and the postgres peer authentication a stable identity.
  users = {
    users.atticd = {
      isSystemUser = true;
      group = "atticd";
    };
    groups.atticd = {};
  };
  systemd.tmpfiles.rules = [
    "d ${storage_path} 0750 atticd atticd -"
  ];

  services.postgresql = {
    enable = true;
    ensureDatabases = ["atticd"];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [const.attic_port];

  # `attic` CLI for cache administration from this host.
  environment.systemPackages = [pkgs.attic-client];
}
