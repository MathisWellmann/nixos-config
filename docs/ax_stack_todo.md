# AX + Agent Substrate on the k3s fleet: TODO

Goal: run sandboxed agent tasks on the k3s cluster (de-msa2, desg0, de-n5)
with `google/ax` as the task API and `agent-substrate/substrate` as the
gVisor runtime underneath.

Upstream:
- https://github.com/google/ax
- https://github.com/agent-substrate/substrate

Both projects are pre-alpha. Pin every image by digest and record the
upstream commit each layer was built from in this file.

Legend: `[ ]` open, `[x]` done, `[-]` dropped.

---

## Phase 0: Feasibility checks (no changes to the fleet) -- DONE 2026-09-21

Checked against k3s v1.36.4+k3s1 (de-msa2 32c/128G, de-n5 16c/128G,
desg0 192c/512G), substrate `main` and ax `main` as of 2026-09-21.
All items closed 2026-09-22.

- [x] `PodCertificateRequest` API. **Not served today**: `certificates.k8s.io`
      only exposes `v1`; no `podcertificaterequests`/`clustertrustbundles`.
      In k8s 1.36 the feature is beta but OFF by default (GA in 1.37).
      Required on every k3s server, via `services.k3s.extraFlags` in
      `modules/k3s_init.nix` + `modules/k3s_server_follow.nix`:
      ```
      --kube-apiserver-arg=feature-gates=PodCertificateRequest=true,ClusterTrustBundle=true
      --kube-apiserver-arg=runtime-config=certificates.k8s.io/v1beta1=true
      --kubelet-arg=feature-gates=PodCertificateRequest=true,PodCertificateProjection=true
      ```
      Substrate's signer (`cmd/podcertcontroller`) already handles the 1.36
      kubelet `StubPKCS10Request` field, so kubelet/signer skew is fine.
      Neither module sets `extraFlags` yet; no `/etc/rancher/k3s/config.yaml`.
- [x] Asset fetching. `atelet` opens `SandboxConfig` asset URLs with an
      **anonymous GCS client first**, then falls back to the cluster's own
      object store (`cmd/atelet/sandbox_assets.go`). `gs://gvisor/...` works
      as long as nodes can reach `storage.googleapis.com` (they can; only
      meshify sits behind Mullvad). No https scheme; if a mirror is ever
      needed, stage `gvisor.tar.bz2` in the rustfs snapshot bucket and use an
      `s3://` URL.
- [x] Privileged pods: k3s has no PodSecurity admission config; RuntimeClasses
      present are `crun nvidia spin wasm*` -- no gVisor class needed, `runsc`
      runs inside the worker pod (`/var/lib/ateom-gvisor` hostPath).
- [x] `runsc` systrap on kernels 6.18.39 (de-msa2/de-n5) and 7.2.6 (desg0):
      tested 2026-09-22 with the exact build Substrate's `SandboxConfig`
      fetches (`gs://gvisor/releases/nightly/2026-09-02/x86_64/gvisor.tar.zstd`,
      `runsc release-20260824.0-120-g727c8c389c36`). On every node, as root,
      `--platform=systrap --network=none`: `runsc do` runs a shell,
      and an OCI bundle (host `/` read-only rootfs) goes through `create`,
      `start`, `checkpoint --image-path`, `delete`, `create`, `restore
      --detach` back to `running`. No kernel-specific issues, so the first
      WorkerPool does not need a de-msa2/de-n5 nodeSelector. Gotchas when
      testing by hand: NixOS has no `/bin/sleep` inside the sandbox (set
      `PATH=/run/current-system/sw/bin`), `runsc restore` without `--detach`
      blocks until the container exits, and `--root` leaves a `null-netns`
      bind mount behind that must be `umount`ed before `rm -rf`. Do not
      pipe the test script into `bash -s`: the sandbox eats stdin.
- [x] Registry: `http://de-msa2:2999/v2/` answers 401 (Forgejo registry, auth
      required); k3s already trusts it (`modules/k3s_registries.nix`).
      `ko` 0.19.1 is in nixpkgs (not installed on meshify). Login with a
      Forgejo token, `KO_DOCKER_REPO=de-msa2:2999/mathiswellmann`; ko honours
      the docker config for plain-http registries. Actual push untested.
