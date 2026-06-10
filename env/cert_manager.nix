# cert-manager issues TLS certificates for cluster services.
#
# A self-signed root CA ("k3s-lan-ca") is generated *in-cluster* — its private
# key only ever lives in the `k3s-lan-ca` secret and never touches this repo.
# The public CA certificate is exported to modules/k3s-lan-ca.crt and trusted
# fleet-wide via `security.pki.certificateFiles` in modules/base_system.nix:
#
#   kubectl -n cert-manager get secret k3s-lan-ca \
#     -o jsonpath='{.data.tls\.crt}' | base64 -d > modules/k3s-lan-ca.crt
#
# Services get a browser-trusted cert by annotating their Ingress with
# `cert-manager.io/cluster-issuer: k3s-lan-ca`.
{charts, ...}: {
  applications.cert-manager = {
    namespace = "cert-manager";
    createNamespace = true;

    # The CRDs and admission webhook need to come up before the CA resources
    # below can be admitted, so the first sync attempts are expected to fail.
    syncPolicy = {
      syncOptions.serverSideApply = true;
      retry = {
        limit = 10;
        backoff = {
          duration = "10s";
          factor = 2;
          maxDuration = "2m";
        };
      };
    };

    helm.releases.cert-manager = {
      chart = charts.jetstack.cert-manager;
      values.crds.enabled = true;
    };

    yamls = [
      ''
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: selfsigned
        spec:
          selfSigned: {}
      ''
      ''
        apiVersion: cert-manager.io/v1
        kind: Certificate
        metadata:
          name: k3s-lan-ca
          namespace: cert-manager
        spec:
          isCA: true
          commonName: k3s-lan-ca
          secretName: k3s-lan-ca
          duration: 87600h # 10 years
          privateKey:
            algorithm: ECDSA
            size: 256
          issuerRef:
            name: selfsigned
            kind: ClusterIssuer
            group: cert-manager.io
      ''
      ''
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: k3s-lan-ca
        spec:
          ca:
            secretName: k3s-lan-ca
      ''
    ];
  };
}
