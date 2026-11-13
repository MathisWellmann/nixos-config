# Bifrost LLM gateway (https://github.com/maximhq/bifrost) in front of the
# sglang server on desg0. Plan and Phase 0 results: docs/bifrost_plan.md.
# Namespace `llm-gateway`, pinned to de-msa2. In-cluster clients use
# http://bifrost.llm-gateway.svc.cluster.local:8080/v1, off-cluster clients
# https://llm.k3s.lan/v1. Both need a virtual key (`Authorization: Bearer
# sk-bf-...`).
#
#   - Every request and response goes to ClickHouse (nexus, namespace
#     `clickhouse`, database and user `bifrost`; the grants are in nexus
#     `env/prod.nix`). Bifrost never runs CREATE DATABASE
#     (maximhq/bifrost#5340), so the initContainer does, with the image's
#     busybox wget over the HTTP port.
#   - `config.json` is rendered below and is authoritative
#     (`source_of_truth`): git wins on every start, UI edits are lost.
#   - The config store (virtual keys, budget usage, admin account) is SQLite
#     on a local-path PVC, so it survives restarts. OSS Bifrost runs on one
#     node only anyway.
#   - Secret `bifrost-secrets` from secrets/bifrost_env.age. No secret
#     operator runs in the cluster, so create it by hand on de-msa2, in
#     nixos-config/secrets:
#       kubectl create namespace llm-gateway --dry-run=client -o yaml | kubectl apply -f -
#       agenix -d bifrost_env.age | kubectl -n llm-gateway create secret generic bifrost-secrets \
#         --from-env-file=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
#     then `kubectl -n llm-gateway rollout restart deploy/bifrost`. Never change
#     BIFROST_ENCRYPTION_KEY: it encrypts the config store.
_: let
  ns = "llm-gateway";
  name = "bifrost";
  host = "llm.k3s.lan";
  # Digest of the multi-arch index. Pinned because upstream releases often and
  # changed its config schema this year.
  image = "docker.io/maximhq/bifrost:v2.5.1@sha256:5ec9873acaf1687556b6e4dd854b92b539d9debf87a5a683b66338648b84d3c8";
  port = 8080;
  dataDir = "/app/data";
  secretName = "bifrost-secrets";
  labels."app.kubernetes.io/name" = name;

  # Both settings below use it: the ClickHouse table TTL and Bifrost's own
  # cleanup job (default 365 days). Estimate (docs/bifrost_plan.md): ~35 GB
  # of raw text per week, against 1.7 TB free on nvme_pool (2026-11-13).
  retentionDays = 30;

  clickhouse = {
    host = "clickhouse.clickhouse.svc.cluster.local";
    nativePort = 9000;
    httpPort = 8123;
    database = "bifrost";
    user = "bifrost";
  };

  config = {
    "$schema" = "https://www.getbifrost.ai/schema";
    source_of_truth = "config.json";
    encryption_key = "env.BIFROST_ENCRYPTION_KEY";
    client = {
      enable_logging = true;
      enforce_auth_on_inference = true;
      log_retention_days = retentionDays;
      # /health pings the config and log stores by default. Then a ClickHouse
      # restart fails the liveness probe and kills every in-flight agent
      # request. Inference must keep working while only logging is down.
      disable_db_pings_in_health = true;
    };
    governance = {
      # Basic auth for the UI, the management API and /metrics.
      auth_config = {
        is_enabled = true;
        admin_username = "admin";
        admin_password = "env.BIFROST_ADMIN_PASSWORD";
      };
      # One key per client. The value comes from the Secret, so the key does
      # not change when the config store is rebuilt.
      virtual_keys = [
        {
          id = "smoke-test";
          name = "smoke-test";
          description = "Manual smoke tests of the gateway";
          value = "env.BIFROST_VK_SMOKE_TEST";
          provider_configs = [
            {
              provider = "sgl";
              allowed_models = ["*"];
              key_ids = ["*"];
            }
          ];
        }
      ];
    };
    config_store = {
      enabled = true;
      type = "sqlite";
      config.path = "${dataDir}/config.db";
    };
    logs_store = {
      enabled = true;
      type = "clickhouse";
      retention_days = retentionDays;
      config = {
        inherit (clickhouse) host database;
        port = toString clickhouse.nativePort;
        username = clickhouse.user;
        password = "env.CLICKHOUSE_PASSWORD";
      };
    };
    providers.sgl = {
      keys = [
        {
          name = "desg0";
          value = "";
          models = ["*"];
          weight = 1.0;
          # The IP, as in pkgs/ax: pods may not resolve `desg0`.
          sgl_key_config.url = "http://192.168.0.13:8000";
        }
      ];
      network_config = {
        # Defaults are 300 s and 120 s. TTFT reached 362 s with 16 agents at
        # 100k context (hosts/desg0/sglang_qwen3_container.nix), and a
        # stream may stay silent until the first token.
        default_request_timeout_in_seconds = 900;
        stream_idle_timeout_in_seconds = 600;
        # A retried 200k-token prefill doubles the GPU load.
        max_retries = 0;
        # Without it every request fails with "connection to private IP
        # 192.168.0.13 is not allowed" (SSRF guard, default off).
        allow_private_network = true;
      };
    };
  };
  configJson = builtins.toJSON config;
