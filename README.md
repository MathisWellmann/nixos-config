# nixos-config

A declarative, reproducible home-and-lab NixOS fleet — nine machines, one
k3s cluster, full-disk secrets, GitOps-deployed workloads, and a unified
HTTPS service mesh over tailscale — all from a single flake.

> `sudo nixos-rebuild switch --flake .#<host>` rebuilds any machine.
> `nix run .#nixidy -- switch .#prod` reconciles the entire cluster.

---

## Highlights

### 🖥️ Fleet of nine NixOS hosts, one flake

Every host — from the k3s server `de-msa2`, to the GPU box `desg0`, to the
laptops `razerblade` / `tensorbook` — is defined in `hosts/<name>/` and built
from the same flake. Add a machine: drop a directory, add one line to
`flake.nix`, rebuild.

| Host | Role |
|------|------|
| `de-msa2` | k3s server + monitoring/alerting + git forge + self-hosted apps |
| `desg0` | GPU node (remote builder, LLM serving) |
| `meshify` / `superserver` / `poweredge` / `de-n5` | servers & nodes |
| `razerblade` / `tensorbook` | laptops (Hyprland desktop) |

### ☸️ k3s cluster with GitOps via nixidy + ArgoCD

A self-hosted k3s cluster whose workloads are rendered by
[**nixidy**](https://github.com/arnarg/nixidy) from Nix (`env/*.nix`) into YAML
manifests (`manifests/prod/`), then continuously reconciled by **ArgoCD** with
auto-sync, prune and self-heal. The cluster manages **itself**: ArgoCD and
cert-manager are declared as nixidy apps and bootstrapped through GitOps.

- `env/argocd.nix` — ArgoCD, exposed at `https://argocd.k3s.lan`
- `env/cert_manager.nix` — a self-signed root CA (`k3s-lan-ca`) generated
  in-cluster, its public cert trusted fleet-wide, so every `*.k3s.lan` service
  has a browser-trusted TLS cert with zero manual trust steps
- `env/host_ingress.nix` — fronts host-local NixOS services (ntfy, forgejo,
  grafana, vikunja) at `*.k3s.lan` via traefik + cert-manager
- `env/homepage.nix` — [homepage](https://gethomepage.dev) dashboard at
  `https://home.k3s.lan`, auto-discovering every annotated `*.k3s.lan` Ingress

### 🔔 Full observability & alerting stack

`hosts/de-msa2/alerting.nix` + `prometheus.nix` declare the entire monitoring
pipeline, rules included, reproducibly:

```
victoriametrics → vmalert (rule eval) → alertmanager
  → alertmanager-ntfy bridge → ntfy-sh (push to phone)
```

Node, ZFS, NVIDIA-GPU and Kubernetes (kube-state-metrics) metrics are all
scraped. Alert rules are set to notify if things go haywire, so the stack fires
on `NodeLoadHigh`, `ContainerCPUNearLimit`, `PodRestartLooping`, `OOMKilled`
and more — paging the ntfy app at `https://ntfy.k3s.lan/cluster-alerts`.

In the ntfy web interface at `https://ntfy.k3s.lan`, manually subscribe to the
**`cluster-alerts`** topic. This is the only required subscription; it receives
production, development (prefixed `[dev]`), host, storage, and cluster alerts.
ntfy topics are created on first publish, so they are not listed automatically
in a new browser profile.

![Monitoring & alerting — NixOS fleet + k3s cluster](docs/diagrams/monitoring-alerting.visual-check.2048x1320.dark.png)

An explorable version with guided views is in
[`docs/diagrams/monitoring-alerting.html`](docs/diagrams/monitoring-alerting.html).

### 🔐 Secrets managed with agenix

Host-specific secrets (k3s token, grafana secret key, …) live encrypted in
`secrets/` and are decrypted at activation via
[agenix](https://github.com/ryantm/agenix). Plaintext never touches the repo.

### 🌐 Tailscale mesh + Mullvad split tunnel

`modules/mullvad_tailscale.nix` wires a Mullvad WireGuard exit node alongside
tailscale, with a deterministic DNS fallback via `/etc/hosts` so routing works
regardless of who owns `resolv.conf`. Every `*.k3s.lan` name resolves to a
node's tailscale IP through `networking.hosts` in `modules/base_system.nix`.

### 🤖 Local AI stack

`modules/ai/` declares a battery of local LLM serving options: `vllm_cuda_container`, `tensorrt_llm_container`, `llama-cpp`, a
`hermes-agent` runner, `qwen_code`, and a `pi-agent` harness. The
`remote_builder.nix` module turns GPU hosts into distributed nix builders over
SSH.

`desg0` serves Qwen3.8-27B-NVFP4 with SGLang
(`hosts/desg0/sglang_qwen3_container.nix`). The concurrency limit
(`--max-running-requests 12`) comes from production metrics in
VictoriaMetrics, not from a synthetic benchmark. The data is 8,769 busy
1-minute windows since 2026-09-11, with a median prompt of ~47k tokens:

![SGLang throughput and latency vs. concurrent requests](docs/diagrams/sglang-concurrency-sweetspot.png)

- Aggregate decode peaks at 8 concurrent requests (~464 tok/s).
- Decode plus prefill compute keeps rising to ~3.3k tok/s at 12.
- From 12 to 13 there is a cliff. Inter-token latency goes from 30 to 73 ms,
  median TTFT goes from 7 to 19 s, and decode throughput halves. The cause is
  the ~50k-token prefills, which take the place of decode steps in the batch.
  The KV pool is only ~60% used at this point, so compute is the limit, not
  memory.
- Above 13, total throughput is almost all prefill (~4.5k tok/s ceiling). The
  streams then get only 4-9 tok/s each.

`meshify` runs a llama.cpp router (`modules/ai/llama-cpp.nix`) on its 24GB
RTX 3090, which also drives the desktop (~3GB). `hosts/meshify/constants.nix`
enables only the models that run fully on the GPU with at least 32k tokens of
context. The other models stay in the list as comments, for a bigger GPU. The
concurrency sweep below used `llama-batched-bench` (q8_0 KV cache,
flash-attn, all layers on the GPU) with an 8,192-token prompt and 128
generated tokens per user (2026-10-07):

![llama.cpp on meshify: throughput vs. concurrent users](docs/diagrams/llama-cpp-meshify-concurrency.png)

Generation tok/s, aggregate over all users (per user in parentheses):

| Model | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| Ling-3.0-tiny UD-Q8_K_XL (MoE) | 149 | 232 (116) | 460 (115) | 652 (82) | 832 (52) |
| gemma-4-26B-A4B Q4_K_M (MoE) | 110 | 188 (94) | 261 (65) | 344 (43) | 518 (32) |
| gemma-4-12b UD-Q8_K_XL | 48 | 89 (44) | 153 (38) | 231 (29) | 344 (22) |
| Muse-Glimmer-30B Q4_K_XL | 37 | 67 (33) | 88 (22) | 108 (13) | 233 (15) |
| Qwen3.6-27B Q4_K_XL | 32 | 56 (28) | 67 (17) | 97 (12) | OOM |

- gemma-4-26B-A4B is the best fit for many users. It gives 110 tok/s to one
  user and still 32 tok/s to each of 16 users. Ling-3.0-tiny is faster, but
  it is a much smaller model.
- Prompt processing speed does not increase with more users (~1.2k tok/s for
  Qwen3.6-27B, ~1.3k Muse, ~2.9k gemma-4-12b, ~4.4k gemma-4-26B, ~6k Ling).
  The time to read all prompts thus grows linearly. With 8 users, the last
  user of Qwen3.6-27B or Muse waits ~55 s for the first token.
- Qwen3.6-27B runs out of memory at 16 users (133k tokens of context); 8 users
  fit.
- With one user, generation speed is almost the same for 8k prompts as for
  512-token prompts (dotted lines in the plot).
- The router serves one request at a time (`parallel = 1`). To use the
  concurrency above, raise `parallel`; each slot costs extra VRAM. `kev` is
  disabled on meshify because it lazy-loads ~5.2GB onto the same GPU.
- This measures the llama.cpp engine directly, not the HTTP server. The
  server also loads the vision projector and keeps a 1GiB `--fit` margin, so
  it holds slightly less context than the benchmark.

### 🧪 Sandboxed agent tasks (ax + Agent Substrate)

The cluster runs [google/ax](https://github.com/google/ax) as the task API on
top of [Agent Substrate](https://github.com/agent-substrate/substrate), which
runs each task in a gVisor sandbox. A task can be suspended into a snapshot
and resumed later. Both projects are pre-alpha: every image is built with Nix
and pinned by digest. Build notes and open items are in
[`docs/ax_stack_todo.md`](docs/ax_stack_todo.md). The full guide to writing,
deploying and operating Tasks is [`docs/ax_usage.md`](docs/ax_usage.md).

How it fits together:

- **Substrate** (`env/substrate.nix`, `hosts/de-msa2/substrate.nix`): API
  server, controller, `atelet` and the gVisor worker pool. Workers run only on
  the Zen-4 nodes (`desg0`, `de-n5`), because golden snapshots must not move
  between CPU generations. Snapshots go to rustfs (S3).
- **ax** (`env/ax.nix`, `pkgs/ax/`): `ax-server` (gRPC API), `ax-controller`
  and Redis in `ax-system`. The API is at `ax.k3s.lan:80` (plaintext h2c
  through traefik). It is also on the homepage under *AI*.
- **Default task image**: tasks without `spec.image` run the Nix-built
  `ax-task-runner`. It ships `git`, `curl`, the fleet CA and the
  [`pi`](https://pi.dev) coding agent, which is preconfigured for Qwen3.8 on
  desg0's SGLang (`OPENAI_BASE_URL=http://192.168.0.13:8000/v1`).
- **ax objects** (`manifests/ax/`): Gateways, Workspaces and Tasks live in
  ax's Redis, not in Kubernetes. ArgoCD does not apply them. Use `ax_apply`.

#### Client-side usage

Every Home Manager host has the `ax` and `kubectl-ate` CLIs (`home/home.nix`).
There are two ways to reach the server:

| Where | How ax connects | What works |
| --- | --- | --- |
| tensorbook (no fleet kubeconfig) | `AX_SERVER=ax.k3s.lan:80`, set in nushell | `apply`, `get`, `describe`, `watch`, `suspend`, `resume`, `delete` |
| de-msa2, meshify (as `m`) | port-forward through the fleet kubeconfig (`home/k3s_kubeconfig.nix`) | everything, including `ax ssh` and `kubectl ate` |

`ax ssh` and `kubectl ate` always need a kubeconfig, because they tunnel to
`atenet-router`. Do not run `ax` with `sudo`: sudo keeps `HOME` and leaves
root-owned `~/.kube` and `~/.ax` behind. In a shell other than nushell on
tensorbook, export `AX_SERVER=ax.k3s.lan:80` first.

Apply the shared objects (Gateways, Models, Workspaces), then a Task:

```sh
nix run .#ax_apply                                    # everything shared in manifests/ax/
nix run .#ax_apply -- manifests/ax/task-smoke-pi.yaml # one Task
```

A minimal Task that lets pi work on a cloned repo:

```yaml
apiVersion: ax.io/v1alpha1
kind: Task
metadata:
  name: smoke-pi
  atespace: default
spec:
  command: [bash, -c, 'pi -p --no-session "Summarize this repo into /workspace/summary.md"']
  workspaces:
    - name: monty-persona # cloned into /workspace, the working directory
  gateway:
    name: lan-llm         # egress to desg0 (SGLang) and Forgejo
  debug: true             # needed for `ax ssh`
```

Watch and inspect it:

```sh
ax get tasks
ax watch task smoke-pi        # "Running" is reported as final; check the result with ax ssh
ax ssh smoke-pi -- cat /workspace/summary.md
ax suspend task smoke-pi      # snapshot; `ax resume task smoke-pi` continues
ax delete task smoke-pi       # also removes the Substrate actor
```

Gotchas:

- Delete a Task before you re-apply it under the same name. Otherwise
  Substrate resumes the old actor, with its old image and snapshot.
- The Gateway egress allowlist is recorded but not enforced yet (no egress
  gateway is deployed), so sandbox egress is allow-all.
- Pods can't resolve `*.k3s.lan` names except `forgejo.k3s.lan`. Use LAN IPs
  for other services.
- To ship a new runner image, run `nix run .#ax-push-images` (after
  `skopeo login --tls-verify=false de-msa2:2999`) **before** you push the
  re-rendered manifests. Otherwise the controller points at a digest that is
  not in the registry yet.

### 📦 Fleet Nix binary cache (attic)

The fleet's store paths live in [attic](https://github.com/zhaofengli/attic)
on `de-msa2` (`hosts/de-msa2/attic.nix`), exposed at `https://attic.k3s.lan`
through the cluster ingress. Every host lists it as its first substituter
(`modules/base_system.nix`), with `cache.nixos.org` appended after; the
`nixos` cache is public, so pulls need no token — only the per-cache
signing key.

`desg0` keeps it stocked: the `nixos-cache-builder` timer
(`modules/nixos_cache_builder.nix`) runs daily at 04:00 — clone the repo,
`nix flake update`, build every host's `system.build.toplevel`, `attic push`
the results, and only then commit and push the new `flake.lock`. A lock that
does not build is never committed.

Since it updates the lock on every run, that timer is also the fleet's canary
for upstream nixpkgs changes — it breaks the day nixpkgs marks a package we
install as insecure, renames an option or drops a package. A failing host no
longer aborts the run: the other hosts are still built and pushed, then a `pi`
agent gets the build log, diagnoses the breakage, patches it, checks that every
host still evaluates and pushes a `cache-mechanic/fix-*` branch for review
(same pattern as `hosts/de-msa2/clanker-bot.nix`). It never pushes to `main`,
so no unreviewed LLM edit can reach a host's next rebuild.

Alongside it, `attic-watch-store` uploads
every new path that lands in `desg0`'s store, so remote builds from the
laptops (via `modules/remote_builder.nix`) end up in the cache too.
Retention is enforced by GC: every 12 hours, paths not pulled for 3 months go.

![Nix binary cache — attic on de-msa2](docs/diagrams/nix-cache-attic.visual-check.2048x1320.dark.png)

An explorable version with guided views is in
[`docs/diagrams/nix-cache-attic.html`](docs/diagrams/nix-cache-attic.html).

### 🏠 Self-hosted services

A curated set of self-hosted apps, each a NixOS module, fronted over HTTPS
through the cluster ingress where it matters:

**ntfy** (push notifications) · **forgejo** (git + actions + LFS) · **grafana**
(dashboards) · **vikunja** (tasks) · **attic** (nix binary cache) ·
**polaris** (music) · **calibre-web** (ebooks) ·
**mealie** (recipes) · **immich** (photos) · **searx** (search) · **readeck** ·
**uptime-kuma** · and more.

### 🖱️ Hyprland desktops with Home Manager

Laptops run Hyprland managed by Home Manager (`home/home_hyprland.nix`): a
curated terminal set, `helix` editor, `yazi` file manager, `waybar`,
animated wallpapers via `awww`, keyboard-driven mouse control via `stochos`,
and per-host home configs (`home/<host>.nix`).

### 🔑 Hardware & trust

`yubi_key.nix` for GPG/SSH, `k3s_nvidia.nix` for container GPU passthrough,
`virtualization_host.nix` for libvirt VMs (`vms/tor.nix`, `vms/waterfox.nix`),
`backup.nix` / `backup_home_to_remote.nix` for off-host backups.

---

## Layout

```
hosts/        one dir per machine — its configuration.nix + host-local services
modules/      reusable NixOS modules (base system, k3s, AI, networking, desktop)
home/         Home Manager configs (shell, editors, Hyprland, per-host tweaks)
env/          nixidy cluster environment: argocd, cert-manager, host_ingress, homepage, substrate, ax
manifests/    rendered k8s YAML (auto-generated, committed for ArgoCD)
secrets/      agenix-encrypted secrets
scripts/      small nix scripts (wake-on-lan, forgejo starred sync, app list)
vms/          libvirt VM definitions
flake.nix     the single entry point for every host and the nixidy env
```

## Applying a Configuration

Rebuild any host:

```sh
sudo nixos-rebuild switch --flake .#meshify
```

Or with [nh](https://github.com/nix-community/nh) for a friendlier flow:

```sh
nh os switch .
```

Reconcile the whole k3s cluster (renders + pushes manifests; ArgoCD syncs):

```sh
nix run .#nixidy -- switch .#prod
```

## Updating

Pull the newest nixpkgs and rebuild:

```sh
nix flake update
sudo nixos-rebuild switch --flake .#<host> --upgrade-all
```

Update a single input:

```sh
nix flake lock --update-input nixpkgs-unstable
```

Inspect flake metadata:

```sh
nix flake metadata .
```

## Cleaning the Store

```sh
nix-store --gc                      # manual GC
nh clean all --keep 5               # keep the last 5 boot generations
```

## Tips & Tricks

**Cached evaluation errors** — if you hit `error: cached failure of attribute
'nixosConfigurations.<host>…'`, bypass the eval cache:

```sh
--option eval-cache false
```

**Why does X depend on Y?** (e.g. an insecure package pulled in transitively):

```sh
nix why-depends /run/current-system \
  $(nix-build '<nixpkgs>' -A electron_35 --no-out-link)
```

**Exposing a new host-local service at `*.k3s.lan`** — add one entry to the
`services` list in `env/host_ingress.nix`, add the hostname to
`modules/base_system.nix`, set the service's base URL. Done.

## License

MIT.
