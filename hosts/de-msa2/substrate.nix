# Agent Substrate bootstrap: the generated key material the control plane
# (env/substrate.nix) needs before any of its pods can start. Upstream's
# hack/install-ate.sh creates these with `kubectl ate admin make-*-pool`; the
# same CLI, built from the same pinned source (pkgs/agent-substrate.nix), runs
# here as a oneshot against the local k3s API. Each pool is created only if
# its Secret is missing, so re-runs are no-ops and a pool is never rotated by
# accident (rotating the pod-identity or service-dns CA invalidates every
# pod certificate in ate-system at once).
#
#   podcertificate-controller-system/service-dns-ca-pool   signs *.svc server certs
#   podcertificate-controller-system/pod-identity-ca-pool  signs per-pod client certs
#   ate-system/actor-id-ca-pool                           actor identity certs
#   ate-system/actor-id-jwt-pool                          actor identity JWTs
#
# The namespaces are pre-created for the same reason as in rustfs.nix: the
# Secrets must exist before ArgoCD syncs the app; ArgoCD adopts them.
{
  inputs,
  pkgs,
  ...
}: let
  substrate = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.agent-substrate;
in {
  systemd.services.substrate-bootstrap = {
    description = "Create the Agent Substrate CA/JWT pool Secrets if missing";
    wantedBy = ["multi-user.target"];
    after = ["k3s.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = ["KUBECONFIG=/etc/rancher/k3s/k3s.yaml"];
    };
    script = ''
      k3s=${pkgs.k3s}/bin/k3s
      ate=${substrate}/bin/kubectl-ate
      for i in $(seq 1 60); do
        "$k3s" kubectl get --raw /readyz >/dev/null 2>&1 && break
        sleep 2
      done
      for ns in ate-system podcertificate-controller-system; do
        "$k3s" kubectl create namespace "$ns" --dry-run=client -o yaml \
          | "$k3s" kubectl apply -f -
      done
      ensure_ca_pool() { # namespace name
        if "$k3s" kubectl -n "$1" get secret "$2" >/dev/null 2>&1; then
          echo "secret $1/$2 exists"
        else
          "$ate" admin make-ca-pool --ca-id=1 --name="$2" --secret-namespace="$1"
        fi
      }
      ensure_ca_pool podcertificate-controller-system service-dns-ca-pool
      ensure_ca_pool podcertificate-controller-system pod-identity-ca-pool
      ensure_ca_pool ate-system actor-id-ca-pool
      if "$k3s" kubectl -n ate-system get secret actor-id-jwt-pool >/dev/null 2>&1; then
        echo "secret ate-system/actor-id-jwt-pool exists"
      else
        "$ate" admin make-jwt-pool --key-id=1 --name=actor-id-jwt-pool --secret-namespace=ate-system
      fi
    '';
  };
}
