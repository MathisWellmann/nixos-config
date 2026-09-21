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
- [ ] `runsc` systrap on kernels 6.18.39 (de-msa2/de-n5) and 7.1.6 (desg0):
      not yet tested; verify with the counter demo in Phase 2. Note the
      traefik-on-desg0 kernel 7.1.6 gotcha in `modules/k3s_init.nix`; pin the
      first WorkerPool to de-msa2/de-n5 if gVisor misbehaves there.
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
      S3 API on `constants.rustfs_port` (9000), console off, firewall open.
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
      endpoint `http://192.168.0.14:9000`) for `envFrom`.
- [x] `pkgs/agent-substrate.nix`: `buildGo127Module` of substrate (vendored
      deps) -> `.#agent-substrate` (binaries incl. `kubectl-ate`) and
      `.#agent-substrate-push-images` (skopeo push of per-component OCI
      images to `de-msa2:2999/mathiswellmann/<name>:<short-rev>`). No `ko`.

Deploy steps, in order (need hands on the hosts):
- [ ] de-msa2: `sudo zfs create -o com.sun:auto-snapshot=false nvme_pool/rustfs`
- [ ] de-msa2: `nixos-rebuild switch` (rustfs, secret bridge, k3s gates);
      check `systemctl status rustfs rustfs-k8s-secret` and
      `sudo k3s kubectl -n ate-system get secret rustfs-s3-credentials`.
- [ ] desg0, then de-n5: `nixos-rebuild switch` (k3s gates). Roll one at a
      time; etcd quorum needs 2 of 3 up. Then verify
      `sudo k3s kubectl api-resources | grep -E 'podcertificate|clustertrust'`.
- [ ] Create bucket: `AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
      nix run nixpkgs#awscli2 -- --endpoint-url http://de-msa2:9000 s3 mb s3://ate-snapshots`
      (creds: `sudo cat /run/agenix/rustfs_env` on de-msa2).
- [ ] Forgejo: create a token with `package:write`;
      `skopeo login --tls-verify=false de-msa2:2999`; then
      `nix run .#agent-substrate-push-images`. Record the digests below.
- [ ] Add `agent-substrate` (kubectl-ate) to `home/meshify.nix`.

Known drift found on the way (not fixed, not ours): `manifests/prod/dsh`
and `manifests/prod/headlong` have no source in `env/`, and the argocd /
cert-manager charts moved with the automated flake.lock bumps. A full
`nixidy switch .#prod` will delete the two apps and upgrade both charts.
Add `dsh`/`headlong` entries to `env/host_ingress.nix` before the next
full switch.

## Phase 2: Agent Substrate (`env/substrate.nix`, namespace `ate-system`)

- [ ] New nixidy app `applications.substrate` imported from `env/prod.nix`.
      Follow the `env/homepage.nix` style: pinned images, inline YAML.
      Source of truth: `manifests/ate-install/` rendered once with
      `kubectl kustomize manifests/ate-install/kind` + `ko resolve`, then
      de-kind-ified (drop rustfs/otel-collector/prometheus, swap S3 env).
- [ ] CRDs from `manifests/ate-install/generated/` (`workerpools`,
      `sandboxconfigs`, `csidriverconfigs`) + `role.yaml`.
- [ ] `ate-otel-config` ConfigMap (can point at nothing / a no-op endpoint).
- [ ] Postgres StatefulSet from `manifests/ate-install/postgres/` on a
      local-path PVC (or a hostPath on `nvme_pool` if pinned to de-msa2).
- [ ] `pod-certificate-controller` Deployment + RBAC.
- [ ] `ate-api-server` Deployment + Service `api.ate-system.svc.cluster.local:443`
      (this exact name is ax's in-cluster default), S3 env from the Secret.
- [ ] `ate-controller` Deployment + RBAC.
- [ ] `atelet` DaemonSet on all 3 nodes, S3 env from the Secret,
      `--gcp-auth-for-image-pulls=false`.
- [ ] `atenet-router` Deployment + Service; CoreDNS hook for
      `*.actors.resources.substrate.ate.dev`.
- [ ] `sandboxconfig-validation.yaml` + `SandboxConfig gvisor-default`
      (upstream `gs://gvisor/releases/release/<date>/x86_64/gvisor.tar.bz2`).
- [ ] `WorkerPool` (gvisor class, `replicas: 2-4`, cpu/mem requests sized
      for the nodes). No GPU pool: desg0's GPU is fully used by SGLang.
      Start with a nodeSelector for de-msa2/de-n5 until gVisor is proven on
      desg0's 7.1.6 kernel.
- [ ] `git add` the new env file (flake eval needs it tracked), run
      `nixidy build .#prod`, push, let ArgoCD sync.
- [ ] Package `kubectl-ate` in `pkgs/kubectl-ate` (buildGoModule) and add
      it to `home/meshify.nix`.
- [ ] Smoke test: `kubectl ate create atespace demo`, create the counter
      demo actor, suspend, resume, confirm the snapshot lands in rustfs.
- [ ] Add `ate-system` pods to Prometheus scrape targets / alerts in
      `hosts/de-msa2/prometheus.nix` if they expose metrics.

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
| substrate | `dc1f263076d1575c0562c71d763edd0a0342fd68` (2026-09-21), tag `dc1f263076d1` | not pushed yet |
| ax        | | |
