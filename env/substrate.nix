# Agent Substrate (https://github.com/agent-substrate/substrate): the gVisor
# sandbox / suspend-resume actor runtime that google/ax drives. Plan and
# operating notes: docs/ax_stack_todo.md (Phase 2).
#
# Layout. Upstream ships plain manifests plus kustomize overlays for kind and
# GKE and an imperative installer (hack/install-ate.sh). Here the upstream
# `manifests/ate-install/` tree is taken verbatim from the same pinned source
# the images are built from (pkgs/agent-substrate.nix), the `ko://` image
# references and the `${SUBSTRATE_VERSION*}` placeholders are substituted at
# build time, and a small kustomize overlay (below) applies the fleet
# specifics on top, the way the kind overlay does for kind:
#   - images from the Forgejo registry, pinned by digest (tag = upstream short rev)
#   - S3 snapshot storage on rustfs (de-msa2) via the
#     `ate-system/rustfs-s3-credentials` Secret (hosts/de-msa2/rustfs.nix)
#   - no telemetry collector: traces sampled off, metrics pushed rarely
#   - no egress gateway (allow-all; add atenet-egress when a Gateway is needed)
#   - bundled Postgres on a small local-path PVC
#   - the atelet DaemonSet on every node, not keyed by a version node label
#     (upstream uses that for blue/green; ArgoCD rolls it instead)
#   - one gVisor WorkerPool for ax's actors
#
# Not in git, created once by the `substrate-bootstrap` oneshot on de-msa2
# (hosts/de-msa2/substrate.nix) because they are generated key material:
# the CA/JWT pool Secrets `ate-system/{actor-id-jwt-pool,actor-id-ca-pool}`
# and `podcertificate-controller-system/{service-dns-ca-pool,pod-identity-ca-pool}`.
# Every pod here mounts a `podCertificate` projected volume signed by
# pod-certificate-controller, so nothing starts until those exist and the
# controller runs (modules/k3s_pod_certificates.nix enables the API).
{
  pkgs,
  lib,
  ...
}: let
  substrate = pkgs.callPackage ../pkgs/agent-substrate.nix {};
  inherit (substrate) tag registry;
  ips = import ../modules/static_ips.nix;

  # Upstream tree with the build-time substitutions applied, under the
  # overlay directory: kustomize refuses to load resources from outside the
  # kustomization's own directory tree.
  manifests = pkgs.runCommand "substrate-manifests-${tag}" {} ''
    mkdir -p $out/prod
    cp -r ${substrate.src}/manifests/ate-install $out/prod/upstream
    chmod -R u+w $out/prod/upstream
    # Images pinned by digest (like `ko resolve` does upstream): the tag is
    # mutable and nodes would otherwise keep whatever they cached first.
    find $out/prod/upstream -name '*.yaml' -print0 | xargs -0 sed -i -E \
      ${lib.concatMapStringsSep " \\\n      " (name: "-e 's#ko://github\\.com/agent-substrate/substrate/cmd/${name}$#${substrate.refs.${name}}#'") (lib.attrNames substrate.refs)} \
      -e 's#atelet-\$\{SUBSTRATE_VERSION_SUFFIX\}#atelet#g' \
      -e 's#"\$\{SUBSTRATE_VERSION\}"#"${tag}"#g'
    if grep -rn 'ko://' $out/prod/upstream/*.yaml; then
      echo "unresolved ko:// image reference" >&2; exit 1
    fi
    cp ${kustomization} $out/prod/kustomization.yaml
    cp ${fleet} $out/prod/fleet.yaml
  '';

  kustomization = pkgs.writeText "kustomization.yaml" ''
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - upstream/generated/ate.dev_workerpools.yaml
      - upstream/generated/ate.dev_sandboxconfigs.yaml
      - upstream/generated/ate.dev_csidriverconfigs.yaml
      - upstream/generated/role.yaml
      - upstream/sandboxconfig-validation.yaml
      - upstream/sandboxconfig-gvisor.yaml
      - upstream/pod-certificate-controller.yaml
      - upstream/postgres/postgres.yaml
      - upstream/ate-api-server.yaml
      - upstream/ate-controller.yaml
      - upstream/atelet.yaml
      - upstream/atenet-router.yaml
      - fleet.yaml
    patches:
      # atelet: every node, S3 snapshots, no GCP registry auth. `env` beats
      # `envFrom`, so the gcs default has to be overridden in place. `envFrom`
      # has no merge key, so a patch replaces the whole list: restate it.
      - target:
          kind: DaemonSet
          name: atelet
        patch: |-
          - op: remove
            path: /spec/template/spec/nodeSelector
          - op: replace
            path: /spec/template/spec/containers/0/args
            value:
              - --gcp-auth-for-image-pulls=false
              - --grpc-server-cred-bundle=/run/podidentity.podcert.ate.dev/credential-bundle.pem
              - --client-ca-certs=/run/podidentity.podcert.ate.dev/trust-bundle.pem
              - --ateapi-ca-file=/run/servicedns.podcert.ate.dev/trust-bundle.pem
              - --drain-delay=0s
              - --drain-timeout=5m
      - patch: |-
          apiVersion: apps/v1
          kind: DaemonSet
          metadata:
            name: atelet
            namespace: ate-system
          spec:
            template:
              spec:
                containers:
                  - name: atelet
                    env:
                      - name: ATE_STORAGE_BACKEND
                        value: s3
                    envFrom:
                      - configMapRef:
                          name: ate-otel-config
                      - secretRef:
                          name: rustfs-s3-credentials
      # ate-api-server: S3 snapshots; no egress gateway deployed, so drop
      # --egress-gateway-address (empty disables tunneled egress).
      - target:
          kind: Deployment
          name: ate-api-server
        patch: |-
          - op: replace
            path: /spec/template/spec/containers/0/args
            value:
              - --grpc-server-cred-bundle=/run/servicedns.podcert.ate.dev/credential-bundle.pem
              - --authentication-config=/etc/ateapi/authentication/authentication.yaml
              - --postgres-connection-string=@env
              - --postgres-schema=@env
              - --actor-id-jwt-pool=/run/actor-id-jwt-pool/pool.json
              - --actor-id-ca-pool=/run/actor-id-ca-pool/pool.json
              - --atelet-client-cred-bundle=/run/podidentity.podcert.ate.dev/credential-bundle.pem
              - --pod-identity-ca-certs=/run/podidentity.podcert.ate.dev/trust-bundle.pem
              - --drain-delay=13s
              - --drain-timeout=15s
      - patch: |-
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: ate-api-server
            namespace: ate-system
          spec:
            template:
              spec:
                containers:
                  - name: ate-api-server
                    env:
                      - name: ATE_STORAGE_BACKEND
                        value: s3
                    envFrom:
                      - configMapRef:
                          name: ate-otel-config
                      - configMapRef:
                          name: ate-api-server-envvars
                      - secretRef:
                          name: ate-api-server-secret-envvars
                      - secretRef:
                          name: rustfs-s3-credentials
      # Postgres: upstream sizes it for GKE (500Gi, 2-16 CPU). The state is
      # small metadata; snapshots live in rustfs.
      - target:
          kind: StatefulSet
          name: postgres
        patch: |-
          - op: replace
            path: /spec/volumeClaimTemplates/0/spec/resources/requests/storage
            value: 20Gi
          - op: replace
            path: /spec/template/spec/containers/0/resources
            value:
              requests:
                cpu: 250m
                memory: 512Mi
              limits:
                cpu: "4"
                memory: 2Gi
  '';

  # Fleet-specific objects that upstream creates imperatively (or per
  # environment overlay) and the WorkerPool.
  fleet = pkgs.writeText "fleet.yaml" ''
    # Every component `envFrom`s this. There is no collector yet: keep the
    # SDK's default localhost endpoint, sample traces off and push metrics
    # hourly so the failed exports stay quiet. Phase 6 may add a collector.
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ate-otel-config
      namespace: ate-system
    data:
      OTEL_TRACES_SAMPLER: always_off
      OTEL_METRIC_EXPORT_INTERVAL: "3600000"
    ---
    # ate-api-server authenticates callers with Kubernetes ServiceAccount
    # tokens (kubectl-ate, ax-controller). Issuer = this cluster's OIDC
    # issuer (`kubectl get --raw /.well-known/openid-configuration`); the
    # audience is what `kubectl ate` and ax request tokens for.
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ate-api-authentication
      namespace: ate-system
    data:
      authentication.yaml: |
        actorIdentityJWTProvider: kubernetes
        jwtProviders:
        - name: kubernetes
          issuer: https://kubernetes.default.svc.cluster.local
          audiences: [api.ate-system.svc]
          certificateAuthorityFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          discoveryTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    ---
    # Referenced by ate-api-server's envFrom (optional, but keep it explicit).
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ate-api-server-envvars
      namespace: ate-system
    data: {}
    ---
    # Postgres DSN for the bundled StatefulSet. No password: the server
    # authenticates clients by their pod certificate (pg_hba clientcert=verify-ca),
    # so this "Secret" holds nothing secret and can live in git.
    apiVersion: v1
    kind: Secret
    metadata:
      name: ate-api-server-secret-envvars
      namespace: ate-system
    type: Opaque
    stringData:
      ATE_API_POSTGRES_CONNECTION_STRING: postgresql://postgres@postgres.ate-system.svc:5432/atepg?sslmode=verify-full&sslrootcert=/run/servicedns.podcert.ate.dev/trust-bundle.pem&sslcert=/run/podidentity.podcert.ate.dev/credential-bundle.pem&sslkey=/run/podidentity.podcert.ate.dev/credential-bundle.pem
      ATE_API_POSTGRES_SCHEMA: public
    ---
    # Actor hostnames (<actor>.<atespace>.actors.resources.substrate.ate.dev)
    # resolve to the atenet ingress router for in-cluster clients. k3s
    # imports kube-system/coredns-custom `*.override` keys into the main
    # CoreDNS server block.
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns-custom
      namespace: kube-system
    data:
      substrate-actors.override: |
        rewrite stop {
          name regex (.*)\.actors\.resources\.substrate\.ate\.dev\.? atenet-router.ate-system.svc.cluster.local.
          answer auto
        }
      # atelet pulls actor images from the Forgejo registry through the
      # forgejo.k3s.lan ingress (see pkgs/agent-substrate.nix); *.k3s.lan
      # only exists in the hosts' /etc/hosts, so give pods the LAN address
      # of de-msa2, where traefik's servicelb listens too. Its own server
      # block (`.server` key): `hosts` may appear only once per block and
      # k3s's main block already has one for NodeHosts.
      substrate-registry.server: |
        forgejo.k3s.lan:53 {
          errors
          hosts {
            ${ips.de-msa2_ip} forgejo.k3s.lan
          }
        }
    ---
    # One gVisor pool for ax's task sandboxes. Per-worker limits are the
    # per-actor ceiling (workerCapacity reads limits), requests are what the
    # scheduler packs by; an actor occupies a whole worker. All three nodes
    # passed the runsc checkpoint/restore test, so no node pinning.
    apiVersion: ate.dev/v1alpha1
    kind: WorkerPool
    metadata:
      name: gvisor
      namespace: ate-system
      labels:
        workload: gvisor
      annotations:
        # The CRD ships in this same app; skip the dry run that would fail
        # before the CRD is established on the first sync.
        argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    spec:
      replicas: 3
      sandboxClass: gvisor
      workerImage: ${substrate.refs.ateom-gvisor}
      template:
        resources:
          requests:
            cpu: "1"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 4Gi
  '';
in {
  applications.substrate = {
    namespace = "ate-system";
    # Upstream ships the Namespace object itself (and a second one for the
    # pod-certificate controller).
    createNamespace = false;
    # The CRDs' schemas are too large for client-side apply.
    syncPolicy.syncOptions.serverSideApply = true;
    # ArgoCD's bundled Kubernetes schema predates the `podCertificate`
    # projected volume source (beta in 1.36); without a server-side diff the
    # comparison fails with "field not declared in schema" and the app sits
    # in Unknown/Degraded although everything is applied.
    compareOptions.serverSideDiff = true;

    kustomize.applications.substrate = {
      # nixidy writes this into the kustomization's `namespace:`, which would
      # move the podcertificate-controller-system and kube-system objects
      # into ate-system. Empty is a no-op for kustomize; every upstream
      # object carries its own namespace.
      namespace = "";
      kustomization = {
        src = manifests;
        path = "prod";
      };
      # The SandboxConfig is a CR of a CRD shipped in this same app (see the
      # WorkerPool above for the annotation).
      transformer = lib.map (
        obj:
          if obj.kind == "SandboxConfig"
          then
            lib.recursiveUpdate obj {
              metadata.annotations."argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true";
            }
          else obj
      );
    };
  };
}
