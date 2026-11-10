# Bifrost LLM gateway: integration plan

Status: planned, nothing is deployed. Research done 2026-11-10 (agent
memory tag `llm_gateway`).

Goal: put one gateway in front of the sglang server on desg0 and OpenRouter,
so that:

- every request and response is stored in a database,
- metrics go to VictoriaMetrics, logs go to VictoriaLogs, and alerts go
  through vmalert -> alertmanager -> ntfy (`hosts/de-msa2/alerting.nix`),
- OpenRouter spend has a daily AND a weekly cap,
- each client has its own API key (Bifrost calls them "virtual keys", VK).

Upstream:
- https://github.com/maximhq/bifrost (Go, Apache-2.0)
- https://docs.getbifrost.ai (raw docs: `docs/` in the repo, branch `dev`)
- Image `docker.io/maximhq/bifrost`, `v2.5.1` was the latest tag on
  2026-11-10. Pin it by digest, as we do for Substrate: the project releases
  often and changed its config schema this year (e.g. the `budgets` array).

Legend: `[ ]` open, `[x]` done, `[-]` dropped.

---

## Why Bifrost

| Need | Bifrost | Why this beats the alternatives |
|---|---|---|
| Message store | `logs_store`: SQLite, Postgres or ClickHouse, optional S3 offload | LiteLLM can store prompts only in Postgres. At our volume (below) ClickHouse is the better home. |
| Daily + weekly OpenRouter cap | One global "model limit" (`scope=global, provider=openrouter, model=*`) with `budgets = [1d, 1w]`, optionally `calendar_aligned` | LiteLLM's `provider_budget_config` has one window per provider and keeps spend in memory unless Redis is set up. |
| sglang | Native `sgl` provider, `/v1/models` passthrough | pi discovers models through `/v1/models`, so discovery keeps working. |
| Metrics | `/metrics`: cost, tokens, TTFT, ITL, overhead, `error_type` taxonomy; OTel GenAI traces | Fits the VictoriaMetrics scrape model directly. |
| Keys | Virtual keys `sk-bf-*` with provider allowlist, budgets, rate limits, per-key content-logging switch | |
| Nix | Upstream flake has `nixosModules.bifrost`; Helm chart; `config.json` can be authoritative | Git stays the source of truth. |

Rejected: Portkey (OSS logging and budgets are still in the 2.0
pre-release), Helicone (maintenance mode since the Mintlify acquisition,
2026-03), TensorZero (clients must send `tensorzero::model_name::...` as the
model id), Envoy AI Gateway / agentgateway (no message store).

Fallback if Phase 0 fails: LiteLLM. It is in nixpkgs as `services.litellm`
(1.108.0), accepts any model alias and passes extra parameters through.

---

## Facts that drive the design

- **Traffic** (VictoriaMetrics, `sglang:*`, 7 days to 2026-11-10):
  136.8k requests/week (~19.5k/day), 8.85B prompt tokens/week (~65k per
  request), 85M generated tokens/week.
- **Storage**: Bifrost stores the full input history in every log row. At
  ~4 bytes/token this is about **35 GB/week of raw text**. This is an
  estimate; Phase 0 measures the real number. Retention is mandatory, and
  ClickHouse is the target store.
- **Long requests**: the header of `hosts/desg0/sglang_qwen3_container.nix`
  records TTFT up to 362 s (16 agents x 100k context). Bifrost's defaults
  (`core/schemas/provider.go`) would cut these requests:
  `default_request_timeout_in_seconds = 300` and
  `stream_idle_timeout_in_seconds = 120` (no stream chunk arrives before
  the first token). Defaults that are fine: `max_retries = 0` (keep it: a
  retried 200k prefill doubles GPU load), concurrency 1000, buffer 5000.
- **sglang-specific parameters**: `modules/ai/pi-sglang-provider.nix`,
  `oh-my-pi.nix` and `prime-agent.nix` send `chat_template_kwargs` to
  toggle thinking. Bifrost drops unknown fields unless the request carries
  the header `x-bf-passthrough-extra-params: true`.
- **Model ids**: Bifrost uses `provider/model`, e.g.
  `sgl/RadixArk/Qwen3.8-27B-NVFP4`. Static aliases exist (v1.5+). Whether
  an id without the prefix works is an open question.
