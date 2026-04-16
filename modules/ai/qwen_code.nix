{pkgs, ...}: let
  lmstudio_base_url = "http://localhost:1234/v1";

  qwen-code-config = (pkgs.formats.json {}).generate "qwen-code-settings.json" {
    modelProviders = {
      openai = [
        {
          id = "lmstudio";
          name = "LM Studio Local";
          baseUrl = lmstudio_base_url;
          envKey = ""; # No key needed
        }
      ];
    };
    model = {
      name = "lmstudio";
    };
  };

  qwen-code-wrapped = pkgs.writeShellScriptBin "qwen-code" ''
    mkdir -p "$HOME/.qwen" && ln -sf ${qwen-code-config} "$HOME/.qwen/settings.json"
    exec ${pkgs.qwen-code}/bin/qwen "$@"
  '';
in {
  environment.systemPackages = [
    qwen-code-wrapped
  ];
}