- [x] Install scripts read. `hack/install-ate.sh` (1699 lines) renders
      `manifests/ate-install/` with `kubectl kustomize | ko resolve`:
      - `ate-system-namespace.yaml`, `generated/` (CRDs: `workerpools`,
        `sandboxconfigs`, `csidriverconfigs`, `role.yaml`)
      - `sandboxconfig-validation.yaml` (ValidatingAdmissionPolicy),
        `sandboxconfig-gvisor.yaml`
      - `pod-certificate-controller.yaml` (signer: RBAC on
        `podcertificaterequests`, `clustertrustbundles`, `signers/sign`)
      - `ate-api-server.yaml`, `ate-controller.yaml`, `atelet.yaml`
        (DaemonSet, privileged, hostPaths `/var/lib/ateom-gvisor`,
        `/var/lib/kubelet/plugins`, `/var/lib/kubelet/device-plugins`, `/dev`)
      - `atenet-router.yaml` (+ optional `atenet-egress*.yaml`,
        `agentgateway*` overlays for egress filtering)
      - `ate-otel-config.yaml` ConfigMap: every component `envFrom`s it, so
        it must exist even without a collector
      - **State store is Postgres, not Valkey/Redis** (bundled StatefulSet
        `manifests/ate-install/postgres/postgres.yaml`, TLS via pod certs,
        DSN `postgresql://postgres@postgres.ate-system.svc:5432/atepg`)
      - kind overlay adds `kind/rustfs.yaml`, `otel-collector.yaml`,
        `prometheus.yaml` and patches S3 env onto atelet + ate-api-server:
        `ATE_STORAGE_BACKEND=s3 AWS_REGION AWS_ENDPOINT_URL
        AWS_S3_USE_PATH_STYLE=true AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY`
      - `${SUBSTRATE_VERSION_SUFFIX}` placeholder in resource names
- [x] S3 backend decided: **rustfs on de-msa2** as a NixOS service
      (`services.rustfs` exists in nixpkgs, rustfs 1.0.0-rc.6, has
      `environmentFile` for `RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`) with
      data in a new ZFS dataset `nvme_pool/rustfs` (pool has 4 TB free;
      sibling datasets are created by hand, e.g. `nvme_pool/forgejo`).
- [x] Secrets: **agenix** (`secrets/secrets.nix`, `age.secrets.*`), not sops.
      Rekeying must happen on de-msa2 (see memory: meshify is not a recipient).
- [x] Gemini key is **optional**. `ax-task-runner` skips the Antigravity
      `goal` bootstrap with a warning when `GEMINI_API_KEY` is unset
      (`internal/workspace/setup.go:runBootstrap`); the task command still
      runs. `Model` is only consulted by the goal planner. Decision: **no
      Gemini key**; do not use `spec.workspaces[].goal`.
- [x] Self-hosted inference path confirmed. `Task.spec.env` is copied
      verbatim into the per-task ActorTemplate env
      (`internal/controller/reconciler.go:143-171`), so
      `OPENAI_BASE_URL=http://192.168.0.13:<qwen3_port>/v1` reaches the
      sandbox. Without a `Gateway`, egress defaults to allow-all
      (`reconciler.go:193`); with one, add `192.168.0.13:<qwen3_port>` to the
      allowlist. Use the IP: pods cannot resolve `*.k3s.lan`/Tailscale names.
- [x] ax-controller -> Substrate: flags `--substrate-endpoint
      api.ate-system.svc.cluster.local:443`, bearer token file (`ate-token`
      Secret) and CA (`servicedns-ca` ClusterTrustBundle-derived);
      `ATENET_ROUTER_ADDR=atenet-router.ate-system.svc.cluster.local:80`.

## Phase 1: Cluster prerequisites -- config done 2026-09-21, deploy pending

Config (one jj revision each):
- [x] `hosts/de-msa2/rustfs.nix`: `services.rustfs` on `/nvme_pool/rustfs`,
      S3 API on `constants.rustfs_port` (3020; 9000 is ClickHouse via k3s
      servicelb on every node), console off, firewall open.
- [x] agenix `secrets/rustfs_env.age` (`RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`,
      recipients de-msa2 user + host) wired into
      `services.rustfs.environmentFile`. Generated on meshify with `age`
      (public keys only; de-msa2 decrypts).
- [x] `s3.k3s.lan` in `modules/base_system.nix` + `env/host_ingress.nix`
      entry; `manifests/prod/s3/` rendered.
