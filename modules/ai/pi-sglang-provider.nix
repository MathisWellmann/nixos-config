# pi `models.json` provider entry for the fleet's OpenAI-compatible
# SGLang/vLLM servers (Qwen3.8 chat template). Shared by the workstation pi
# (modules/ai/pi-agent.nix) and the ax task runner image (pkgs/ax).
#
# The servers speak OpenAI Chat Completions, but have no `developer` role and
# no `reasoning_effort`; Qwen-style thinking is toggled via
# `chat_template_kwargs`. The RadixArk Qwen3.8 template additionally steers
# effort via a `reasoning_effort` kwarg: xhigh|medium|low, default xhigh, any
# other value is a 400. It is prompt-level steering (an injected instruction,
# no token budget). The generic chat-template format forwards pi levels
# through it.
{
  baseUrl,
  models,
  contextWindow ? 262144,
  maxTokens ? 32768,
  # The served Qwen3.8-27B is multimodal; pi defaults custom models to
  # text-only input, which drops pasted images.
  vision ? true,
}: {
  inherit baseUrl;
  api = "openai-completions";
  # Placeholder: the servers run without `--api-key`, but pi hides models
  # that have no auth configured.
  apiKey = "vllm";
  compat = {
    supportsDeveloperRole = false;
    supportsReasoningEffort = false;
    thinkingFormat = "chat-template";
    chatTemplateKwargs = {
      enable_thinking = {"$var" = "thinking.enabled";};
      reasoning_effort = {
        "$var" = "thinking.effort";
        omitWhenOff = true;
      };
      preserve_thinking = true;
    };
  };
  models =
    map (id: {
      inherit id contextWindow maxTokens;
      reasoning = true;
      input =
        ["text"]
        ++ (
          if vision
          then ["image"]
          else []
        );
      # Map pi levels onto the template's xhigh|medium|low. `off` needs no
      # entry: enable_thinking=false already suppresses thinking.
      thinkingLevelMap = {
        minimal = "low";
        low = "low";
        medium = "medium";
        high = "xhigh";
        xhigh = "xhigh";
        max = "xhigh";
      };
    })
    models;
}
