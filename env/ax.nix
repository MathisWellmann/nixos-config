# google/ax (https://github.com/google/ax): the task API on top of Agent
# Substrate (env/substrate.nix). Plan and notes: docs/ax_stack_todo.md
# (Phase 3). Namespace `ax-system`, images from pkgs/ax (digest-pinned).
#
# Upstream `deploy/*.yaml` inlined with the fleet specifics:
#   - ax-controller drives Substrate over `api.ate-system.svc:443` with its
#     own ServiceAccount token (audience `api.ate-system.svc`, accepted by
#     the `ate-api-authentication` config) and the servicedns
#     ClusterTrustBundle as CA; actor snapshots go to the rustfs bucket via
#     AX_SNAPSHOTS_BUCKET, tasks without `spec.image` get the runner built
#     here via AX_DEFAULT_TASK_IMAGE (patched in, see pkgs/ax).
#   - ax-server: gRPC :8080 (h2c) + `/healthz`. The `ax` CLI reaches it
#     through a kubectl port-forward tunnel it manages itself (`ax ctx`), or
#     `$AX_SERVER`. The `ax.k3s.lan` Ingress exists for the homepage entry
#     and health probe; traefik speaks h2c to the backend so gRPC through
#     it works too when a client trusts the fleet CA.
#   - Redis: upstream's `redis:7-alpine`, pinned. Ephemeral (emptyDir):
#     Tasks/Workspaces/Gateways live here and are re-applied from
#     `manifests/ax/` (Phase 4) after a loss; actors themselves persist in
#     Substrate/Postgres.
# ax objects (Task, Workspace, Gateway) are not Kubernetes resources; they are
# applied with `ax apply -f` (Phase 4), not through ArgoCD.
{pkgs, ...}: let
  ax = pkgs.callPackage ../pkgs/ax {};
  inherit (ax) refs;
  ns = "ax-system";
  redisImage = "redis:7-alpine@sha256:858f009f9709ce576febc734aa78b8f6d624b82571f9ddb6bda4377c833b3499";
