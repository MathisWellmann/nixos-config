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
_: let
  meshify_const = import ../hosts/meshify/constants.nix {};

  # Each entry renders a Namespace + selector-less Service + EndpointSlice +
  # TLS Ingress. `name` is the app/k8s name, `host` the `*.k3s.lan` FQDN,
  # `port` the host-local HTTP port the service listens on, `hostIp` the
  # tailscale IP of the machine running the service (defaults to de-msa2).
  # `group`/`icon`/`description` feed the `gethomepage.dev/*` annotations so
  # the service shows up on the homepage dashboard (env/homepage.nix).
  services = [
    {
      name = "ntfy";
      host = "ntfy.k3s.lan";
      port = 9007; # const.ntfy_port
      group = "Utilities";
      icon = "ntfy.svg";
      description = "Push notifications";
    }
    {
      name = "forgejo";
      host = "forgejo.k3s.lan";
      port = 2999; # const.forgejo_port
      group = "DevOps";
      icon = "forgejo.svg";
      description = "Git forge, CI & container registry";
    }
    {
      name = "grafana";
      host = "grafana.k3s.lan";
      port = 3001; # const.grafana_port
      group = "Monitoring";
      icon = "grafana.svg";
      description = "Dashboards";
    }
    {
      name = "vikunja";
      host = "vikunja.k3s.lan";
      port = 3005; # const.vikunja_port
      group = "Productivity";
      icon = "vikunja.svg";
      description = "Tasks & projects";
    }
    {
      name = "bencher";
      host = "bencher.k3s.lan";
      port = 3008; # const.bencher_ui_port
      group = "DevOps";
      icon = "mdi-speedometer";
      description = "Continuous benchmarking UI";
    }
    {
      name = "bencher-api";
      host = "bencher-api.k3s.lan";
      port = 61016; # const.bencher_api_port
      group = "DevOps";
      icon = "mdi-api";
      description = "Bencher API";
    }
    {
      name = "llama";
      host = "llama.k3s.lan";
      port = meshify_const.llama-cpp_port;
      hostIp = "100.94.190.65"; # meshify tailscale IP
      group = "AI";
      icon = "mdi-robot";
      description = "llama.cpp inference server";
    }
  ];

  mkApp = {
    name,
    host,
    port,
    hostIp ? "100.83.142.17",
    group ? "Services",
    icon ? "mdi-web",
    description ? name,
  }: {
    inherit name;
    namespace = name;
    createNamespace = true;
    # Raw YAML: selector-less Service (does NOT load-balance to any pod)
    # backed by a manual EndpointSlice at the host IP, plus the TLS Ingress.
    # NOTE: must be an EndpointSlice (discovery.k8s.io/v1), not the legacy
    # `v1 Endpoints` -- the latter is deprecated since k8s 1.33 and is no
    # longer reconciled/applied on this cluster (k3s 1.35), which left the
    # Services with zero backends and traefik returning 503.
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
        apiVersion: discovery.k8s.io/v1
        kind: EndpointSlice
        metadata:
          name: ${name}
          namespace: ${name}
          labels:
            kubernetes.io/service-name: ${name}
        addressType: IPv4
        endpoints:
          - addresses:
              - ${hostIp}
            conditions:
              ready: true
        ports:
          - name: http
            port: ${toString port}
            protocol: TCP
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ${name}
          namespace: ${name}
          annotations:
            cert-manager.io/cluster-issuer: k3s-lan-ca
            gethomepage.dev/enabled: "true"
            gethomepage.dev/name: ${name}
            gethomepage.dev/group: ${group}
            gethomepage.dev/icon: ${icon}
            gethomepage.dev/description: ${description}
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
      inherit (s) name;
      value = mkApp s;
    })
    services
  );
}
