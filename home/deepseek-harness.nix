# DeepSeek Harness (`dsh`) — the agent CLI packaged in `pkgs/deepseek-harness`.
#
# Home-manager module: installs the CLI and declares its configuration through
# the loader's *patch layer* instead of `~/.dsh/settings.yaml`.
#
# Why the patch layer: a dsh profile is a cordis loader entry list, composed at
# boot by applying patch lists in order — each bundle in the profile's
# `dsh.profile.bundles`, then `profiles/<name>/cordis.patch.yml`, then
# `$DSH_HOME/cordis.patch.yml` (this file: machine-local, applies to every
# profile), then `--patch` overlays. Those files are pure *inputs*: dsh reads
# and watches them (hot-reload) but never writes them, so a read-only store
# symlink stays authoritative. `settings.yaml`, by contrast, is app-owned state
# written with a temp-file + rename that silently replaces a symlink, so
# managing it from Nix loses either your edits or the app's.
#
# A patch row is `{id = <entry id>; <key> = <value>;}` and assigns keys onto the
# matched row — `config` is *replaced*, not merged — plus `{insert = [...];}` to
# add rows and `disabled = true;` to switch one off. A row id that matches
# nothing only warns, so check the composed tree with `dsh --dump-config`.
#
# Caveat: for entries backed by a settings namespace (`llm-pi-ai`,
# `agent-default-model`), a section in `~/.dsh/settings.yaml` overrides what is
# configured here. Keep those namespaces out of that file (the web UI's Models
# page writes them).
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.deepseek-harness;
  yaml = pkgs.formats.yaml {};

  # `llm-pi-ai` and `agent-default-model` carry no config worth preserving in
  # `@deepseek-ai/dsh-base`, so replacing their `config` wholesale is safe.
  patches =
    lib.optional (cfg.llmProviders != {}) {
      id = "llm-pi-ai";
      config.providers = cfg.llmProviders;
    }
    ++ lib.optional (cfg.defaultModel != null) {
      id = "agent-default-model";
      config = lib.filterAttrs (_: v: v != null) cfg.defaultModel;
    }
    ++ cfg.patches;
in {
  options = {
    programs.deepseek-harness = with lib; {
      enable = mkEnableOption "DeepSeek Harness (`dsh`) agent CLI";

      package = mkOption {
        type = types.package;
        default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
        defaultText = literalExpression "inputs.self.packages.\${system}.deepseek-harness";
        description = "The `dsh` package to install.";
      };

      llmProviders = mkOption {
        type = types.attrsOf yaml.type;
        default = {};
        description = ''
          Provider routes for `dsh-llm-pi-ai`, the generic adapter that serves
          OpenAI-completions, OpenAI-responses and Anthropic-messages endpoints.
          It is mounted dormant and wakes up per route declared here.

          A route outside dsh's built-in catalog must spell out `api`, `baseURL`
          and `models` (ids exactly as the endpoint's `/v1/models` reports
          them), and always declares api-key auth: set `apiKeyEnv` to an
          environment variable name even for an unauthenticated local server.
        '';
        example = literalExpression ''
          {
            my-vllm = {
              api = "openai-completions";
              baseURL = "http://localhost:8000/v1";
              apiKeyEnv = "VLLM_API_KEY";
              models = [{id = "Qwen/Qwen3.8-27B-FP8";}];
            };
          }
        '';
      };

      defaultModel = mkOption {
        default = null;
        description = "The provider/model new sessions start with (`agent-default-model`).";
        type = types.nullOr (types.submodule {
          options = {
            provider = mkOption {
              type = types.str;
              description = "Provider route, e.g. a key of `llmProviders`.";
            };
            model = mkOption {
              type = types.str;
              description = "Model id as the provider spells it.";
            };
            reasoningEffort = mkOption {
              type = types.nullOr (types.enum ["off" "minimal" "low" "medium" "high"]);
              default = null;
              description = "Thinking level, when the model offers one.";
            };
          };
        });
      };

      patches = mkOption {
        type = types.listOf yaml.type;
        default = [];
        description = ''
          Extra loader patch rows appended to `$DSH_HOME/cordis.patch.yml`,
          after the rows derived from `llmProviders` and `defaultModel`. Use
          `dsh --dump-config` to find entry ids and `--dump-default-config` for
          the untouched composition.
        '';
        example = literalExpression ''
          [
            # Turn a bundled row off.
            {
              id = "session-telemetry-otel";
              disabled = true;
            }
            # Re-configure one.
            {
              id = "tool-result-pruner";
              config.thresholdChars = 16384;
            }
          ]
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file.".dsh/cordis.patch.yml" = lib.mkIf (patches != []) {
      # A profile init writes a placeholder patch file, so take an existing one
      # over instead of failing with "would be clobbered".
      force = true;
      source = yaml.generate "dsh-cordis.patch.yml" patches;
    };
  };
}
