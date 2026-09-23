# Credentials for operator workstations to reach the k3s API.
#
# `meshify-admin`: ServiceAccount bound to cluster-admin, with a long-lived
# (non-expiring, legacy) token Secret that the token controller fills in.
# meshify's `~/.kube/k3s.yaml` and de-msa2's `~/.kube/config`
# (home/k3s_kubeconfig.nix) read the token from the agenix secret
# `secrets/k3s_meshify_admin_token.age`, decrypted to /run/agenix. cluster-admin because kubectl-ate/ax need
# port-forwards into ate-system/ax-system plus admin RPCs, and meshify is the
# main workstation.
#
# Rotate: delete the Secret (ArgoCD recreates it with a new token), then
# re-encrypt the token:
#   ssh de-msa2 'bash -lc "sudo k3s kubectl -n kube-system get secret meshify-admin-token -o jsonpath={.data.token}"' \
#     | base64 -d | age -a -R <(recipients) > secrets/k3s_meshify_admin_token.age
{
  applications.cluster-access = {
    namespace = "kube-system";
    yamls = [
      ''
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: meshify-admin
          namespace: kube-system
      ''
      ''
        apiVersion: v1
        kind: Secret
        metadata:
          name: meshify-admin-token
          namespace: kube-system
          annotations:
            kubernetes.io/service-account.name: meshify-admin
            # The token controller deletes token Secrets whose SA does not
            # exist yet; apply after the ServiceAccount.
            argocd.argoproj.io/sync-wave: "1"
        type: kubernetes.io/service-account-token
      ''
      ''
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: meshify-admin
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: cluster-admin
        subjects:
          - kind: ServiceAccount
            name: meshify-admin
            namespace: kube-system
      ''
    ];
  };
}
