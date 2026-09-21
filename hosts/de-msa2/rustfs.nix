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
#     aws --endpoint-url http://de-msa2:3020 s3 mb s3://ate-snapshots
{
  config,
  pkgs,
  ...
}: let
  const = import ./constants.nix;
  ips = import ../../modules/static_ips.nix;
  storage_path = "/nvme_pool/rustfs";
  # Kubernetes Secret that hands the same credentials to Agent Substrate.
  k8s_namespace = "ate-system";
  k8s_secret = "rustfs-s3-credentials";
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

  # agenix -> Kubernetes bridge. There is no in-cluster secret manager; this
  # host runs the k3s control plane and holds the decrypted env file, so a
  # oneshot mirrors it into a Secret shaped for `envFrom` on Substrate's
  # atelet and ate-api-server (the AWS_* names the S3 backend reads). The
  # namespace is pre-created so the Secret can exist before ArgoCD syncs the
  # substrate app; ArgoCD adopts the existing namespace without complaint.
  # Re-runs on every boot and whenever the .age file changes; `kubectl apply`
  # makes it idempotent.
  systemd.services.rustfs-k8s-secret = {
    description = "Mirror rustfs credentials into the ${k8s_namespace}/${k8s_secret} Secret";
    wantedBy = ["multi-user.target"];
    after = ["k3s.service" "rustfs.service"];
    restartTriggers = [config.age.secrets.rustfs_env.file];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.age.secrets.rustfs_env.path;
    };
    script = ''
      k3s=${pkgs.k3s}/bin/k3s
      # Retry: the API may not be accepting requests right after k3s starts.
      for i in $(seq 1 60); do
        "$k3s" kubectl get --raw /readyz >/dev/null 2>&1 && break
        sleep 2
      done
      "$k3s" kubectl create namespace ${k8s_namespace} --dry-run=client -o yaml \
        | "$k3s" kubectl apply -f -
      "$k3s" kubectl -n ${k8s_namespace} create secret generic ${k8s_secret} \
        --from-literal=ATE_STORAGE_BACKEND=s3 \
        --from-literal=AWS_REGION=us-east-1 \
        --from-literal=AWS_ENDPOINT_URL=http://${ips.de-msa2_ip}:${toString const.rustfs_port} \
        --from-literal=AWS_S3_USE_PATH_STYLE=true \
        --from-literal=AWS_ACCESS_KEY_ID="$RUSTFS_ACCESS_KEY" \
        --from-literal=AWS_SECRET_ACCESS_KEY="$RUSTFS_SECRET_KEY" \
        --dry-run=client -o yaml \
        | "$k3s" kubectl apply -f -
    '';
  };
}