- [x] `modules/k3s_pod_certificates.nix` (feature gates + v1beta1
      runtime-config, kubelet gates), imported by both k3s server modules.
      Gate names verified against k8s release-1.36 source.
- [x] agenix -> k8s bridge: oneshot `rustfs-k8s-secret` on de-msa2 creates
      `ate-system/rustfs-s3-credentials` (`ATE_STORAGE_BACKEND`, `AWS_*`,
      endpoint `http://192.168.0.14:3020`) for `envFrom`.
- [x] `pkgs/agent-substrate.nix`: `buildGo127Module` of substrate (vendored
      deps) -> `.#agent-substrate` (binaries incl. `kubectl-ate`) and
      `.#agent-substrate-push-images` (skopeo push of per-component OCI
      images to `de-msa2:2999/mathiswellmann/<name>:<short-rev>`). No `ko`.

Deploy steps, in order (need hands on the hosts):
- [x] de-msa2: `sudo zfs create -o com.sun:auto-snapshot=false nvme_pool/rustfs`
- [x] de-msa2: `nixos-rebuild switch` (rustfs, secret bridge, k3s gates);
      check `systemctl status rustfs rustfs-k8s-secret` and
      `sudo k3s kubectl -n ate-system get secret rustfs-s3-credentials`.
- [x] Create bucket `ate-snapshots` (done by hand 2026-09-21 with awscli2;
      now declarative: `buckets` list in `hosts/de-msa2/rustfs.nix`, created
      by the `rustfs-buckets` oneshot. Re-switch de-msa2 once to activate it;
      it will report `bucket ate-snapshots exists`).

### Fleet rollout -- DONE 2026-09-22

- [x] k3s gates on all three servers (k3s restarted 12:42/12:47/12:49 CEST).
      Verified with `systemctl cat k3s | grep -oE '(kube-apiserver|kubelet)-arg=[^ ]*feature-gates[^ ]*'`
      and `sudo k3s kubectl api-resources | grep -E 'podcertificate|clustertrust'`
      (both `certificates.k8s.io/v1beta1`). Do **not** use
      `ps -o args= -C k3s | grep -c ...`: k3s re-execs and `ps -C` matches
      the wrong process, it prints 0 even where the gates are on.
- [x] de-msa2 re-switched; `rustfs`, `rustfs-buckets` (`bucket
      ate-snapshots exists`), `rustfs-k8s-secret` all active.
- [x] Substrate images pushed to Forgejo (`skopeo login --tls-verify=false
      de-msa2:2999` with a `package: write` token, `nix run
      .#agent-substrate-push-images`) and pulled from de-msa2 with
      `k3s crictl`; digests in the table at the bottom.

Remote shell on the hosts is nushell, hence `bash -lc "..."` wrappers; the
checkout is `~/nixos-config` (de-n5: `/home/m/nixos-config`).

**Next:** Phase 2 (`env/substrate.nix`). Inputs are all in place: Secret
`ate-system/rustfs-s3-credentials`, bucket, images, gates. Add
`agent-substrate` (kubectl-ate) to `home/meshify.nix` when the first actor
is to be created.

Known drift found on the way: `manifests/prod/dsh` and
`manifests/prod/headlong` had no source in `env/`. Fixed 2026-09-22: `dsh`
is now an entry in `env/host_ingress.nix` (rendered output synced), headlong
was removed everywhere (it was already gone from the cluster). Still open,
not ours: the argocd / cert-manager charts moved with the automated
flake.lock bumps, so the next full `nixidy switch .#prod` upgrades both.
Review those two diffs (`nix run .#nixidy -- build .#prod && diff -r
manifests/prod result`) before pushing.

## Phase 2: Agent Substrate (`env/substrate.nix`, namespace `ate-system`)

Config done 2026-09-22, deploy pending. Instead of hand-inlined YAML the app
is a nixidy `kustomize.applications` entry: the pinned upstream
`manifests/ate-install/` tree (same source as the images) gets `ko://` and
`${SUBSTRATE_VERSION*}` substituted at build time, then a small kustomize
overlay applies the fleet patches; `fleet.yaml` holds what upstream creates
imperatively. Rendered to `manifests/prod/substrate/` (48 objects), all
non-CR objects pass `kubectl apply --server-side --dry-run=server`.

