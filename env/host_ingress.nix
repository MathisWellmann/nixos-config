# Fronts host-local NixOS services on de-msa2 with HTTPS at `*.k3s.lan`
# through the cluster's traefik ingress + the fleet-trusted `k3s-lan-ca`
# cert (same path as `tikr.k3s.lan` etc.). The services do NOT live in the
# cluster, so each uses the standard "Ingress -> external Service" pattern:
# a Service with no selector (no pod load-balancing) + manual Endpoints
# pointing at de-msa2's tailscale IP on the service's HTTP port. traefik
# terminates TLS and proxies to the host; each service is told its real
# https base URL + to trust proxy headers (see the host config).
#
# Add a new entry to `services` below to expose another host-local service
# the same way -- nothing else needed.
{
  lib,
  ...
}: let
  # de-msa2's tailscale IP -- the same IP `*.k3s.lan` resolves to via
  # networking.hosts in modules/base_system.nix. Pods reach the host's
  # tailscale IP because they NAT through the node.
  hostIp = "100.83.142.17";

  # Each entry renders a Namespace + selector-less Service + Endpoints +
  # TLS Ingress. `name` is the app/k8s name, `host` the `*.k3s.lan` FQDN,
  # `port` the host-local HTTP port the service listens on.
  services = [
    {
      name = "ntfy";
      host = "ntfy.k3s.lan";
      port = 9007; # const.ntfy_port
    }
    {
      name = "forgejo";
      host = "forgejo.k3s.lan";
      port = 2999; # const.forgejo_port
    }
    {
      name = "grafana";
      host = "grafana.k3s.lan";
      port = 3001; # const.grafana_port
    }
  ];

  mkApp = {
    name,
    host,
    port,
  }: {
    inherit name;
    namespace = name;
    createNamespace = true;
    # Raw YAML: selector-less Service (does NOT load-balance to any pod)
    # backed by manual Endpoints at the host IP, plus the TLS Ingress.
    yamls = [
      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: ${name}
          namespace: ${name}
        spec:
          type: ClusterIP
          ports:
            - name: http
              port: 80
              targetPort: ${toString port}
      ''
      ''
        apiVersion: v1
        kind: Endpoints
        metadata:
          name: ${name}
          namespace: ${name}
        subsets:
          - addresses:
              - ip: ${hostIp}
            ports:
              - name: http
                port: ${toString port}
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ${name}
          namespace: ${name}
          annotations:
            cert-manager.io/cluster-issuer: k3s-lan-ca
        spec:
          ingressClassName: traefik
          rules:
            - host: ${host}
              http:
                paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: ${name}
                        port:
                          number: 80
          tls:
            - hosts:
                - ${host}
              secretName: ${name}-tls
      ''
    ];
  };
in {
  applications = builtins.listToAttrs (
    map (s: {
      name = s.name;
      value = mkApp s;
    })
    services
  );
}