in {
  applications.${name} = {
    namespace = ns;
    createNamespace = true;
    resources = {
      configMaps.bifrost-config.data."config.json" = configJson;

      persistentVolumeClaims.bifrost-data.spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        # SQLite config store only; the logs live in ClickHouse.
        resources.requests.storage = "1Gi";
      };

      deployments.${name}.spec = {
        replicas = 1;
        # RWO local-path volume, and OSS Bifrost keeps budget and rate-limit
        # state in memory: never run two pods.
        strategy.type = "Recreate";
        selector.matchLabels = labels;
        template = {
          metadata = {
            inherit labels;
            # The config is a subPath mount, which never sees ConfigMap
            # updates: roll the pod instead.
            annotations."checksum/config" = builtins.hashString "sha256" configJson;
          };
          spec = {
            # The local-path PVC binds to the node of the first pod.
            nodeSelector."kubernetes.io/hostname" = "de-msa2";
            securityContext = {
              runAsNonRoot = true;
              runAsUser = 1000;
              fsGroup = 1000;
            };
            volumes = {
              data = {
                name = "data";
                persistentVolumeClaim.claimName = "bifrost-data";
              };
              config = {
                name = "config";
                configMap.name = "bifrost-config";
              };
            };
            initContainers.create-database = {
              inherit image;
              command = [
                "sh"
                "-c"
                ''
                  exec wget -qO- \
                    --header "X-ClickHouse-User: ${clickhouse.user}" \
                    --header "X-ClickHouse-Key: $CLICKHOUSE_PASSWORD" \
                    --post-data "CREATE DATABASE IF NOT EXISTS ${clickhouse.database}" \
                    http://${clickhouse.host}:${toString clickhouse.httpPort}/
                ''
              ];
              env.CLICKHOUSE_PASSWORD = {
                name = "CLICKHOUSE_PASSWORD";
                valueFrom.secretKeyRef = {
                  name = secretName;
                  key = "CLICKHOUSE_PASSWORD";
                };
              };
              securityContext = {
                allowPrivilegeEscalation = false;
                capabilities.drop = ["ALL"];
              };
            };
            containers.${name} = {
              inherit image;
              envFrom = [{secretRef.name = secretName;}];
              env = {
                LOG_STYLE = {
                  name = "LOG_STYLE";
                  value = "json";
                };
                # ~90% of the memory limit, so the GC works harder before
                # the OOM killer steps in.
                GOMEMLIMIT = {
                  name = "GOMEMLIMIT";
                  value = "1800MiB";
                };
              };
              ports.http = {
                name = "http";
                containerPort = port;
              };
              volumeMounts = {
                data = {
                  name = "data";
                  mountPath = dataDir;
                };
                config = {
                  name = "config";
                  mountPath = "${dataDir}/config.json";
                  subPath = "config.json";
                  readOnly = true;
                };
              };
              # Startup runs the config store and ClickHouse migrations.
              startupProbe = {
                httpGet = {
                  path = "/health";
                  port = "http";
                };
                periodSeconds = 5;
                failureThreshold = 60;
              };
              readinessProbe = {
                httpGet = {
                  path = "/health";
                  port = "http";
                };
                periodSeconds = 10;
              };
              livenessProbe = {
                httpGet = {
                  path = "/health";
                  port = "http";
                };
                periodSeconds = 30;
                timeoutSeconds = 5;
              };
              # Idle RSS was 85 MB in Phase 0. Each request holds up to ~1 MB
              # of prompt, also while it waits in sglang's queue.
              resources = {
                requests = {
                  cpu = "100m";
                  memory = "256Mi";
                };
                limits = {
                  cpu = "4";
                  memory = "2Gi";
                };
              };
              securityContext = {
                allowPrivilegeEscalation = false;
                capabilities.drop = ["ALL"];
              };
            };
          };
        };
      };

      services.${name}.spec = {
        selector = labels;
        ports.http = {
          name = "http";
          inherit port;
          targetPort = "http";
        };
      };

      ingresses.${name} = {
        metadata.annotations = {
          "cert-manager.io/cluster-issuer" = "k3s-lan-ca";
          "gethomepage.dev/enabled" = "true";
          "gethomepage.dev/name" = "Bifrost";
          "gethomepage.dev/group" = "AI";
          "gethomepage.dev/icon" = "mdi-transit-connection-variant";
          "gethomepage.dev/description" = "LLM gateway (sglang), logs to ClickHouse";
          "gethomepage.dev/pod-selector" = "app.kubernetes.io/name=${name}";
          "gethomepage.dev/siteMonitor" = "http://${name}.${ns}.svc.cluster.local:${toString port}/health";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              inherit host;
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    inherit name;
                    port.number = port;
                  };
                }
              ];
            }
          ];
          tls = [
            {
              hosts = [host];
              secretName = "${name}-tls";
            }
          ];
        };
      };
    };
  };
}
