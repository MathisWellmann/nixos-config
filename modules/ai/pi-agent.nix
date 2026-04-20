{baseUrl ? "http://localhost:1234/v1"}: {
  pkgs,
  inputs,
  ...
}: let
  pi-models-config = (pkgs.formats.json {}).generate "pi-agent-models.json" {
    providers = {
      "${baseUrl}" = {
        inherit baseUrl;
        api = "openai-completions";
        apiKey = "blah";
        models = [
          {id = "qwen/qwen3.6-35b-a3b";}
          {id = "unsloth/qwen3.5-27b";}
          {id = "gemma-4-31b-it@f16";}
          {id = "gemma-4-31b-it@q8_0";}
        ];
      };
    };
  };

  pi-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

  pi-wrapped = pkgs.writeShellScriptBin "pi" ''
    mkdir -p "$HOME/.pi/agent" && ln -sf ${pi-models-config} "$HOME/.pi/agent/models.json"
    exec ${pi-pkg}/bin/pi "$@"
  '';
in {
  environment.systemPackages = [
    pi-wrapped
  ];
}
