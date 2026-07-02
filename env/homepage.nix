# Homepage (gethomepage.dev) dashboard at https://home.k3s.lan — the central
# discovery page for every `*.k3s.lan` route. It runs IN the cluster and
# auto-discovers any Ingress annotated with `gethomepage.dev/enabled: "true"`
# (see env/host_ingress.nix and env/argocd.nix), so newly exposed services
# show up automatically — no config file to keep in sync.
#
# NOTE: `home.k3s.lan` must be listed in `networking.hosts` in
# modules/base_system.nix (there is no real DNS for *.k3s.lan).
_: {
  applications.homepage = {
    namespace = "homepage";
    createNamespace = true;
    yamls = [
      # RBAC: homepage watches the k8s API for annotated Ingresses and reads
      # node/pod metrics (metrics-server ships with k3s) for its widgets.
      ''
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: homepage
          namespace: homepage
      ''
      ''
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: homepage
        rules:
          - apiGroups:
              - ""
            resources:
              - namespaces
              - pods
              - nodes
            verbs:
              - get
              - list
          - apiGroups:
              - networking.k8s.io
            resources:
              - ingresses
            verbs:
              - get
              - list
          - apiGroups:
              - traefik.io
            resources:
              - ingressroutes
            verbs:
              - get
              - list
          - apiGroups:
              - metrics.k8s.io
            resources:
              - nodes
              - pods
            verbs:
              - get
              - list
      ''
      ''
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: homepage
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: homepage
        subjects:
          - kind: ServiceAccount
            name: homepage
            namespace: homepage
      ''
      # Homepage's config files, mounted at /app/config. Service tiles come
      # from Ingress annotations (kubernetes.yaml `mode: cluster`), not from
      # services.yaml.
      ''
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: homepage
          namespace: homepage
        data:
          settings.yaml: |
            title: k3s.lan
            theme: dark
            color: slate
            hideFooter: true
            headerStyle: boxed
          kubernetes.yaml: |
            mode: cluster
          widgets.yaml: |
            - kubernetes:
                cluster:
                  show: true
                  cpu: true
                  memory: true
                  showLabel: true
                  label: k3s
                nodes:
                  show: true
                  cpu: true
                  memory: true
                  showLabel: true
            - search:
                provider: duckduckgo
                target: _blank
          services.yaml: ""
          bookmarks.yaml: ""
          docker.yaml: ""
      ''
      ''
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: homepage
          namespace: homepage
        spec:
          replicas: 1
          selector:
            matchLabels:
              app.kubernetes.io/name: homepage
          template:
            metadata:
              labels:
                app.kubernetes.io/name: homepage
            spec:
              serviceAccountName: homepage
              automountServiceAccountToken: true
              containers:
                - name: homepage
                  image: ghcr.io/gethomepage/homepage:v1.13.2
                  ports:
                    - name: http
                      containerPort: 3000
                      protocol: TCP
                  env:
                    - name: HOMEPAGE_ALLOWED_HOSTS
                      value: home.k3s.lan
                  volumeMounts:
                    - name: config
                      mountPath: /app/config
                    - name: logs
                      mountPath: /app/config/logs
              volumes:
                - name: config
                  configMap:
                    name: homepage
                - name: logs
                  emptyDir: {}
      ''
      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: homepage
          namespace: homepage
        spec:
          type: ClusterIP
          selector:
            app.kubernetes.io/name: homepage
          ports:
            - name: http
              port: 80
              targetPort: http
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: homepage
          namespace: homepage
          annotations:
            cert-manager.io/cluster-issuer: k3s-lan-ca
        spec:
          ingressClassName: traefik
          rules:
            - host: home.k3s.lan
              http:
                paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: homepage
                        port:
                          number: 80
          tls:
            - hosts:
                - home.k3s.lan
              secretName: homepage-tls
      ''
    ];
  };
}
