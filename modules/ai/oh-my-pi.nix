# oh-my-pi (`omp`) wired to the vLLM server on desg0.
#
# `omp` has a built-in `vllm` provider that discovers models from
# `<vllmBaseUrl>/models` on every launch and keeps vLLM's advertised
# `max_model_len` as the context window. The Nix-generated `models.yml`
# therefore only carries what the server does not advertise: the endpoint, the
# Qwen thinking wire format and an output-token cap.
{
  # OpenAI-compatible endpoint of the vLLM server. Defaults to desg0's, which
  # resolves from every machine in this config; desg0 itself (and hosts that
  # reach it through an SSH tunnel) pass a loopback URL instead.
  vllmBaseUrl ? null,
  # Model ids used until discovery succeeds (e.g. while vLLM loads weights), so
  # `/model` keeps working. A discovered model of the same id replaces its
  # entry, so listing the real id causes no duplicates.
  vllmModels ? null,
  # Fallback context window; discovery prefers the server's `max_model_len`.
  vllmContextWindow ? 131072,
  # Discovery leaves `maxTokens` unset, and vLLM rejects requests whose
  # prompt + max_tokens exceed `max_model_len`, so cap the output budget.
  vllmMaxTokens ? 32768,
  # Optional `provider/model` selector seeded into `modelRoles.default`, e.g.
  # "vllm/Qwen/Qwen3.8-27B-FP8". Merged as a *default*: a selection already
  # stored in `config.yml` (what `/model` writes) wins.
  defaultModel ? null,
}: {
  pkgs,
  inputs,
  lib,
  ...
}: let
  desg0 = import ./../../hosts/desg0/constants.nix;

  effectiveBaseUrl =
    if vllmBaseUrl != null
    then vllmBaseUrl
    else "http://${desg0.hostname}:${toString desg0.vllm_port}/v1";

  effectiveModels =
    if vllmModels != null
    then vllmModels
    else [desg0.vllmModel];

  yaml = pkgs.formats.yaml {};

  models-yml = yaml.generate "omp-models.yml" {
    providers.vllm = {
      baseUrl = effectiveBaseUrl;
      # The server runs without `--api-key`; without `auth: none` omp drops a
      # provider that has no credential.
      auth = "none";
      api = "openai-completions";
      compat = {
        # vLLM has no `developer` role and no `reasoning_effort`; Qwen-style
        # thinking is toggled via `chat_template_kwargs`.
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        thinkingFormat = "qwen-chat-template";
      };
      models =
        map (id: {
          inherit id;
          reasoning = true;
          contextWindow = vllmContextWindow;
          maxTokens = vllmMaxTokens;
        })
        effectiveModels;
      # `models` entries are merged before runtime discovery and can be
      # overwritten by it; `modelOverrides` is re-applied afterwards, so the
      # output cap survives.
      modelOverrides = lib.genAttrs effectiveModels (_: {
        reasoning = true;
        maxTokens = vllmMaxTokens;
      });
    };
  };

  config-defaults-yml = yaml.generate "omp-config-defaults.yml" {
    modelRoles.default = defaultModel;
  };

  omp-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;

  # `models.yml` is read from $HOME, so it is (re-)linked on every launch. It
  # points into the store, i.e. it is Nix-owned: extra providers belong in this
  # module, not in the file.
  omp-wrapped = pkgs.writeShellScriptBin "omp" ''
    agent_dir="''${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
    mkdir -p "$agent_dir"
    ln -sfn ${models-yml} "$agent_dir/models.yml"
    ${lib.optionalString (defaultModel != null) ''
      config="$agent_dir/config.yml"
      if [ -f "$config" ]; then
        # Deep merge with the later (user) document winning, so this seeds a
        # fresh install without undoing a later `/model` choice.
        ${pkgs.yq-go}/bin/yq eval-all '. as $doc ireduce ({}; . * $doc)' \
          ${config-defaults-yml} "$config" > "$config.tmp" \
          && mv "$config.tmp" "$config"
      else
        install -m 0644 ${config-defaults-yml} "$config"
      fi
    ''}
    exec ${omp-pkg}/bin/omp "$@"
  '';
in {
  environment.systemPackages = [
    # Shadows the plain `omp` that `local_ai.nix` puts in the same profile.
    (lib.hiPrio omp-wrapped)
    omp-pkg
  ];
}
