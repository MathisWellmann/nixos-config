# Enable the Kubernetes "Pod Certificates" feature (KEP-4317) on a k3s server.
#
# Agent Substrate (docs/ax_stack_todo.md) issues per-pod mTLS identities with
# its `pod-certificate-controller`, which signs `PodCertificateRequest`s and
# publishes `ClusterTrustBundle`s. Both live in `certificates.k8s.io/v1beta1`.
# On Kubernetes 1.36 the feature is beta but OFF by default (it goes GA and
# locked-on in 1.37), so the beta API group must be served explicitly and the
# feature gates flipped on both the API server and the kubelet, which is the
# component that files the requests and mounts the `podCertificate` and
# `clusterTrustBundle` projected volume sources Substrate's manifests use.
#
# Gate names verified against k8s release-1.36 `pkg/features/kube_features.go`:
# PodCertificateRequest (beta 1.35, also gates the projected volume),
# ClusterTrustBundle + ClusterTrustBundleProjection (beta 1.33). An unknown
# gate name makes the kubelet refuse to start, so do not add speculative ones.
#
# Imported by every k3s server module (k3s_init.nix, k3s_server_follow.nix);
# all servers must agree or requests get rejected depending on which API
# server replica answers. Remove once k3s ships Kubernetes >= 1.37.
_: {
  services.k3s.extraFlags = let
    gates = "PodCertificateRequest=true,ClusterTrustBundle=true,ClusterTrustBundleProjection=true";
  in [
    "--kube-apiserver-arg=feature-gates=${gates}"
    "--kube-apiserver-arg=runtime-config=certificates.k8s.io/v1beta1=true"
    "--kubelet-arg=feature-gates=${gates}"
  ];
}
