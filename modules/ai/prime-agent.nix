# prime-agent pointed at the Qwen3.8 SGLang server on desg0.
#
# `models.json` is read-only input to prime-agent (the app reads and reloads
# it, never writes it), so it is a store symlink. `settings.json` is
# app-owned (onboarding/telemetry flags land in it at runtime), so the Nix
# defaults are merged at launch with user values winning.
{
  # OpenAI-compatible endpoint; defaults to desg0's, which resolves from every
  # machine in this config.
  baseUrl ? null,
  # Model ids as the endpoint's `/v1/models` reports them.
  models ? null,
  # Context window; the Qwen3.8 server advertises `max_model_len` 196608.
  contextWindow ? 196608,
  # Output cap: SGLang rejects requests whose prompt + max_tokens exceed
  # `max_model_len`, so keep the budget well below it.
  maxTokens ? 32768,
  providerName ? "desg0",
}: {
  pkgs,
  inputs,
  lib,
  ...
}: let
  desg0 = import ./../../hosts/desg0/constants.nix;
  json = pkgs.formats.json {};

  effectiveBaseUrl =
    if baseUrl != null
    then baseUrl
    else "http://${desg0.hostname}:${toString desg0.qwen3_port}/v1";
  effectiveModels =
    if models != null
    then models
    else [desg0.qwen3Model];

  models-json = json.generate "prime-agent-models.json" {
    providers.${providerName} = {
      baseUrl = effectiveBaseUrl;
      api = "openai-completions";
      # The server runs without `--api-key`, but prime-agent hides providers
      # that have no credential, so a placeholder is required.
      apiKey = "none";
      compat = {
        # SGLang has no `developer` role and no `reasoning_effort`; Qwen-style
        # thinking is toggled via `chat_template_kwargs`.
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        thinkingFormat = "qwen-chat-template";
      };
      models =
        map (id: {
          inherit id;
          reasoning = true;
          contextWindow = contextWindow;
          maxTokens = maxTokens;
        })
        effectiveModels;
    };
  };

  settings-defaults = json.generate "prime-agent-settings-defaults.json" {
    defaultProvider = providerName;
    defaultModel = builtins.head effectiveModels;
  };

  prime-agent-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.prime-agent;
  prime-agent-wrapped = pkgs.writeShellScriptBin "prime-agent" ''
    agent_dir="$HOME/.prime/agent"
    mkdir -p "$agent_dir"
    ln -sfn ${models-json} "$agent_dir/models.json"
    settings="$agent_dir/settings.json"
    if ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
      # Deep merge with the later (user) document winning, so this seeds a
      # fresh install without undoing a later `/settings` choice.
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' ${settings-defaults} "$settings" > "$settings.tmp.$$" \
        && mv "$settings.tmp.$$" "$settings"
    else
      # Missing, empty, or unparseable: reseed from the Nix defaults.
      cp ${settings-defaults} "$settings"
    fi
    exec ${prime-agent-pkg}/bin/prime-agent "$@"
  '';
in {
  environment.systemPackages = [
    # Shadows the plain `prime-agent` that `local_ai.nix` puts in the same profile.
    (lib.hiPrio prime-agent-wrapped)
    prime-agent-pkg
  ];
}