- [x] `applications.substrate` in `env/substrate.nix`, imported from
      `env/prod.nix`. `syncOptions.serverSideApply` (CRD schemas too large
      for client-side apply). nixidy gotcha: `kustomize.applications.<n>.namespace`
      is written into the kustomization's `namespace:`; set it to `""`
      or every object is moved into `ate-system`.
- [x] CRDs (`workerpools`, `sandboxconfigs`, `csidriverconfigs`) + `role.yaml`.
- [x] `ate-otel-config`: no collector; `OTEL_TRACES_SAMPLER=always_off`,
      `OTEL_METRIC_EXPORT_INTERVAL=3600000`. Exports are hard-wired to
      `localhost:4317` and fail quietly. Phase 6: a collector -> Prometheus.
- [x] Postgres StatefulSet, local-path PVC 20Gi, 250m/512Mi requests. TLS
      via pod certs; the DSN "Secret" `ate-api-server-secret-envvars` has
      no password (clientcert auth), so it lives in git.
- [x] `pod-certificate-controller` (ns `podcertificate-controller-system`).
- [x] `ate-api-server` + headless Service `api.ate-system.svc:443`, S3 env
      via `envFrom rustfs-s3-credentials`; `--egress-gateway-address`
      dropped (no atenet-egress deployed => egress allow-all). Auth config
      `ate-api-authentication`: issuer
      `https://kubernetes.default.svc.cluster.local`, audience `api.ate-system.svc`.
- [x] `ate-controller`.
- [x] `atelet` DaemonSet named `atelet` (upstream `atelet-<version>` keyed by
      an `ate.dev/substrate-version` node label for blue/green; dropped, ArgoCD
      rolls it), hostPorts 8085/9090 (free on all nodes), S3 env,
      `--gcp-auth-for-image-pulls=false`.
- [x] `atenet-router` (+ envoy sidecar) and CoreDNS rewrite of
      `*.actors.resources.substrate.ate.dev` -> `atenet-router.ate-system.svc`
      via k3s's `kube-system/coredns-custom` ConfigMap (`.override` key).
- [x] `SandboxConfig gvisor-default` (upstream nightly 2026-09-02 tarball, the
      build verified in Phase 0) + ValidatingAdmissionPolicy. Annotated
      `SkipDryRunOnMissingResource=true` (CRD ships in the same app).
- [x] `WorkerPool ate-system/gvisor`: 3 replicas, 1-4 CPU / 4Gi per worker,
      `workerImage` ateom-gvisor (digest-pinned), label `workload: gvisor`,
      Zen 4 nodes only (see smoke-test findings below).
- [x] Bootstrap oneshot `substrate-bootstrap` in `hosts/de-msa2/substrate.nix`:
      creates the namespaces and, if missing, the four generated pools with
      `kubectl-ate admin make-ca-pool/make-jwt-pool`
      (`podcertificate-controller-system/{service-dns,pod-identity}-ca-pool`,
      `ate-system/{actor-id-ca-pool,actor-id-jwt-pool}`). Never rotates.
- [x] `kubectl-ate`: part of `.#agent-substrate`, added to `home/meshify.nix`
      (`~/.kube/config` exists on meshify).
- [x] Images rebuilt with `/ko-app/<name>` (upstream `command:` paths) and
      the `demos/counter` smoke-test image; re-pushed, digests below.

Deployed 2026-09-22 (first rollout). Control plane, atelet on all nodes,
router and 3 workers came up on the first sync; the golden-snapshot boot
of the smoke-test template then exposed four problems, all fixed in git:
- `envFrom` has no merge key: the S3 strategic-merge patch replaced the list
  and dropped `ate-otel-config` + the Postgres DSN refs; ate-api-server
  crash-looped with "--postgres-connection-string is required".
- ArgoCD's bundled schema predates `podCertificate` projected volumes ->
  "field not declared in schema", app Unknown/Degraded. Fixed with
  `compareOptions.serverSideDiff = true`.
