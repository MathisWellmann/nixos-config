{
  baseUrl ? "http://localhost:1234/v1",
  enableAgentica ? false,
  agenicaPath ? "/home/m/symbolica/agentica-mcp-runtime",
}: {
  pkgs,
  inputs,
  ...
}: let
  lib = pkgs.lib;

  pi-models-config = (pkgs.formats.json {}).generate "pi-agent-models.json" {
    providers = {
      "${baseUrl}" = {
        inherit baseUrl;
        api = "openai-completions";
        apiKey = "blah";
        models = [
          {
            id = "qwen/qwen3.6-35b-a3b";
            contextWindow = 256000;
            # reasoning = true; # Need to test if there is a difference in performance.
          }
          {
            id = "unsloth/qwen3.6-27b";
            contextWindow = 256000;
            # reasoning = true; # Need to test if there is a difference in performance.
          }
          {id = "unsloth/qwen3.5-27b";}
          {id = "gemma-4-31b-it@f16";}
          {id = "gemma-4-31b-it@q8_0";}
        ];
      };
    };
  };

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

  # pi-autoresearch extension — cloned from GitHub at build time
  autoResearchSrc = pkgs.fetchzip {
    url = "https://github.com/davebcn87/pi-autoresearch/archive/main.tar.gz";
    sha256 = "1bqqx5s3bzrp676pvnwk47i6nv6j1iafv3sj28bw4xvahyfa8xi2";
  };
  autoResearchExt = pkgs.runCommand "pi-autoresearch" {} ''
    mkdir -p $out
    cp ${autoResearchSrc}/extensions/pi-autoresearch/index.ts $out/pi-autoresearch.ts
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

  pi-wrapped = pkgs.writeShellScriptBin "pi" ''
    mkdir -p "$HOME/.pi/agent"
    ln -sf ${pi-models-config} "$HOME/.pi/agent/models.json"
    mkdir -p "$HOME/.pi/agent/extensions"
    ln -sf ${tokenRateExt}/token-rate.ts "$HOME/.pi/agent/extensions/token-rate.ts"
    ln -sf ${autoResearchExt}/pi-autoresearch.ts "$HOME/.pi/agent/extensions/pi-autoresearch.ts"
    ${lib.optionalString enableAgentica ''
      rm -rf "$HOME/.pi/agent/extensions/agentica"
      ln -sf ${agenticaExt}/agentica.ts "$HOME/.pi/agent/extensions/agentica.ts"
    ''}
    exec ${pi-pkg}/bin/pi "$@"
  '';
in {
  environment.systemPackages = [
    pi-wrapped
  ];
}
