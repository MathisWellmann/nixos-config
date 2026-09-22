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
      `workerImage` ateom-gvisor, label `workload: gvisor`; no node pinning.
- [x] Bootstrap oneshot `substrate-bootstrap` in `hosts/de-msa2/substrate.nix`:
      creates the namespaces and, if missing, the four generated pools with
      `kubectl-ate admin make-ca-pool/make-jwt-pool`
      (`podcertificate-controller-system/{service-dns,pod-identity}-ca-pool`,
      `ate-system/{actor-id-ca-pool,actor-id-jwt-pool}`). Never rotates.
- [x] `kubectl-ate`: part of `.#agent-substrate`, added to `home/meshify.nix`
      (`~/.kube/config` exists on meshify).
- [x] Images rebuilt with `/ko-app/<name>` (upstream `command:` paths) and
      the `demos/counter` smoke-test image; re-pushed, digests below.

Deploy (in order):
1. Commit + push (`env/substrate.nix`, `hosts/de-msa2/substrate.nix`,
   `manifests/prod/substrate/`, `manifests/prod/apps/Application-substrate.yaml`).
2. de-msa2: `nixos-rebuild switch`; `systemctl status substrate-bootstrap`
   must show the four pools created; `kubectl -n ate-system get secret`.
3. ArgoCD syncs `substrate`. Expected order of readiness:
   podcertificate-controller -> ClusterTrustBundles
   (`kubectl get clustertrustbundles`) -> postgres -> ate-api-server ->
   ate-controller / atenet-router / atelet -> WorkerPool workers
   (`kubectl -n ate-system get workerpool gvisor`).
4. Smoke test from meshify (`kubectl ate ...`, `manifests/ax/` later):
   - `kubectl ate create atespace demo`
   - ActorTemplate from upstream `demos/counter/counter-template.yaml.tmpl`
     with image `de-msa2:2999/mathiswellmann/counter:dc1f263076d1`,
     `workerSelector.matchLabels.workload: gvisor`,
     `storageLocation: gs://ate-snapshots/demo/` (scheme is ignored, the
     host is the bucket), `configName: gvisor-default`.
   - create actor, hit it, `suspend`, `resume`, check the count continued
     and `s5cmd ls s3://ate-snapshots/demo/` on de-msa2 shows the snapshot.
- [ ] Add `ate-system` pods to Prometheus scrape targets / alerts in
      `hosts/de-msa2/prometheus.nix` (atelet/ateapi/atenet expose :9090
      `/metrics`, annotated `prometheus.io/scrape`).

## Phase 3: AX control plane (`env/ax.nix`, namespace `ax-system`)

- [ ] Build and push `ax-server`, `ax-controller` and the `ax-task-runner`
      image with `ko` to Forgejo. Record digests + upstream commit.
- [ ] New nixidy app `applications.ax` imported from `env/prod.nix`.
- [ ] Redis Deployment + Service (from `deploy/redis.yaml`).
- [ ] `ax-server` Deployment + Service (gRPC :8080, `/healthz`), configured
      with the Substrate address `api.ate-system.svc.cluster.local:443`.
- [ ] `ax-controller` Deployment + RBAC, with the Substrate bearer token
      (`ate-token` Secret) and CA (`servicedns-ca`) mounted as in
      `deploy/ax-controller.yaml`, `ATENET_ROUTER_ADDR` set.
- [-] `gemini-api-secret`: not needed (Phase 0 decision: no Gemini, no
      `goal`). Revisit only if Phase 5's OpenAI-compatible provider lands.
- [ ] Ingress `ax.k3s.lan` -> ax-server with the fleet `k3s-lan-ca` cert,
      annotated for the homepage dashboard (`gethomepage.dev/*`).
- [ ] Package the `ax` CLI in `pkgs/ax` (buildGoModule of `cmd/ax`) and
      expose it as `packages.x86_64-linux.ax` in `flake.nix`; add to
      `home/meshify.nix`.
- [ ] Smoke test from meshify: `ax ctx`, `ax get tasks`.

## Phase 4: AX objects (not GitOps-managed; live in ax's Redis)

- [ ] Create `manifests/ax/` for `Task`/`Workspace`/`Gateway` YAML
      (no `Model` until Phase 5).
- [ ] `Gateway lan-llm`: egress allowlist with the SGLang endpoint by IP
      (`192.168.0.13:<qwen3_port>`; pods cannot resolve `*.k3s.lan` or
      Tailscale names), plus git hosts (`192.168.0.14:2999` Forgejo,
      github.com:443).
- [ ] `Workspace` pointing at a Forgejo repo (`http://de-msa2:2999/...`).
- [ ] First `Task` with `debug: true` and
      `env: [{name: OPENAI_BASE_URL, value: http://192.168.0.13:<qwen3_port>/v1}]`;
      verify `ax ssh`, a `curl $OPENAI_BASE_URL/models` from inside the
      sandbox, `ax suspend`, `ax resume`.
- [ ] Decide how to (re)apply these after a Redis flush: a script in
      `scripts/` run from meshify, or a post-sync Job in `env/ax.nix` that
      runs `ax apply -f`.

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
- [ ] Update `README.md` service table and the homepage dashboard entries.
- [ ] Save gotchas found along the way to the maki memory notes.

---

## Recorded versions

| Component | Upstream commit | Image digest |
|-----------|-----------------|--------------|
| substrate | `dc1f263076d1575c0562c71d763edd0a0342fd68` (2026-09-21), tag `dc1f263076d1` | see below |

Substrate images, `de-msa2:2999/mathiswellmann/<name>:dc1f263076d1`, re-pushed
2026-09-22 after adding `/ko-app/<name>` and the counter demo (the first
push of the day had different digests; tags were overwritten):

| Image | sha256 |
|-------|--------|
| ateapi | `b4956a712dd3ddf55c8342299e14fff6f51df899d01c4b93e2e917a33e3a51c7` |
| atecontroller | `7584a3688dcee4c8e653e4ac497e123e7f4630ae017bb1239a17fc94b02252d2` |
| atelet | `28ac23e3b64e65cfa26e500eb216553cd2dcd9f2e9aca9e27f6c2dd43f3bedab` |
| atenet | `36936e2acbb6114c45d1df600259587cb352bb3109d3315edc9524241e30d1f2` |
| ateom-gvisor | `962e66b054d106a268cdb211175433ef4b23f08d87f75af0e0be2a8dd5a3f700` |
| podcertcontroller | `642e12f75fba9721f37afa476ef4ed3b1e432380eff3d8f1e16cb3ceb407295c` |
| counter (demo) | `efd521a53515f065b4ed1c9eae44fe8c0e5ceeea08bf6049e7256e4a4457a272` |
| ax        | | |