- **OSS limits**: one node only (state is held in memory; multi-node sync
  is Enterprise). Scraping `/metrics` needs admin basic auth once auth is
  on (API-key scraping is Enterprise). There is no "remaining budget"
  gauge, so alerts work from `bifrost_cost_total`.
- **Cluster secrets**: there is no secret operator. nexus creates k8s
  Secrets by hand and references them with `secretKeyRef`.

---

## Decisions (defaults; confirm in Phase 0)

| Topic | Choice | Why | Alternative |
|---|---|---|---|
| Where | Pod in k3s, nixidy app `env/bifrost.nix` in this repo, namespace `llm-gateway` | vlagent ships pod logs to VictoriaLogs, ArgoCD self-heals, traefik + `k3s-lan-ca` give TLS | NixOS service on de-msa2 from the upstream flake module, with agenix secrets. Logs then stay in journald. |
| Manifests | Plain nixidy resources: Deployment (1 replica, `Recreate`), PVC, Service, Ingress, ConfigMap with `config.json` | The chart is not in nixhelm; one container is easy to write by hand and we avoid chart churn | `lib.helm.downloadHelmChart` from `https://maximhq.github.io/bifrost/helm-charts` |
| Node | Pin to de-msa2 | `local-path` PVCs bind to one node; de-msa2 is always on and already runs the observability stack | |
| `config_store` | SQLite on the PVC | OSS is single-node anyway; budget usage survives restarts; no database to run | Postgres on de-msa2 (`services.postgresql` already runs for attic) |
| `logs_store` | Phase 1: SQLite with short retention, to measure. Phase 3: ClickHouse database `bifrost` in the nexus ClickHouse | Volume (see above) | Postgres with retention |
| Config source | `source_of_truth = "config.json"` with the config store enabled | Git wins on every start; UI edits are only for experiments | `split` (default) keeps UI edits |
| Auth | `enforce_auth_on_inference = true`; admin basic auth for UI and `/metrics` | Every request is attributed to a VK | |
| Hostname | `llm.k3s.lan`; in-cluster clients use `bifrost.llm-gateway.svc.cluster.local` | Same pattern as `ax.k3s.lan` | |
| Budget numbers | One Nix `let` binding used by both `config.json` and the alert rules | Gateway caps and alert thresholds cannot drift apart | |

---

## Phase 0: Proof of concept (no client changes)

Run Bifrost by hand on de-msa2 with podman (pinned digest), SQLite for both
stores, an `sgl` provider pointing at `http://192.168.0.13:8000` and an
`openrouter` provider. Use a test OpenRouter key with an OpenRouter-side
limit of $1/day, so a mistake cannot cost money.

- [ ] `/v1/models` lists `sgl/RadixArk/Qwen3.8-27B-NVFP4`. Check whether the
      id without the prefix works, or whether a static alias makes it work.
      (agent-symbiont checks the id against `/v1/models`.)
- [ ] `chat_template_kwargs` reaches sglang with
      `x-bf-passthrough-extra-params: true`: thinking on and off must give
      different outputs. Look for a server-side way to make passthrough the
      default.
- [ ] pi works end to end through the gateway
      (`pi -p --no-session --thinking low "..."`): streaming, tool calls,
      `reasoning_content`.
- [ ] A cold ~200k-token prompt completes with
      `default_request_timeout_in_seconds = 900` and
      `stream_idle_timeout_in_seconds = 600` on the `sgl` provider. Find
      out whether sglang sends anything on the stream before the first token.
- [ ] Budget: a global model limit for openrouter with
      `budgets = [{1d, $0.05}, {1w, $0.10}]`. Go over it and record the HTTP
      status, the `error_type` label value and the error body. sglang
      traffic must keep working.
- [ ] Virtual keys can be declared in `config.json` with fixed values (from
      env), so their secrets can live in agenix. If not: create them once
      through the API and store the values in agenix.
- [ ] Budget usage survives a restart with `source_of_truth = "config.json"`.
- [ ] Measure bytes per logged request in SQLite under real traffic (point
      one busy client at the PoC for a day). Extrapolate to 136.8k/week.
