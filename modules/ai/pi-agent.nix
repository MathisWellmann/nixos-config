{
  baseUrl ? "http://localhost:1234/v1",
  enableAgentica ? false,
  agenicaPath ? "/home/m/symbolica/agentica-mcp-runtime",
  imageWidthCells ? 180,
  llamaServerUrl ? null,
  # OpenAI-compatible endpoint of a vLLM server, e.g. `http://meshify:8000/v1`.
  # When set, the `pi` wrapper queries `<vllmBaseUrl>/models` on every launch and
  # generates a `vllm` provider from whatever the server currently serves.
  vllmBaseUrl ? null,
  # Fallback model ids, used when the vLLM server is unreachable (e.g. still
  # loading weights) so `/model` keeps working.
  vllmModels ? [],
  # The served Qwen3.8-27B is multimodal (vision tower in the weights, SGLang
  # reports `has_image_understanding: true`). pi defaults custom models to
  # text-only input, which drops pasted images — so declare image input here.
  vllmVision ? true,
  # Fallback context window; discovery prefers the server's `max_model_len`.
  vllmContextWindow ? 262144,
  vllmMaxTokens ? 32768,
  # Default model for pi-rlm subagents (rlm.run without an explicit model).
  #   "auto"            — vllm/<first discovered model id>, re-derived from the
  #                       /v1/models query the wrapper already runs each launch.
  #   "provider/model"  — pinned, e.g. "vllm/RadixArk/Qwen3.8-27B-NVFP4".
  #   null              — leave pi-rlm's built-in heuristic in charge. It name-
  #                       matches "volume tiers" (haiku/flash/mini/...) across
  #                       ALL available models, which happily picks catalog
  #                       entries like "openrouter/...claude-haiku-4.5:batch"
  #                       that are batch-API-only and 404 on a normal request.
  # Exported as PI_RLM_SUBAGENT_MODEL (pi-rlm's override); children inherit
  # their parent's environment, so the whole fan-out tree runs on one model.
  subagentModel ? "auto",
}: {
  pkgs,
  inputs,
  ...
}: let
  inherit (pkgs) lib;
  effectiveLlamaServerUrl =
    if llamaServerUrl != null
    then llamaServerUrl
    else lib.removeSuffix "/v1" baseUrl;

  # vLLM speaks OpenAI Chat Completions, but has no `developer` role and no
  # `reasoning_effort`; Qwen-style thinking is toggled via `chat_template_kwargs`.
  vllmProvider = lib.optionalAttrs (vllmBaseUrl != null) {
    vllm = {
      baseUrl = vllmBaseUrl;
      api = "openai-completions";
      # Placeholder: vLLM is started without `--api-key`, but pi hides models
      # that have no auth configured.
      apiKey = "vllm";
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        thinkingFormat = "qwen-chat-template";
      };
      models =
        map (id: {
          inherit id;
          contextWindow = vllmContextWindow;
          maxTokens = vllmMaxTokens;
          reasoning = true;
          input = [ "text" ] ++ lib.optionals vllmVision [ "image" ];
        })
        vllmModels;
    };
  };

  pi-models-config = (pkgs.formats.json {}).generate "pi-agent-models.json" {
    providers = vllmProvider;
  };

  # Rewrites `models.json` on every `pi` launch: the static Nix-generated config,
  # with the `vllm` provider's model list replaced by live `/v1/models` output.
  writeModelsJson =
    if vllmBaseUrl == null
    then ''cp ${pi-models-config} "$models_json"''
    else ''
      discovered=$(${pkgs.curl}/bin/curl -fsS -m 3 "${vllmBaseUrl}/models" 2>/dev/null || true)
      if printf '%s' "$discovered" | ${pkgs.jq}/bin/jq -e '(.data // []) | length > 0' >/dev/null 2>&1; then
        printf '%s' "$discovered" | ${pkgs.jq}/bin/jq \
          --slurpfile base ${pi-models-config} \
          --argjson ctx ${toString vllmContextWindow} \
          --argjson maxTokens ${toString vllmMaxTokens} \
          --argjson vision ${toString vllmVision} \
          '$base[0] * {providers: {vllm: {models: [
             .data[] | {
               id: .id,
               reasoning: true,
               input: (["text"] + (if $vision then ["image"] else [] end)),
               contextWindow: (.max_model_len // $ctx),
               # Leave room for the prompt: vLLM rejects requests whose
               # prompt + max_tokens exceed `max_model_len`.
               maxTokens: ([$maxTokens, (((.max_model_len // $ctx) / 4) | floor)] | min),
             }
           ]}}}' > "$models_json.tmp.$$" \
          && mv "$models_json.tmp.$$" "$models_json" \
          || cp ${pi-models-config} "$models_json"
      else
        cp ${pi-models-config} "$models_json"
      fi
    '';

  pi-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

  # Token-rate pi extension — downloaded from npm at build time
  tokenRateSrc = pkgs.fetchzip {
    url = "https://registry.npmjs.org/token-rate-pi/-/token-rate-pi-1.0.2.tgz";
    sha256 = "sha256-dTe4f8kBZxvADJhLpPtlnJ/y3ebNFG77ws/oGliAQJA=";
  };
  tokenRateExt = pkgs.runCommand "pi-token-rate" {} ''
    mkdir -p $out
    cp ${tokenRateSrc}/token-rate.ts $out/
  '';

  # Pinned npm package; Pi loads its extension from the package manifest.
  piLlamaCppSrc = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-llama-cpp/-/pi-llama-cpp-0.9.1.tgz";
    sha256 = "sha256-dIXXkjcavmN8P3YFP1rXpnB4tNEDsR10vw6zn+YBQVA=";
  };

  # ponytail — lazy-senior-dev pi package (extension + skills)
  # Pinned to commit 45f7d2f (2026-06-17). Update the ref + hash to upgrade.
  ponytailSrc = pkgs.fetchzip {
    url = "https://github.com/DietrichGebert/ponytail/archive/45f7d2f83fb430a65fd512a98ad7b14d79e06636.tar.gz";
    sha256 = "sha256-BAwav7tf6RuHZ/A7TF/1k1TXWhYAdshlsYB3LbdgUD8=";
  };

  # pi-rlm — replaces the toolset with a single `execute` tool that runs
  # TypeScript in a persistent Bun evaluator; subagents are function calls.
  # Pinned npm package; Pi loads its extension from the package manifest.
  piRlmSrc = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@shift-labs/pi-rlm/-/pi-rlm-0.5.0.tgz";
    sha256 = "sha256-425Xn01A/HXDV121Ay1zt1gd1GolG+AP+38QyS1u+Ck=";
  };

  # acorn is pi-rlm's one runtime dependency. Pi loads local packages
  # straight from the store (no `npm install` at runtime) and only
  # virtualises its own bundled deps (typebox, pi-*) into the extension
  # module graph, so vendor acorn into the package's node_modules.
  piRlmAcorn = pkgs.fetchzip {
    url = "https://registry.npmjs.org/acorn/-/acorn-8.18.0.tgz";
    sha256 = "sha256-pHW24oi4w2MuWlkufOPIK2tYGdQ8om3SuegyCK8MGZc=";
  };
  piRlmPkg = pkgs.runCommand "pi-rlm-0.5.0" {} ''
    # cp -a copies the store's read-only directory mode into $out,
    # so make it writable before creating node_modules.
    cp -a ${piRlmSrc} $out
    chmod -R u+w $out
    mkdir -p $out/node_modules
    cp -a ${piRlmAcorn} $out/node_modules/acorn
  '';

  # Agentica MCP server config JSON
  agenticaConfigJson = pkgs.writeText "agentica-config.json" (builtins.toJSON {
    agentica = {
      command = "nix";
      args = [
        "develop"
        agenicaPath
        "--command"
        "uv"
        "run"
        "--project"
        agenicaPath
        "python"
        "-m"
        "agentica_mcp_runtime"
        "--config"
        "~/.claude/settings.json"
      ];
    };
  });

  # Agentica pi extension (TypeScript) - use mkDerivation to create a directory
  agenticaExt = pkgs.stdenv.mkDerivation {
    name = "pi-agentica";
    buildCommand = ''
      mkdir -p $out
      cat > $out/agentica.ts << 'EOF'
      import { Type } from "@sinclair/typebox";
      import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

      export default function (pi: ExtensionAPI) {
        const AGENTAICA_RUNTIME_PATH = "${agenicaPath}";
        const AGENTAICA_CONFIG = "${agenticaConfigJson}";
        const PYTHON = AGENTAICA_RUNTIME_PATH + "/.venv/bin/python";
        const MCP_HELPER = "${mcpHelper}";

        pi.registerTool({
          name: "agentica",
          label: "Agentica",
          description:
            "Execute Python code that can call MCP tools via the Agentica MCP Runtime. " +
            "MCP tools are available as async functions. Use `await` to call them and `print()` to surface results. " +
            "Minimize calls - do as much as possible in a single call. " +
            "Use asyncio.gather() for parallel tool calls. Keep output concise to save context.",
          parameters: Type.Object({
            code: Type.String({
              description:
                "Python code to execute. MCP tools from discovered MCP servers are available as async functions. " +
                "Example:\n" +
                "  result = await some_mcp_tool(arg1, arg2)\n" +
                "  print(result)\n\n" +
                "For parallel calls:\n" +
                "  data1, data2 = await asyncio.gather(tool1(), tool2())",
            }),
          }),
          async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            const { execFile } = await import("node:child_process");
            const { promisify } = await import("node:util");
            const execFilePromise = promisify(execFile);
            const { writeFileSync, unlinkSync } = await import("node:fs");
            const { randomUUID } = await import("node:crypto");
            const { tmpdir } = await import("node:os");
            const { join } = await import("node:path");

            const tmpFile = join(tmpdir(), `agentica_` + randomUUID() + `.py`);
            writeFileSync(tmpFile, params.code);

            try {
              const { stdout, stderr } = await execFilePromise(
                PYTHON,
                [MCP_HELPER, tmpFile],
                {
                  timeout: 120_000,
                  maxBuffer: 10 * 1024 * 1024,
                }
              );

              const output = (stdout || "").trim();
              const errorMsg = (stderr || "").trim();

              if (errorMsg && !output) {
                return {
                  content: [{ type: "text", text: "ERROR:\\n" + errorMsg }],
                  details: {},
                  isError: true,
                };
              }

              return {
                content: [{ type: "text", text: output || "(no output)" }],
                details: {},
              };
            } catch (error: any) {
              const message = error.message || "Unknown error";
              return {
                content: [{ type: "text", text: "Agentica execution failed:\\n" + message }],
                details: {},
                isError: true,
              };
            } finally {
              try {
                unlinkSync(tmpFile);
              } catch {
                // ignore cleanup errors
              }
            }
          },
        });
      }
      EOF
    '';
  };

  # Helper Python script — launches the runtime directly and calls the `python` tool
  mcpHelper = pkgs.writeScript "mcp_helper.py" ''
    #!/usr/bin/env python3
    """MCP client helper for Agentica MCP Runtime.

    Launches the runtime server (via nix develop) and executes Python code
    against it.
    """

    import asyncio
    import sys
    from pathlib import Path

    try:
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
    except ImportError:
        print("Error: mcp package not found.", file=sys.stderr)
        sys.exit(1)

    RUNTIME_PATH = Path("${agenicaPath}")
    CONFIG_FILE = "${agenticaConfigJson}"

    async def connect_and_execute(code: str) -> str:
        server_params = StdioServerParameters(
            command="nix",
            args=[
                "develop", str(RUNTIME_PATH), "--command",
                "uv", "run", "--project", str(RUNTIME_PATH),
                "python", "-m", "agentica_mcp_runtime",
            ],
        )

        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool("python", arguments={"code": code})
                output_parts = [c.text for c in result.content if c.type == "text"]
                return "\n".join(output_parts) if output_parts else "(no output)"

    def main():
        code_file = sys.argv[1] if len(sys.argv) > 1 else "-"
        code = sys.stdin.read() if code_file == "-" else Path(code_file).read_text()
        try:
            result = asyncio.run(connect_and_execute(code))
            print(result, end="")
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)

    if __name__ == "__main__":
        main()
  '';

  pi-settings-patch = (pkgs.formats.json {}).generate "pi-settings-patch.json" {
    terminal = {
      inherit imageWidthCells;
    };
    llamaServerUrl = effectiveLlamaServerUrl;
    # Local-directory pi packages. Pi reads each package's `pi` manifest,
    # loading its extensions and skills. Local paths incur no npm/git fetch
    # at runtime — the source lives read-only in the Nix store.
    packages = [
      "${piLlamaCppSrc}"
      "${ponytailSrc}"
      "${piRlmPkg}"
    ];
  };

  pi-wrapped = pkgs.writeShellScriptBin "pi" ''
    mkdir -p "$HOME/.pi/agent"
    models_json="$HOME/.pi/agent/models.json"
    # Drop the symlink/read-only copy left by earlier generations before writing,
    # plus stale tmps left by crashed wrapper instances.
    rm -f "$models_json" "$models_json.tmp" "$HOME/.pi/agent/settings.json.tmp"
    ${writeModelsJson}
    chmod u+w "$models_json" 2>/dev/null || true
    # pi-rlm's default subagent model: children spawn "pi --provider <p>
    # --model <m>", so steer them explicitly instead of letting pi-rlm's name
    # heuristic pick an unspawnable catalog entry.
    ${lib.optionalString (subagentModel == "auto" && vllmBaseUrl != null) ''
      subagent_model="$(${pkgs.jq}/bin/jq -r '.providers.vllm.models[0].id // empty' "$models_json" 2>/dev/null)"
      [ -n "$subagent_model" ] && export PI_RLM_SUBAGENT_MODEL="vllm/$subagent_model"
    ''}
    ${lib.optionalString (lib.isString subagentModel && subagentModel != "auto") ''
      export PI_RLM_SUBAGENT_MODEL="${subagentModel}"
    ''}
    mkdir -p "$HOME/.pi/agent/extensions"
    # Clean stale files from previous packaging layout
    rm -f "$HOME/.pi/agent/extensions/hooks.ts" "$HOME/.pi/agent/extensions/jsonl.ts"
    ln -sf ${tokenRateExt}/token-rate.ts "$HOME/.pi/agent/extensions/token-rate.ts"
    ${lib.optionalString enableAgentica ''
      rm -rf "$HOME/.pi/agent/extensions/agentica"
      ln -sf ${agenticaExt}/agentica.ts "$HOME/.pi/agent/extensions/agentica.ts"
    ''}
    # Merge Nix-managed settings into settings.json. The merge must survive
    # (a) a corrupt or 0-byte settings.json — pi itself writes this file, and
    #     a killed write leaves the Nix "packages" (pi-rlm and co.) out of the
    #     launch; (b) concurrent wrapper instances (interactive launch plus
    #     rlm children), which race on a shared .tmp name.
    settings_json="$HOME/.pi/agent/settings.json"
    if ${pkgs.jq}/bin/jq -e . "$settings_json" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$settings_json" ${pi-settings-patch} > "$settings_json.tmp.$$" \
        && mv "$settings_json.tmp.$$" "$settings_json"
    else
      # Missing, empty, or unparseable: reseed from the Nix patch.
      cp ${pi-settings-patch} "$settings_json"
    fi
    # pi-rlm's engine spawns `bun` for its persistent evaluator; guarantee
    # it is found even when the user environment has no bun on PATH.
    export PATH="${pkgs.bun}/bin:$PATH"
    exec ${pi-pkg}/bin/pi "$@"
  '';
in {
  environment.systemPackages = [
    pi-wrapped
  ];
}

