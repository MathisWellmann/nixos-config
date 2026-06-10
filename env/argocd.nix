# ArgoCD itself, deployed declaratively through nixidy so that ArgoCD
# manages its own installation via GitOps (replaces the manual install).
{charts, ...}: {
  applications.argocd = {
    namespace = "argocd";
    createNamespace = true;

    # The argo-cd chart ships CRDs too large for client-side apply,
    # so the Application must sync with server-side apply.
    syncPolicy.syncOptions.serverSideApply = true;

    helm.releases.argocd = {
      chart = charts.argoproj.argo-cd;
      values = {
        # Primary access path: https://argocd.k3s.lan through the built-in
        # traefik ingress controller. The hostname resolves to a node's
        # tailscale IP via `networking.hosts` in modules/base_system.nix and
        # the certificate is issued by the k3s-lan-ca ClusterIssuer
        # (see env/cert_manager.nix), so browsers on the fleet trust it.
        global.domain = "argocd.k3s.lan";
        server.ingress = {
          enabled = true;
          ingressClassName = "traefik";
          annotations."cert-manager.io/cluster-issuer" = "k3s-lan-ca";
          tls = true;
        };
        # Traefik terminates TLS; argocd-server itself speaks plain HTTP.
        configs.params."server.insecure" = "true";

        # Dex is ArgoCD's SSO connector, unused here; local admin login is enough.
        dex.enabled = false;
      };
    };
  };
}