- [ ] Measure `bifrost_overhead_latency_microseconds` and RSS with 12
      concurrent streams (sglang's `--max-running-requests`).
- [ ] Write the results into this file and decide: go, or fall back to
      LiteLLM.

## Phase 1: Deploy in k3s (no clients yet)

- [ ] `env/bifrost.nix`, imported in `env/prod.nix`: Namespace, PVC
      (`local-path`), ConfigMap (`config.json` rendered from Nix),
      Deployment (pinned digest, `nodeSelector` de-msa2, `strategy:
      Recreate`, liveness/readiness probes (take the health path from
      the upstream chart), CPU and memory requests
      AND limits: the 2026-06-27 greptimedb incident shows why), Service,
      Ingress (`cert-manager.io/cluster-issuer: k3s-lan-ca`, traefik; copy
      from `env/ax.nix`).
- [ ] `config.json`:
  - `sgl` provider: the timeouts from Phase 0, `max_retries = 0`. Use the
    IP, as `pkgs/ax/default.nix` does, because pods may not resolve `desg0`.
  - `openrouter` provider: key `env.OPENROUTER_API_KEY`, with a model
    allowlist so a typo cannot reach an expensive model.
  - Global model limit for openrouter (daily + weekly budgets).
  - Client settings: `enforce_auth_on_inference`, log retention, JSON logs.
- [ ] Secret `bifrost-secrets` (OpenRouter key, admin password, encryption
      key, later the ClickHouse password), created by hand as in nexus.
      Write the exact `kubectl create secret ... --dry-run=client -o yaml |
      kubectl apply -f -` command into `env/bifrost.nix`.
- [ ] `llm.k3s.lan`: add it to `networking.hosts` in
      `modules/base_system.nix`, and add `gethomepage.dev/*` annotations.
- [ ] Render (`nix run .#nixidy -- switch .#prod`). Put unrelated manifest
      drift in its own revision (`jj restore manifests/prod/<app>`).
- [ ] Run a smoke test through `https://llm.k3s.lan` with a test VK.

## Phase 2: Observability

- [ ] Scrape job `bifrost` in `hosts/de-msa2/prometheus.nix`: pod role in
      namespace `llm-gateway` (copy `substrate_scrape_configs`), with
      `basic_auth.password_file` from an agenix secret on de-msa2.
      `ScrapeTargetDown` then covers it automatically.
- [ ] Logs: confirm that vlagent ships them
      (`kubernetes.pod_namespace:"llm-gateway"` in VictoriaLogs).
- [ ] Alert group `llm-gateway` in `hosts/de-msa2/alerting.nix`:
  - `BifrostDown`: `up{job="bifrost"} == 0` for 2m, `critical`. Every
    migrated agent loses LLM access when the gateway is down.
  - `OpenRouterSpendHigh`:
    `sum(increase(bifrost_cost_total{provider="openrouter"}[1d])) > 0.8 * <daily>`,
    and the same over `[7d]` against the weekly budget. These are rolling
    windows; the gateway budget may be calendar-aligned.
  - `GatewayBudgetRefusals`: `increase(bifrost_error_requests_total{error_type=~"policy_.*"}[15m]) > 0`.
    Use the exact value recorded in Phase 0.
  - `GatewayUpstreamErrors`: rate of `error_type=~"provider_.*"` divided by
    `bifrost_upstream_requests_total` above 5% for 10m.
  - `SglangKeyDown`: `bifrost_provider_key_up{provider="sgl"} == 0` for 5m.
- [ ] Dashboard `hosts/de-msa2/dashboards/bifrost.json`:
  - requests by VK and provider,
  - OpenRouter cost per day and per week against the budgets,
  - TTFT and ITL p50/p95 per provider,
  - gateway overhead,
  - errors by `error_type`, active requests.

  Validate each `expr` against `http://de-msa2:9003/api/v1/query`.
- [-] OTel traces: deferred. Grafana has the Tempo plugin, but no
      Tempo/OTLP backend runs.

## Phase 3: Message store at scale

- [ ] Add a ClickHouse database `bifrost` and user `bifrost` in nexus
      (`env/prod.nix`, `clickhouse.users`, like `venue_registry`). Store the
      password in `bifrost-secrets`.
- [ ] Switch `logs_store` to `clickhouse`
      (`clickhouse.clickhouse.svc.cluster.local:9000`, native protocol). Set
      `retention_days` from the Phase 0 measurement and the free space on
      `nvme_pool/clickhouse` (ZFS, daily snapshots only, see
      `hosts/de-msa2/zfs_pool.nix`).
- [ ] Measure ClickHouse's compression ratio on real rows. Successive agent
      turns repeat the same prefix, but they are rarely adjacent in a block,
      so do not assume a high ratio.
- [ ] If it still grows too fast: use `object_storage` offload to rustfs, or
      a shorter retention.

## Phase 4: Migrate clients

Migrate one client per revision, and keep the direct sglang URL in a comment
for rollback. Each client gets its own VK: NixOS clients from agenix, cluster
clients from a k8s Secret. Clients that send `chat_template_kwargs` also send
the passthrough header.

| Client | Where | Notes |
|---|---|---|
| pi (all hosts) | `vllmBaseUrl` in `hosts/{meshify,tensorbook,de-msa2,de-n5,desg0,razerblade}/configuration.nix`; provider in `modules/ai/pi-sglang-provider.nix` | Add VK + passthrough header to the provider. The discovery `curl` (`modules/ai/pi-agent.nix:63`) needs the auth header too. |
| oh-my-pi | `modules/ai/oh-my-pi.nix`, desg0 `defaultModel` | Model id gets the `sgl/` prefix unless aliases work. |
| prime-agent | `modules/ai/prime-agent.nix` | |
| nixos_cache_builder repair agent | `hosts/desg0/configuration.nix` (`agent_model`) | Uses pi on desg0. |
| deepseek-harness | `home/deepseek-harness.nix` (`sglang-desg0` route) | |
| ax task runner | `pkgs/ax/default.nix` (`llmBaseUrl`, `OPENAI_BASE_URL`) | Do NOT set `OPENAI_API_KEY` (pi then lists the OpenAI catalog). Put the VK into the pi provider's `models.json` instead. |
| Open WebUI | `hosts/desg0/open_webui.nix` (`inferenceUrl`) | |
| nubuddy | `pkgs/nubuddy.nix` | |
| Python env | `home/python.nix` | |
| venue-registry weekly job | `hosts/de-msa2/venue-registry.nix` | Find out which agent and endpoint it uses. |
| agent-symbiont (nexus) | `agent-symbiont/config_files/*.ron` (`inference_target.base_url`, `model`) | Probably most of the traffic. Migrate last, after Phase 3. Its `/v1/models` check must accept the new id. |

## Phase 5: OpenRouter

- [ ] Create a dedicated OpenRouter key for the gateway with `limit` +
      `limit_reset: weekly`, slightly above the gateway's weekly budget.
      This is the hard cap: the gateway checks budgets before a request
      starts, so requests already in flight can go over.
- [ ] Choose the OpenRouter models (allowlist on the provider key) and the
      VKs that may use OpenRouter. Give those VKs their own budgets.
- [ ] Compare Bifrost's cost numbers with OpenRouter's activity page after
      a week. If they differ, use custom pricing.
- [-] Custom pricing for `sgl` that mirrors the OpenRouter prices in
      `hosts/de-msa2/dashboards/sglang.json`: only if every VK budget is
      scoped to `provider=openrouter`. Otherwise local traffic would use up
      the VK budgets.

---

## Rollback

Each client migration is one revision: revert it to go back to
`http://desg0:8000/v1`. To retire the gateway, remove `env/bifrost.nix`.
nixidy Applications have no finalizer, so delete the namespace by hand.

## Open questions

- Do model ids without the `provider/` prefix work, through aliases or
  otherwise? If yes, agent-symbiont needs no config change.
- Is there a server-side default for extra-parameter passthrough?
- Can virtual-key secrets be fixed in `config.json`?
- Does sglang send anything on a stream before the first token? This sets
  the minimum `stream_idle_timeout_in_seconds`.
- Out of scope for now: putting the llama-cpp router on meshify and
  minimax-music3 behind the gateway. The `sgl` provider has no audio
  endpoints.
