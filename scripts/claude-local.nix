{ pkgs, ... }:let
  gum = "${pkgs.gum}/bin/gum";
  curl = "${pkgs.curl}/bin/curl";
in 
pkgs.writeShellScriptBin "claude-local" ''
  set -euo pipefail

  # --- Configuration ---
  LMSTUDIO_HOST="''${LMSTUDIO_HOST:-"http://localhost:1234"}"

  # --- Fetch available models ---
  echo "Fetching models from LM Studio at ''$LMSTUDIO_HOST ..."
  models_json=$(${curl} -sf "''$LMSTUDIO_HOST/v1/models" 2>/dev/null) || {
    echo "Error: Could not reach LM Studio at $LMSTUDIO_HOST" >&2
    echo "Make sure LM Studio's server is running:" >&2
    echo "  lms server start --port 1234" >&2
    exit 1
  }

  models=$(echo "''$models_json" | jq -r '.data[].id' | sort)

  if [ -z "''$models" ]; then
    echo "No models found on ''$LMSTUDIO_HOST." >&2
    echo "Load a model in LM Studio first." >&2
    exit 1
  fi

  # --- Select model with gum ---
  echo ""
  selected=$(echo "''$models" | ${gum} choose --header "Select a model for Claude Code:")

  if [ -z "''$selected" ]; then
    echo "No model selected." >&2
    exit 1
  fi

  echo ""
  echo "Using model: ''$selected"
  echo "Base URL:    ''$LMSTUDIO_HOST"
  echo ""

  # --- Launch Claude Code ---
  exec env \
    ANTHROPIC_BASE_URL="''$LMSTUDIO_HOST" \
    ANTHROPIC_API_KEY="" \
    ANTHROPIC_AUTH_TOKEN="lmstudio" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="''$selected" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="''$selected" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="''$selected" \
    CLAUDE_CODE_SUBAGENT_MODEL="''$selected" \
    claude --model "$selected" "''$@"
''
  