in {
  applications.ax = {
    namespace = ns;
    createNamespace = true;
    # Same reason as env/substrate.nix: ArgoCD's bundled schema does not know
    # the `clusterTrustBundle` projected volume source.
    compareOptions.serverSideDiff = true;
    yamls = [
      # ---------------------------------------------------------------- redis
      ''
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ax-redis
          namespace: ${ns}
          labels:
            app.kubernetes.io/name: ax-redis
            app.kubernetes.io/part-of: ax
        spec:
          replicas: 1
          selector:
            matchLabels:
              app.kubernetes.io/name: ax-redis
          template:
            metadata:
              labels:
                app.kubernetes.io/name: ax-redis
            spec:
              containers:
                - name: redis
                  image: ${redisImage}
                  ports:
                    - containerPort: 6379
                      name: redis
                  resources:
                    requests:
                      cpu: 50m
                      memory: 64Mi
                    limits:
                      cpu: "1"
                      memory: 512Mi
                  volumeMounts:
                    - name: data
                      mountPath: /data
              volumes:
                - name: data
                  emptyDir: {}
      ''
      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: ax-redis
          namespace: ${ns}
          labels:
            app.kubernetes.io/name: ax-redis
            app.kubernetes.io/part-of: ax
        spec:
          ports:
            - port: 6379
              targetPort: 6379
              name: redis
          selector:
            app.kubernetes.io/name: ax-redis
      ''
      # ------------------------------------------------------------ ax-server
      ''
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ax-server
          namespace: ${ns}
          labels:
            app.kubernetes.io/name: ax-server
            app.kubernetes.io/part-of: ax
        spec:
          replicas: 1
          selector:
            matchLabels:
              app.kubernetes.io/name: ax-server
          template:
            metadata:
              labels:
                app.kubernetes.io/name: ax-server
            spec:
              containers:
                - name: ax-server
                  image: ${refs.ax-server}
                  args:
                    - --addr=:8080
                    - --redis-addr=ax-redis.${ns}.svc.cluster.local:6379
                  ports:
                    - containerPort: 8080
                      name: http
                  resources:
                    requests:
                      cpu: 50m
                      memory: 64Mi
                    limits:
                      cpu: "1"
                      memory: 512Mi
                  readinessProbe:
                    httpGet:
                      path: /healthz
                      port: 8080
                    initialDelaySeconds: 2
                    periodSeconds: 5
                  livenessProbe:
                    httpGet:
                      path: /healthz
                      port: 8080
                    initialDelaySeconds: 5
                    periodSeconds: 10
      ''
      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: ax-server
          namespace: ${ns}
          labels:
            app.kubernetes.io/name: ax-server
            app.kubernetes.io/part-of: ax
        spec:
          ports:
            - port: 8080
              targetPort: 8080
              name: http
          selector:
            app.kubernetes.io/name: ax-server
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ax-server
          namespace: ${ns}
          annotations:
            cert-manager.io/cluster-issuer: k3s-lan-ca
            # gRPC backend without TLS: traefik must talk HTTP/2 cleartext.
            traefik.ingress.kubernetes.io/service.serversscheme: h2c
            gethomepage.dev/enabled: "true"
            gethomepage.dev/name: ax
            gethomepage.dev/group: AI
            gethomepage.dev/icon: mdi-robot-industrial
            gethomepage.dev/description: "AX agent tasks (gRPC API)"
            gethomepage.dev/siteMonitor: http://ax-server.${ns}.svc.cluster.local:8080/healthz
        spec:
          ingressClassName: traefik
          rules:
            - host: ax.k3s.lan
              http:
                paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: ax-server
                        port:
                          number: 8080
          tls:
            - hosts:
                - ax.k3s.lan
              secretName: ax-server-tls
      ''
      # -------------------------------------------------------- ax-controller
      ''
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: ax-controller
          namespace: ${ns}
      ''
      # Upstream: the controller reads a `gemini-api-secret` per atespace
      # namespace (not used here, Phase 0 decision) -- keep the RBAC as is.
      ''
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: ax-controller
        rules:
          - apiGroups: [""]
            resources: ["secrets"]
            verbs: ["get", "list", "watch"]
      ''
      ''
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: ax-controller
        subjects:
          - kind: ServiceAccount
            name: ax-controller
            namespace: ${ns}
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: ax-controller
      ''
      ''
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ax-controller
          namespace: ${ns}
          labels:
            app.kubernetes.io/name: ax-controller
            app.kubernetes.io/part-of: ax
        spec:
          replicas: 1
          selector:
            matchLabels:
              app.kubernetes.io/name: ax-controller
          template:
            metadata:
              labels:
                app.kubernetes.io/name: ax-controller
            spec:
              serviceAccountName: ax-controller
              containers:
                - name: controller
                  image: ${refs.ax-controller}
                  args:
                    - --redis-addr=ax-redis.${ns}.svc.cluster.local:6379
                    - --substrate-endpoint=api.ate-system.svc.cluster.local:443
                    - --substrate-authority=api.ate-system.svc
                    - --substrate-token-file=/var/run/secrets/ateapi/token
                    - --substrate-ca-file=/run/servicedns-ca/trust-bundle.pem
                    - --template=default-template
                    - --template-atespace=${ns}
                  env:
                    - name: ATENET_ROUTER_ADDR
                      value: atenet-router.ate-system.svc.cluster.local:80
                    # Snapshot prefix in the rustfs bucket (scheme is ignored by
                    # Substrate's S3 backend; the host is the bucket).
                    - name: AX_SNAPSHOTS_BUCKET
                      value: gs://ate-snapshots/ax/
                    # Runner image for Tasks without `spec.image` (pkgs/ax
                    # patch). Pulled by atelet through the forgejo.k3s.lan
                    # ingress, hence that host (see pkgs/agent-substrate.nix).
                    - name: AX_DEFAULT_TASK_IMAGE
                      value: ${refs.ax-task-runner}
                  resources:
                    requests:
                      cpu: 50m
                      memory: 128Mi
                    limits:
                      cpu: 500m
                      memory: 512Mi
                  securityContext:
                    readOnlyRootFilesystem: true
                    allowPrivilegeEscalation: false
                  volumeMounts:
                    - mountPath: /var/run/secrets/ateapi
                      name: ate-token
                      readOnly: true
                    - mountPath: /run/servicedns-ca
                      name: servicedns-ca
                      readOnly: true
              volumes:
                - name: ate-token
                  projected:
                    defaultMode: 420
                    sources:
                      - serviceAccountToken:
                          audience: api.ate-system.svc
                          expirationSeconds: 7200
                          path: token
                - name: servicedns-ca
                  projected:
                    defaultMode: 420
                    sources:
                      - clusterTrustBundle:
                          labelSelector:
                            matchLabels:
                              podcert.ate.dev/canarying: live
                          path: trust-bundle.pem
                          signerName: servicedns.podcert.ate.dev/identity
      ''
    ];
  };
}
