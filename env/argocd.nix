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
        # Expose the web UI on fixed NodePorts on every cluster node.
        # From inside the tailnet: https://<any-node>:30443
        # (self-signed cert, login user is `admin`, initial password lives in
        # the `argocd-initial-admin-secret` secret).
        server.service = {
          type = "NodePort";
          nodePortHttp = 30080;
          nodePortHttps = 30443;
        };
        # Dex is ArgoCD's SSO connector, unused here; local admin login is enough.
        dex.enabled = false;
      };
    };
  };
}