- atelet pulls actor images itself (go-containerregistry): plain HTTP only
  for localhost / RFC1918 registries, and Forgejo sends the token realm at
  its ROOT_URL. Actor images are therefore referenced as
  `forgejo.k3s.lan/mathiswellmann/<name>@sha256:...` (ateapi requires a
  digest pin), the fleet CA is in the image bundle, and pods resolve
  `forgejo.k3s.lan` -> de-msa2 via a `coredns-custom` `.server` block
  (`hosts` may appear once per server block; k3s's main block has one).
- The Nix images had no `/tmp`; runsc boot chroots into `/tmp`, so every
  sandbox died with "waiting for sandbox to start: EOF" (visible only with
  `debugRunsc = true` in `pkgs/agent-substrate.nix`, which uncomments
  ateom's `runsc -debug` flags; logs under
  `/var/lib/ateom-gvisor/actors/<uid>/runsc-debug-logs/`). And because the
  WorkerPool controller creates worker pods with the default pull policy,
  nodes kept the first image they cached under the mutable tag. Images are
  now **pinned by digest**: the package converts each archive to an OCI
  layout at build time (`refs`/`digests`, IFD), pushes from that layout so
  the registry digest is identical, and the manifests reference
  `<registry>/<name>:<tag>@sha256:...`. Any image change = manifest diff.

Redeploy after a rebuild: `nix run .#agent-substrate-push-images` (prints
pushed vs expected digests), `nix run .#nixidy -- build .#prod`, copy
`result/substrate` + `result/apps/Application-substrate.yaml` into
`manifests/prod/`, push. ArgoCD self-heal reverts any live `kubectl apply`
that differs from `main` within minutes, so live patching is only for
experiments (untracked objects, e.g. a `gvisor-debug` WorkerPool, survive).

Smoke test **passed 2026-09-22** (counter demo): template golden snapshot ->
`create actor` (starts SUSPENDED) -> `resume` -> HTTP via the router ->
`suspend` (checkpoint + pages + durable dir land in
`s3://ate-snapshots/<prefix>/atespaces/demo/actors/<uid>/snapshots/<id>/`)
-> `resume` -> both the in-memory and the on-disk counter continued (3 -> 4,
5, 6). Findings:
- **Snapshots are CPU-feature-bound.** de-msa2 is Zen 5, desg0/de-n5 are
  Zen 4; a snapshot taken on de-msa2 fails to restore elsewhere with
  "incompatible FeatureSet: missing features: tsc_adjust movdiri movdir64b
  avx512_vp2intersect". The `gvisor` WorkerPool is therefore pinned to
  `hostname NotIn [de-msa2]` (nodeAffinity in the template). A new worker
  node must be Zen 4-compatible or get its own pool + selector label.
- The router routes HTTP on the header `ate-target-actor: <atespace>/<actor>`
  (`curl -H ate-target-actor:demo/c1 http://atenet-router.ate-system.svc/`
  from a pod); the `<actor>.<atespace>.actors.resources.substrate.ate.dev`
  hostname is for CONNECT tunnels (what ax uses). The first request after a
  resume can time out while the tunnel warms up.
- An actor whose `runsc restore` fails is left in `ACTOR_STATE_RESUMING`
  and cannot be deleted/reverted (`demo/my-counter`, the cross-CPU victim;
  should flip to CRASHED once its worker pod is gone). Upstream gap.
- kubectl-ate from meshify: `KUBECONFIG=~/.kube/k3s.yaml` (k3s admin config,
  server `https://100.83.142.17:6443`, `tls-server-name: 192.168.0.14`
  because the API cert has no tailnet SAN); it port-forwards itself.
  Template used: `/tmp/ate/counter-template.yaml` on meshify (image
  `forgejo.k3s.lan/mathiswellmann/counter@<digest>`, `workload: gvisor`,
  `gs://ate-snapshots/demo/`, `gvisor-default`).
- [ ] After the Zen-4 pinning is pushed: recreate template `demo/counter`
      (its golden snapshot may have been taken on de-msa2) and delete
      `demo/my-counter` once it is CRASHED.
- [x] Prometheus (VictoriaMetrics on de-msa2, `hosts/de-msa2/prometheus.nix`
      `substrate_scrape_configs`): k8s pod SD in `ate-system` keyed on the
      upstream `prometheus.io/scrape` annotation -> jobs `atelet` (one target
      per node, `node` label), `ate-api-server`, `atenet-router` on :9090,
      plus job `ate-controller` (controller-runtime `/metrics` :8080, no
      annotation). Workers export OTLP only; Postgres has no exporter. The
      existing `ScrapeTargetDown` alert covers all of them. Needs a de-msa2
      switch; verify at http://de-msa2:9003/targets (or `up{job=~"ate.*|atelet|atenet-router"}`).

## Phase 3: AX control plane (`env/ax.nix`, namespace `ax-system`) -- DONE 2026-09-22

Config done 2026-09-22 (upstream `d8ed0fe38bce`, 2026-09-19), deployed the
same day.

- [x] `pkgs/ax/default.nix`: buildGoModule of `cmd/{ax,ax-server,ax-controller,ax-task-runner}`
      (`vendorHash`, deps not vendored), images + OCI layouts + digests +
      `refs` like agent-substrate; `.#ax` (CLI), `.#ax-push-images`.
      Patch `default-task-image-env.patch`: `AX_DEFAULT_TASK_IMAGE` env
      overrides upstream's hardcoded GCR runner image (candidate upstream PR).
- [x] Task-runner image without Antigravity/Python (no `goal` support, see
      Phase 0): git, ssh, curl, bash, coreutils, fleet CA, `/usr/local/bin/ax-task-runner`,
      `/workspace`, `/tmp`. Referenced as
      `forgejo.k3s.lan/mathiswellmann/ax-task-runner@sha256:...` (atelet pull
      path, see Phase 2). Phase 5 replaces it with a dsh/pi image.
- [x] `applications.ax` in `env/prod.nix`; `compareOptions.serverSideDiff`
      (clusterTrustBundle volume). Rendered to `manifests/prod/ax/`.
- [x] Redis Deployment + Service (`redis:7-alpine` pinned, emptyDir; a
      PVC + AOF since Phase 4).
- [x] `ax-server` Deployment + Service :8080.
- [x] `ax-controller` Deployment + RBAC as upstream (`ate-token` projected SA
      token, audience `api.ate-system.svc`; `servicedns-ca` trust bundle;
      `ATENET_ROUTER_ADDR`), plus `AX_SNAPSHOTS_BUCKET=gs://ate-snapshots/ax/`
      and `AX_DEFAULT_TASK_IMAGE`. ate-api-server does not enforce authz yet
      (TODOs in `controlapi/actor.go`), so the SA token is accepted.
      The controller creates atespaces itself; per-task ActorTemplates carry
      no `workerSelector` (= any worker) and no resource limits.
- [-] `gemini-api-secret`: not needed (Phase 0 decision: no Gemini, no
      `goal`). Revisit only if Phase 5's OpenAI-compatible provider lands.
- [x] Ingress `ax.k3s.lan` -> ax-server (traefik `serversscheme: h2c`,
      fleet cert, homepage annotations + `/healthz` siteMonitor);
      `ax.k3s.lan` in `modules/base_system.nix` hosts. The CLI itself uses
      its kubectl tunnel (`ax ctx`) or `$AX_SERVER`.
- [x] `ax` CLI in `home/meshify.nix`.
- [x] Deploy: ArgoCD `ax` Synced/Healthy; `ax-server`, `ax-controller`,
      `ax-redis` Running on desg0 with 0 restarts. The controller logs one
      Redis "connection refused" at startup (it starts before Redis), then
      reconnects and blocks in `XREADGROUP` on the task stream. It only
      talks to Substrate when a Task is reconciled, so the first Phase 4
      Task is what proves that path.
- [x] Smoke test: `ax get tasks|gateways|workspaces|models` all answer
      (empty). meshify was not ready for the planned `ax ctx` path: `ax` not
      on PATH (home-manager not switched), no fleet kubeconfig
      (`~/.kube/config` is only a local k3d cluster, `~/.kube/k3s.yaml`
      does not exist), and `ax.k3s.lan` does not resolve (meshify not
      switched). Tested through an SSH tunnel to the ax-server ClusterIP
      instead: `ssh -f -N -L 18080:<clusterIP>:8080 de-msa2` +
      `AX_SERVER=localhost:18080 ax get tasks`. The ax CLI needs `kubectl`
      on PATH for its own tunnels (`ax ctx`, and `ax ssh` port-forwards
      `svc/atenet-router`), so Phase 4 drives it from de-msa2.

## Phase 4: AX objects (not GitOps-managed; live in ax's Redis)

Applied and smoke tested 2026-09-22. One deploy step open (patched ax images).

- [x] `manifests/ax/`: one file per object, `gateway-*`, `workspace-*`,
      `task-*` (no `Model` until Phase 5). ArgoCD only renders
      `manifests/prod/`, so these are not picked up by GitOps.
      Decided 2026-09-23 to keep them as raw YAML outside nixidy: they are
      not Kubernetes resources (no CRDs; ax-server keeps them in Redis over
      gRPC), so ArgoCD could only manage a ConfigMap plus a home-made
      `ax apply` CronJob, with no diff, prune or health for the objects.
      Tasks are one-offs that ax changes on suspend/resume. Revisit if
      upstream adds CRDs.
- [x] `Gateway lan-llm` (`manifests/ax/gateway-lan-llm.yaml`): SGLang
      `192.168.0.13/32`, Forgejo `192.168.0.14/32` + `forgejo.k3s.lan`,
      `github.com`, `*.githubusercontent.com`. **Recorded, not enforced**:
      ax drops `port` (only host patterns/CIDRs reach Substrate's
      EgressPolicy), and Substrate only enforces EgressPolicy through an
      egress gateway (`--egress-gateway-address` + atenet-egress), which the
      fleet does not deploy. Sandbox egress is allow-all. Bare IPs must be
      written as CIDRs (`/32`); Substrate validates hostname patterns as DNS
      names. `listeners` are display-only.
- [x] `Workspace monty-persona`: `https://forgejo.k3s.lan/MathisWellmann/monty-persona.git`
      (pods resolve `forgejo.k3s.lan` via coredns-custom, fleet CA in the
      runner image; `de-msa2` does not resolve in pods). `dir: "."` clones
      into the workspace root; the default is `<path>/<repo name>`, i.e.
      `/workspace/monty-persona/monty-persona`.
- [x] `Task smoke-lan-llm`: `debug: true`, `OPENAI_BASE_URL=http://192.168.0.13:8000/v1`,
      Gateway `lan-llm`, Workspace `monty-persona`. Verified: controller ->
      Substrate (custom ActorTemplate, actor resumed on a worker),
      `WorkspaceReady`, `ax ssh`, `git log` in the clone, `curl
      $OPENAI_BASE_URL/models` from inside the sandbox (returns
      `RadixArk/Qwen3.8-27B-NVFP4`), `ax suspend` + `ax resume` (resumed on a
      different worker; `/workspace` survived, `/tmp` did not: suspend sends
      SIGTERM to PID 1 and only the durable `/workspace` is restored into a
      fresh process tree, unlike the raw Substrate counter demo). Left
      suspended.
- [x] Re-apply after a Redis flush: `nix run .#ax_apply` (`scripts/ax_apply.nix`)
      applies Gateways, Models, Workspaces from a store copy of
      `manifests/ax/` in dependency order; `ax_apply FILE...` applies
      explicit files (Tasks). Chosen over a post-sync Job: tasks are
      one-offs, and the script needs nothing in-cluster. It needs a fleet
      kubeconfig + `kubectl` (ax tunnels via `kubectl port-forward`); when
      `KUBECONFIG` is unset it uses `/etc/rancher/k3s/k3s.yaml`, so on a k3s
      node run it as root. Used from de-msa2 for everything above (built
      on meshify, `nix copy --to ssh://de-msa2`).
- [ ] **Deploy the reconciler patch.** Tasks without `spec.image` failed with
      "must be pinned by digest": `reconciler.go` sets `spec.image` to
      upstream's unpinned GCR default before `BuildActorTemplate` sees it, so
      the old `AX_DEFAULT_TASK_IMAGE` patch never fired. Fixed in
      `pkgs/ax/default-task-image-env.patch` (`substrate.DefaultImage()` in
      both places) and `manifests/prod/ax/` re-rendered (all three ax image
      digests change). Still needed: `skopeo login --tls-verify=false
      de-msa2:2999`, `nix run .#ax-push-images`, push `main`. Until then the
      smoke test ran with `spec.image` set to the live runner digest (not
      committed; the committed Task omits `image` on purpose). After the
      deploy: `ax delete task smoke-lan-llm` and re-apply the committed
      file to confirm the default image path.
- [x] meshify access (config 2026-09-23, needs push + meshify switch):
      `env/cluster_access.nix` (nixidy app `cluster-access`) declares
      ServiceAccount `kube-system/meshify-admin` (cluster-admin) and a
      long-lived token Secret (sync-wave 1: the token controller deletes a
      token Secret whose SA does not exist yet). The token is in
      `secrets/k3s_meshify_admin_token.age` (recipients meshify host + user,
      de-msa2 user), decrypted on meshify to `/run/agenix/k3s_meshify_admin_token`.
      `~/.kube/k3s.yaml` is generated by home-manager (`home/meshify.nix`):
      server `https://de-msa2:6443` (the API cert has a `de-msa2` SAN; no
      `tls-server-name` needed), CA `modules/k3s-server-ca.crt` (valid until
      2036), `tokenFile` pointing at the agenix path. `kubectl` is in
      `home/home.nix`. meshify's `age.identityPaths` pointed only at a
      missing `~/.ssh/magewe_meshify`; the host key is now listed first.
      The SA objects were applied live once to mint the token, and ArgoCD
      adopts them on sync. Tested before deploying (token decrypted to a temp
      file): `kubectl get nodes`, `ax ctx` (context `k3s`), `ax get tasks`
      through ax's own tunnel. Usage: `KUBECONFIG=~/.kube/k3s.yaml ax ...`
      (`~/.kube/config` stays the local k3d cluster).
- [x] ax-redis persistence (config 2026-09-23, needs push): 1Gi local-path
      PVC `ax-redis-data`, `--appendonly yes --appendfsync everysec`,
      Deployment strategy `Recreate`. The first sync replaces the emptyDir,
      so the current objects are lost once: re-run `ax_apply` and re-apply
      the smoke Task after the rollout.

## Phase 5: Local-model integration

- [ ] Task runner image: build an image that ships `dsh` and/or `pi` with
      `OPENAI_BASE_URL` pointed at the SGLang endpoint (see
      `hosts/desg0/constants.nix` for the model id and port).
- [ ] Optional: patch ax `internal/model/client.go` (only `google` is
      implemented) to add an OpenAI-compatible provider so
      `spec.workspaces[].goal` can use SGLang. The runner's
      `antigravity_bootstrap.py` is Gemini-specific too, so this also means
      swapping the bootstrap agent (e.g. for `dsh`/`pi` non-interactive).
      Keep the patch in `pkgs/ax/` and consider upstreaming it.
- [ ] If the patch lands: add a `Model` pointing at SGLang and enable `goal`.

## Phase 6: Operations

- [ ] Document the upgrade procedure (upstream May 2026 change required:
      delete CRDs, redeploy Substrate, `kubectl ate admin
      debug-flush-redis`, redeploy ax, re-apply Phase 4 objects).
- [ ] Backup policy for `nvme_pool/rustfs` (zfs auto-snapshot is already on
      for the pool if `com.sun:auto-snapshot` is inherited) or accept the
      bucket as ephemeral.
- [ ] Resource limits and WorkerPool size tuned after the first real load.
- [ ] Alert on `ate-system` / `ax-system` pods down (Prometheus).
      (`ate-system` is covered by `ScrapeTargetDown` since the Phase 2 scrape
      jobs; `ax-system` once Phase 3 adds its jobs.)
- [ ] Reproducible Grafana dashboard for the stack (provisioned from this
      repo like the other dashboards in `hosts/de-msa2/grafana.nix`, not
      clicked together in the UI): atelet per node (sandbox count, image
      cache, snapshot durations), ate-api-server RPC rates/errors,
      atenet-router requests + resume latency, ate-controller reconcile
      errors, worker pool capacity vs. use, rustfs bucket size; later ax
      task counts/states. Metric names: `docs/metrics/` upstream.
- [ ] Update `README.md` service table and the homepage dashboard entries.
- [ ] Save gotchas found along the way to the maki memory notes.

---

## Recorded versions

| Component | Upstream commit | Image digest |
|-----------|-----------------|--------------|
| substrate | `dc1f263076d1575c0562c71d763edd0a0342fd68` (2026-09-21), tag `dc1f263076d1` | see below |
| ax        | `d8ed0fe38bceb7842d3c47817d53d16ccdfcb601` (2026-09-19), tag `d8ed0fe38bce` | pinned in `manifests/prod/ax/*.yaml` |

Substrate image digests are pinned in the rendered manifests
(`grep -h 'image:\|workerImage:' manifests/prod/substrate/*.yaml`) and computed
by `pkgs/agent-substrate.nix` (`refs`); the push script prints pushed vs
expected. Actor images (`counter`, later ax's task runner) are referenced
through `forgejo.k3s.lan/...@sha256:...` in ActorTemplates.
