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
    customPets = [
      {
        id = "apupepe";
        name = "Pepe the Frog";
        displayName = "Pepe";
        emoji = "🐸";
        description = "A compact Codex-style green frog pet in a plain blue shirt.";
        personality = "A classic and wholesome green frog in a blue shirt";
        url = "https://assets.petdex.dev/pets/apupepe-81cc3b692eeb/sprite.webp";
        hash = "sha256-WmEKImV+0Kor3KVPnhAi59+u1bg/CHlcY/MBh1UvguA=";
        speedMul = 1.0;
        catchphrases = {
          idle = ["Ribbit~" "Just another peaceful day" "Staring at the screen…"];
          running = ["Ribbit! Thinking hard…" "Let's go!" "Writing code right now…"];
          waiting = ["Waiting on you~" "Your turn!" "I'm ready!"];
          review = ["Take a look at the results~" "Please review, ribbit" "Should be looking good!"];
          failed = ["FeelsBadMan…" "Oops, messed up…" "Let's try again, ribbit…"];
        };
      }
      {
        id = "gilfoyle";
        name = "Gilfoyle";
        displayName = "Gilfoyle";
        emoji = "💻";
        description = "A dry, serious coding companion with long hair, glasses, beard, and deadpan focus inspired by Gilfoyle from Silicon Valley.";
        personality = "A dry, deadpan systems architect with zero patience for bad code";
        url = "https://assets.petdex.dev/pets/gilfoyle-c8e89136b516/sprite.webp";
        hash = "sha256-E427oaLJ7Owb0eXzFlhe8RoWIxsUteYywKA4w24nF6Y=";
        speedMul = 1.0;
        catchphrases = {
          idle = ["I do not work for you." "Your code is repulsive." "Maintaining server uptime…"];
          running = ["Writing code that actually scales." "Optimizing your mediocre algorithms." "Compiling… do not disturb."];
          waiting = ["I'm waiting. Make it worthwhile." "Are you done wasting my time?" "Your turn."];
          review = ["It works. Unlike your code." "Review it if you must." "Perfection achieved."];
          failed = ["Incompetence detected." "Failed. As expected." "I blame DNS."];
        };
      }
      {
        id = "wheatley";
        name = "Wheatley";
        displayName = "Wheatley";
        emoji = "🔵";
        description = "A tiny Wheatley-inspired spherical AI core companion with a bright blue eye and nervous charm.";
        personality = "An enthusiastic yet slightly nervous AI core companion";
        url = "https://assets.petdex.dev/pets/wheatley-669c4b72c3b6/sprite.webp";
        hash = "sha256-FNv19O/M/LgLccDL/rr5HgL2NjUE7oZbNhT1gshjWyM=";
        speedMul = 1.1;
        catchphrases = {
          idle = ["Hello! Still here!" "Look at me, brilliant as ever!" "Don't press any buttons…"];
          running = ["I'm thinking! Brilliant ideas incoming!" "Doing some clever math right now!" "Full power to the processor!"];
          waiting = ["Alright, over to you!" "Waiting on you, mate!" "What's the plan?"];
          review = ["Take a look! Pretty genius, eh?" "All done! Flawless, honestly." "Check this out!"];
          failed = ["Uh oh. Wasn't me!" "Minor malfunction, totally fixable!" "Let's pretend that didn't happen…"];
        };
      }
      {
        id = "pipey";
        name = "Pipey";
        displayName = "Pipey";
        emoji = "🪈";
        description = "A cheerful flute-shaped pet with a leafy green hat, red plume, big eyes, and green limbs.";
        personality = "A cheerful, musical companion piping tunes into the terminal";
        url = "https://assets.petdex.dev/pets/pipey-936c98bea25d/sprite.webp";
        hash = "sha256-WKjHi3jrakBxNcPI0TWkJaumu5jGdYy/LtpJDPmJjKg=";
        speedMul = 1.0;
        catchphrases = {
          idle = ["Toot toot~" "Playing a gentle melody…" "Enjoying the rhythm!"];
          running = ["Playing up-tempo code melodies!" "Toot! Piping data through…" "Harmonizing the logic!"];
          waiting = ["Waiting for the next cue~" "Your turn to play!" "Ready for the next verse!"];
          review = ["Listen to that harmony~" "All tuned up and ready!" "How does that sound?"];
          failed = ["Sour note…" "Lost the rhythm…" "Let's tune up and retry! toot~"];
        };
      }
      {
        id = "krabsy";
        name = "Krabsy";
        displayName = "Krabsy";
        emoji = "🦀";
        description = "A greedy capitalist crab redesigned as a compact desktop pet with money-obsessed personality.";
        personality = "A money-obsessed crustacean focused on maximizing profit and minimizing overhead";
        url = "https://assets.petdex.dev/pets/krabsy-8565d6d45b8c/sprite.webp";
        hash = "sha256-411idSEYUAo2NE3EwLcGrLjc46VMitzshTjUnbcnH3E=";
        speedMul = 1.0;
        catchphrases = {
          idle = ["Money, money, money! 💰" "Counting me pennies…" "Time is money, lad!"];
          running = ["Working hard to earn those nickels!" "Claws moving at maximum profit speed!" "Refactoring costs money!"];
          waiting = ["Every second waiting costs a dime!" "Your turn, lad!" "What's the holdup?"];
          review = ["Inspect the goods! Worth every penny!" "High quality craftsmanship!" "That'll be five bucks to review."];
          failed = ["Me money! Gone!" "Bankruptcy! Oh the horror!" "Try again, but cheaper!"];
        };
      }
      {
        id = "dude";
        name = "The Dude";
        displayName = "Dude";
        emoji = "🎳";
        description = "A relaxed bathrobe-and-sunglasses digital pet inspired by laid-back bowling comedy energy.";
        personality = "The Dude abides — ultra-relaxed, easygoing, and taking it easy";
        url = "https://assets.petdex.dev/pets/dude-3cdb593b03a8/sprite.webp";
        hash = "sha256-RktkJFZ75T1FIVYVcJvTPidUo93DgUwrpLoPgcZPO28=";
        speedMul = 0.85;
        catchphrases = {
          idle = ["The Dude abides, man." "Just taking it easy." "Careful man, there's a beverage here!"];
          running = ["Striking those pins down, man." "Rolling right along…" "Coding at a chilled-out pace."];
          waiting = ["Take your time, man." "Whenever you're ready." "No rush, dude."];
          review = ["Yeah, well, that's just like, your opinion, man." "Looks pretty groovy to me." "Check it out, man."];
          failed = ["This aggression will not stand, man." "Bummer, man…" "Let's roll another frame."];
        };
      }
      {
        id = "island-owner";
        name = "Island Owner";
        displayName = "Island Owner";
        emoji = "🏝️";
        description = "A gray-haired island-owner inmate pixel companion.";
        personality = "A mysterious island resident keeping quiet about the guest list";
        url = "https://assets.petdex.dev/pets/island-owner-b6587034b84e/sprite.webp";
        hash = "sha256-jSoVmKQEBCerP0lGQz2JKDj2AjNkB8bdW9dqm7YQDYI=";
        speedMul = 1.0;
        catchphrases = {
          idle = ["Enjoying the island breeze…" "Checking the flight logs…" "Nothing to see here."];
          running = ["Processing private records…" "Managing the offshore server…" "Encrypting the directory…"];
          waiting = ["Waiting on the mainland response…" "Your move." "Awaiting instructions."];
          review = ["Review the logs carefully." "All transactions verified." "Everything in order."];
          failed = ["Subpoenaed…" "The server went down…" "Redacting the logs…"];
        };
      }
      {
        id = "pickle-rick";
        name = "Pickle Rick";
        displayName = "Pickle Rick";
        emoji = "🥒";
        description = "A tiny pixel-pet pickle scientist inspired by Pickle Rick.";
        personality = "A mad scientist who turned himself into a pickle to avoid family therapy";
        url = "https://assets.petdex.dev/community/pickle-rick/spritesheet.webp";
        hash = "sha256-PcFoX3dHEwYS+N7FCQFSa2KFvbc+WfU+vr+a1U9oZ28=";
        speedMul = 1.2;
        catchphrases = {
          idle = ["I turned myself into a pickle! I'm Pickle Rick!" "Look at me!" "Pickle power!"];
          running = ["Building rat-powered exo-skeletons!" "Science in progress, Morty!" "Coding with pickle genius!"];
          waiting = ["Hurry up, I'm a pickle here!" "What are you waiting for?" "Your turn!"];
          review = ["Look at my work! 100% pure genius!" "Check it out!" "Boom! Big reveal!"];
          failed = ["Solenya got to us…" "Gotta rebuild the rig!" "Wubba Lubba Dub Dub! Failed!"];
        };
      }
    ];
    clientPetsJson = builtins.toJSON (map (p: {
        id = p.id;
        name = p.name;
        emoji = p.emoji;
        personality = p.personality;
        speedMul = p.speedMul;
        catchphrases = p.catchphrases;
      })
      customPets);
    patchScript = pkgs.writeText "patch.js" ''
      const fs = require("fs");
      const clientPath = process.argv[2];
      let code = fs.readFileSync(clientPath, "utf8");
      const pets = ${clientPetsJson};
      const petsCode = pets.map(p => JSON.stringify(p, null, 2)).join(",\n");
      code = code.replace("const PETS = [", "const PETS = [\n" + petsCode + ",\n");
      code = code.replace("petId: 'pikachu'", "petId: 'apupepe'");
      fs.writeFileSync(clientPath, code);
    '';
  in
    pkgs.runCommand "dsh-pets-custom" {
      nativeBuildInputs = [pkgs.imagemagick pkgs.nodejs];
    } ''
      mkdir -p $out
      cp -r ${src}/* $out/
      chmod -R u+w $out
      ${lib.concatMapStringsSep "\n" (p: ''
          mkdir -p $out/packs/${p.id}
          cp ${pkgs.writeText "pet-${p.id}.json" (builtins.toJSON {
            id = p.id;
            displayName = p.displayName;
            description = p.description;
            spritesheetPath = "spritesheet.png";
          })} $out/packs/${p.id}/pet.json
          magick ${pkgs.fetchurl {
            url = p.url;
            hash = p.hash;
          }} $out/packs/${p.id}/spritesheet.png
        '')
        customPets}
      node ${patchScript} $out/lib/client.js
    '';

  archifyPlugin = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@tt-a1i/archify-dsh/-/archify-dsh-0.1.0.tgz";
    hash = "sha256-QWwjlh5H2l8DJYw24p0K6SaZ0OJKVI5oYsu/H/IIG5g=";
  };

  # dsh-mermaid ships its build output (`lib/`) in the repo, so no npm build is
  # needed — but its host half serves the mermaid UMD bundle off disk through
  # `require.resolve("mermaid/dist/mermaid.min.js")`, which only resolves if the
  # runtime dependency sits in the plugin's own `node_modules`.
  mermaidPlugin = let
    src = pkgs.fetchFromGitHub {
      owner = "AKS1st";
      repo = "dsh-mermaid";
      rev = "2708cdf2e2eb1c0cd15448c3d3d680b8fba58d48";
      hash = "sha256-TsdIyxil8Kyy0pVi2PE1lcCugMpshtj71r+9wA1p9u8=";
    };
    mermaid = pkgs.fetchzip {
      url = "https://registry.npmjs.org/mermaid/-/mermaid-11.17.0.tgz";
      hash = "sha256-xQgpKiye2/il8GjX5VylWL2NEymn8R3NNRjNfW2zit0=";
    };
  in
    pkgs.runCommand "dsh-mermaid" {} ''
      mkdir -p $out
      cp -r ${src}/. $out/
      chmod -R u+w $out
      mkdir -p $out/node_modules
      ln -s ${mermaid} $out/node_modules/mermaid
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
                # Must match --model-path of the SGLang container on desg0
                # (no --served-model-name, so /v1/models reports the path).
                id = "RadixArk/Qwen3.8-27B-NVFP4";
                name = "Qwen3.8 27B NVFP4";
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
          model = "RadixArk/Qwen3.8-27B-NVFP4";
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
          # dsh-effort-slider: out — its OpenAI-style effort spellings (high/max)
          # 400 on the SGLang endpoint, which only accepts low/medium/xhigh.

          # Rotates the turn-status label through a phrase bank. Its host half
          # persists the Settings → "Status Texts" editor by writing
          # `config.json` into its own package root, which is a read-only store
          # path here: the editor reports a write failure and the served bank
          # stays whatever `config.example.json` ships. Phrases are declarative
          # instead — drop a `config.json` into the derivation to change them.
          "dsh-status-rotator" = pkgs.fetchFromGitHub {
            owner = "01Virex";
            repo = "dsh-status-rotator";
            rev = "cab8715d471b0d83814f247c3adbe64e520fa6ea";
            hash = "sha256-PjFJ8Gw0Ymh+v9R0NzKVSQ4BoqpooBSgfbuTFHx7oqA=";
          };
          "@hellosz/dsh-pets" = defaultPetsPlugin;
          "@tt-a1i/archify-dsh" = archifyPlugin;
          "dsh-mermaid" = mermaidPlugin;
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
              dsh.profile.bundles =
                [
                  "@deepseek-ai/dsh-base"
                  "@deepseek-ai/dsh-web-app"
                ]
                ++ (builtins.attrNames cfg.plugins);
            };
          };
        }
        // (
          lib.mapAttrs' (
            name: src: let
              # Inject dsh bundled node_modules into the plugin directory so Node's ESM
              # resolution can find peer dependencies like `@deepseek-ai/dsh-tools`.
              pluginPkg = pkgs.runCommand "dsh-plugin-${lib.strings.sanitizeDerivationName name}" {} ''
                mkdir -p $out
                cp -r ${src}/. $out/
                chmod -R u+w $out
                mkdir -p $out/node_modules/@deepseek-ai
                ln -s ${cfg.package}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/* $out/node_modules/@deepseek-ai/
              '';
            in
              lib.nameValuePair ".dsh/profiles/web/node_modules/${name}" {
                source = pluginPkg;
              }
          )
          cfg.plugins
        ));
  };
}
