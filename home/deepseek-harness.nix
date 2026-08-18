# DeepSeek Harness (`dsh`) — the agent CLI from the `llm-agents` flake input.
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

  defaultPetsPlugin = let
    src = pkgs.fetchFromGitHub {
      owner = "hellosz";
      repo = "dsh-pets";
      rev = "master";
      hash = "sha256-WNfdVsuek5mE+h/eenOYaNIENlujv6FwaAMJqulqMHo=";
    };
    apupepe-sprite = pkgs.fetchurl {
      url = "https://assets.petdex.dev/pets/apupepe-81cc3b692eeb/sprite.webp";
      hash = "sha256-WmEKImV+0Kor3KVPnhAi59+u1bg/CHlcY/MBh1UvguA=";
    };
    apupepe-pet-json = pkgs.writeText "pet.json" (builtins.toJSON {
      id = "apupepe";
      displayName = "Pepe";
      description = "A compact Codex-style green frog pet in a plain blue shirt.";
      spritesheetPath = "spritesheet.png";
    });
    patchScript = pkgs.writeText "patch.js" ''
      const fs = require("fs");
      const clientPath = process.argv[2];
      let code = fs.readFileSync(clientPath, "utf8");
      const pepeObj = `      {
          id: 'apupepe',
          name: '佩佩蛙 (Pepe)',
          emoji: '🐸',
          personality: '经典又治愈的蓝色短袖小青蛙',
          speedMul: 1.0,
          catchphrases: {
            idle: ['呱~', '今天也是平静的一天', '看着屏幕发呆中…'],
            running: ['呱呱！努力思考中', '冲呀！', '正在编写代码…'],
            waiting: ['等你呢呱~', '到你了', '我准备好啦'],
            review: ['看看写得怎么样？', '检查一下吧呱', '应该没问题吧'],
            failed: ['FeelsBadMan…', '呜呜搞砸了…', '再试一次呱…'],
          },
        },
  `;
      code = code.replace("const PETS = [", "const PETS = [\n" + pepeObj);
      code = code.replace("petId: 'pikachu'", "petId: 'apupepe'");
      fs.writeFileSync(clientPath, code);
    '';
  in
    pkgs.runCommand "dsh-pets-with-apupepe" {
      nativeBuildInputs = [pkgs.imagemagick pkgs.nodejs];
    } ''
      mkdir -p $out
      cp -r ${src}/* $out/
      chmod -R u+w $out
      mkdir -p $out/packs/apupepe
      cp ${apupepe-pet-json} $out/packs/apupepe/pet.json
      magick ${apupepe-sprite} $out/packs/apupepe/spritesheet.png
      node ${patchScript} $out/lib/client.js
    '';
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
        default = {
          vllm-desg0 = {
            displayName = "vLLM desg0";
            api = "openai-completions";
            baseURL = "http://desg0:8000/v1";
            apiKeyEnv = "VLLM_API_KEY";
            defaultContextWindow = 131072;
            defaultMaxTokens = 32768;
            models = [
              {
                id = "Qwen/Qwen3.8-27B-FP8";
                name = "Qwen3.8 27B FP8";
              }
            ];
          };
        };
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
        default = {
          provider = "vllm-desg0";
          model = "Qwen/Qwen3.8-27B-FP8";
        };
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

      dotenv = mkOption {
        type = types.attrsOf types.str;
        default = {
          VLLM_API_KEY = "unused-by-vllm";
        };
        description = ''
          Credentials written to `$DSH_HOME/.env`, the read-only fallback of
          `dsh-credentials-local` (resolution order: process environment >
          `$DSH_HOME/.credentials.yaml` > `<cwd>/.env` > `$DSH_HOME/.env`).

          This is how an `apiKeyEnv` reference is satisfied without depending on
          the login environment — `home.sessionVariables` does not reach a `dsh`
          started from a launcher or user unit, and the app never writes `.env`,
          only `.credentials.yaml`.

          Values land world-readable in the nix store, so this is for
          placeholders (an unauthenticated local server) only. Real keys belong
          in `.credentials.yaml` (the web Models page writes it) or in an
          agenix/sops secret.
        '';
        example = literalExpression ''{VLLM_API_KEY = "unused-by-vllm";}'';
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

      plugins = mkOption {
        type = types.attrsOf types.package;
        default = {
          "cyber-particle" = pkgs.fetchFromGitHub {
            owner = "AKS1st";
            repo = "dsh-cyber-particle";
            rev = "master";
            hash = "sha256-2FP4duo1rO4WfNMsDhq3uxU+6EqRst7tAgmNA0XHmCA=";
          };
          "@hellosz/dsh-pets" = defaultPetsPlugin;
        };
        description = ''
          Plugins installed into the `web` profile (`$DSH_HOME/profiles/web`).
          Each entry key is the plugin package name, and the value is the derivation
          containing the plugin's root directory (with `package.json`, `client.js`, etc.).
        '';
        example = literalExpression ''
          {
            "cyber-particle" = pkgs.fetchFromGitHub {
              owner = "AKS1st";
              repo = "dsh-cyber-particle";
              rev = "master";
              hash = "sha256-2FP4duo1rO4WfNMsDhq3uxU+6EqRst7tAgmNA0XHmCA=";
            };
          }
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file =
      lib.optionalAttrs (cfg.dotenv != {}) {
        ".dsh/.env".text = lib.concatLines (lib.mapAttrsToList (name: value: "${name}=${value}") cfg.dotenv);
      }
      // lib.optionalAttrs (patches != []) {
        # A profile init writes a placeholder patch file, so take an existing one
        # over instead of failing with "would be clobbered".
        ".dsh/cordis.patch.yml" = {
          force = true;
          source = yaml.generate "dsh-cordis.patch.yml" patches;
        };
      }
      // lib.optionalAttrs (cfg.plugins != {}) ({
        ".dsh/profiles/web/package.json" = {
          force = true;
          text = builtins.toJSON {
            name = "dsh-profile-web";
            private = true;
            dependencies = lib.mapAttrs (name: pkg: "${pkg}") cfg.plugins;
            dsh.profile.bundles = [
              "@deepseek-ai/dsh-base"
              "@deepseek-ai/dsh-web-app"
            ] ++ (builtins.attrNames cfg.plugins);
          };
        };
      } // (
        lib.mapAttrs' (name: src:
          let
            # Inject dsh bundled node_modules into the plugin directory so Node's ESM
            # resolution can find peer dependencies like `@deepseek-ai/dsh-tools`.
            pluginPkg = pkgs.runCommand "dsh-plugin-${lib.strings.sanitizeDerivationName name}" {} ''
              mkdir -p $out/node_modules/@deepseek-ai
              cp -r ${src}/* $out/
              chmod -R u+w $out
              ln -s ${cfg.package}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/* $out/node_modules/@deepseek-ai/
            '';
          in
          lib.nameValuePair ".dsh/profiles/web/node_modules/${name}" {
            source = pluginPkg;
          }
        ) cfg.plugins
      ));
  };
}
