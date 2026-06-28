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

        # Override the chart's default `resource.exclusions`: the default list
        # excludes BOTH `Endpoints` and `discovery.k8s.io/EndpointSlice`, which
        # made ArgoCD silently refuse to manage the manually-defined
        # EndpointSlices in env/host_ingress.nix ("Resource ... EndpointSlice
        # is excluded in the settings") -- leaving the host-local Services
        # (forgejo/grafana/ntfy/vikunja) with zero backends -> traefik 503.
        # We keep every other default exclusion but drop EndpointSlice so our
        # host-ingress slices sync. (Legacy `Endpoints` stays excluded.)
        configs.cm."resource.exclusions" = ''
          ### Network resources created by the Kubernetes control plane and excluded to reduce the number of watched events and UI clutter
          - apiGroups:
            - ${"''"}
            kinds:
            - Endpoints
          ### Internal Kubernetes resources excluded reduce the number of watched events
          - apiGroups:
            - coordination.k8s.io
            kinds:
            - Lease
          ### Internal Kubernetes Authz/Authn resources excluded reduce the number of watched events
          - apiGroups:
            - authentication.k8s.io
            - authorization.k8s.io
            kinds:
            - SelfSubjectReview
            - TokenReview
            - LocalSubjectAccessReview
            - SelfSubjectAccessReview
            - SelfSubjectRulesReview
            - SubjectAccessReview
          ### Intermediate Certificate Request excluded reduce the number of watched events
          - apiGroups:
            - certificates.k8s.io
            kinds:
            - CertificateSigningRequest
          - apiGroups:
            - cert-manager.io
            kinds:
            - CertificateRequest
          ### Cilium internal resources excluded reduce the number of watched events and UI Clutter
          - apiGroups:
            - cilium.io
            kinds:
            - CiliumIdentity
            - CiliumEndpoint
            - CiliumEndpointSlice
          ### Kyverno intermediate and reporting resources excluded reduce the number of watched events and improve performance
          - apiGroups:
            - kyverno.io
            - reports.kyverno.io
            - wgpolicyk8s.io
            kinds:
            - PolicyReport
            - ClusterPolicyReport
            - EphemeralReport
            - ClusterEphemeralReport
            - AdmissionReport
            - ClusterAdmissionReport
            - BackgroundScanReport
            - ClusterBackgroundScanReport
            - UpdateRequest
        '';

        # Dex is ArgoCD's SSO connector, unused here; local admin login is enough.
        dex.enabled = false;
      };
    };
  };
}
