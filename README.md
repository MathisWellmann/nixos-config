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
| `meshify` / `superserver` / `poweredge` / `elitedesk` / `de-n5` | servers & nodes |
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

`modules/ai/` declares a battery of local LLM serving options: `ollama`,
`vllm_cuda_container`, `tensorrt_llm_container`, `llama-cpp`, a
`hermes-agent` runner, `qwen_code`, and a `pi-agent` harness. The
`remote_builder.nix` module turns GPU hosts into distributed nix builders over
SSH.

### 🏠 Self-hosted services

A curated set of self-hosted apps, each a NixOS module, fronted over HTTPS
through the cluster ingress where it matters:

**ntfy** (push notifications) · **forgejo** (git + actions + LFS) · **grafana**
(dashboards) · **vikunja** (tasks) · **harmonia**
(local nix binary cache) · **polaris** (music) · **calibre-web** (ebooks) ·
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
env/          nixidy cluster environment: argocd, cert-manager, host_ingress, homepage
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
