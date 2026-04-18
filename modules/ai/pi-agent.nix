{
  pkgs,
  inputs,
  ...
}: let
  global_const = import ../../global_constants.nix;

  pi-models-config = (pkgs.formats.json {}).generate "pi-agent-models.json" {
    providers = {
      LMStudio = {
        baseUrl = "http://localhost:1234/v1";
        api = "openai-completions";
        apiKey = "blah";
        models = [
          {id = "gemma-4-31b-it@f16";}
          {id = "gemma-4-31b-it@q8_0";}
          {id = "unsloth/qwen3.5-27b";}
          {id = "qwen/qwen3.6-35b-a3b";}
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
