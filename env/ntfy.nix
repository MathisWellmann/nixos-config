# Exposes the host-local `ntfy-sh` NixOS service (see
# hosts/de-msa2/alerting.nix) off-cluster at `https://ntfy.k3s.lan` through the
# cluster's traefik ingress, so the ntfy phone/desktop app gets the same
# fleet-trusted TLS cert (`k3s-lan-ca`) as the other `*.k3s.lan` UIs.
#
# ntfy itself does NOT live in the cluster, so this is the standard
# "Ingress -> external Service" pattern: a Service with no selector + manual
# Endpoints pointing at de-msa2's tailscale IP on the ntfy HTTP port. traefik
# terminates TLS and proxies to it. ntfy's `behind-proxy = true` makes it trust
# the X-Forwarded-* headers traefik sets.
#
# No new dependency, no in-cluster ntfy pod -- ntfy stays declarative in NixOS.
{
  config,
  lib,
  ...
}: let
  # de-msa2's tailscale IP -- the same IP `*.k3s.lan` resolves to via
  # networking.hosts in modules/base_system.nix. Pods reach the host's
  # tailscale IP because they NAT through the node.
  hostIp = "100.83.142.17";
  # ntfy listen-http port (const.ntfy_port in hosts/de-msa2/constants.nix).
  ntfyPort = 9007;
in {
  applications.ntfy = {
    namespace = "ntfy";
    createNamespace = true;
    # Raw YAML: a Service with no selector (so it does NOT load-balance to any
    # pod) backed by manually-defined Endpoints at the host IP. The Ingress
    # then routes ntfy.k3s.lan -> this Service.
    yamls = [
      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: ntfy
          namespace: ntfy
        spec:
          type: ClusterIP
          ports:
            - name: http
              port: 80
              targetPort: ${toString ntfyPort}
      ''
      ''
        apiVersion: v1
        kind: Endpoints
        metadata:
          name: ntfy
          namespace: ntfy
        subsets:
          - addresses:
              - ip: ${hostIp}
            ports:
              - name: http
                port: ${toString ntfyPort}
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ntfy
          namespace: ntfy
          annotations:
            cert-manager.io/cluster-issuer: k3s-lan-ca
        spec:
          ingressClassName: traefik
          rules:
            - host: ntfy.k3s.lan
              http:
                paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: ntfy
                        port:
                          number: 80
          tls:
            - hosts:
                - ntfy.k3s.lan
              secretName: ntfy-tls
      ''
    ];
  };
}
