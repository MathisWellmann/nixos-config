# rustfs (https://github.com/rustfsdev/rustfs): S3-compatible object store.
# Backs Agent Substrate's actor snapshots (`ATE_STORAGE_BACKEND=s3`, see
# docs/ax_stack_todo.md); anything else on the fleet that wants an S3 bucket
# can use it too. Single node, single disk, plain HTTP on the LAN port (the
# cluster nodes talk to it directly, the way they pull from the Forgejo
# registry); the `s3.k3s.lan` ingress in env/host_ingress.nix is for humans.
#
# One-time setup:
#   # Storage dataset. Snapshots of suspended actors are large zstd blobs
#   # that churn constantly, so keep the dataset out of the pool's
#   # hourly/daily ZFS snapshots and their replication (same as attic).
#   sudo zfs create -o com.sun:auto-snapshot=false nvme_pool/rustfs
#   # Root credentials (random 20/40-char strings, like AWS keys):
#   printf 'RUSTFS_ACCESS_KEY=%s\nRUSTFS_SECRET_KEY=%s\n' \
#     "$(head -c 400 /dev/urandom | tr -dc A-Z0-9 | head -c 20)" \
#     "$(head -c 400 /dev/urandom | tr -dc A-Za-z0-9 | head -c 40)" \
#     | (cd secrets && agenix -e rustfs_env.age)
#   # After the first `nixos-rebuild switch`, create the Substrate bucket:
#   AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
#     aws --endpoint-url http://de-msa2:9000 s3 mb s3://ate-snapshots
{config, ...}: let
  const = import ./constants.nix;
  storage_path = "/nvme_pool/rustfs";
in {
  age.secrets.rustfs_env.file = ../../secrets/rustfs_env.age;

  services.rustfs = {
    enable = true;
    environmentFile = config.age.secrets.rustfs_env.path;
    settings = {
      RUSTFS_VOLUMES = storage_path;
      RUSTFS_ADDRESS = ":${toString const.rustfs_port}";
      # The web console is a second listener with its own auth surface; the
      # bucket is only ever driven by API clients, so leave it off.
      RUSTFS_CONSOLE_ENABLE = "false";
    };
  };

  networking.firewall.allowedTCPPorts = [const.rustfs_port];
}
