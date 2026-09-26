# Global instructions for every agent harness, from one source: ./agent-instructions.md
# (not named AGENTS.md, so agents working in this repo do not load it as
# project instructions for home/).
# Each harness reads a user-global instruction file at a different path, so the
# same store file is linked into each of them.
_: let
  source = ./agent-instructions.md;
  targets = [
    ".config/maki/AGENTS.md" # maki
    ".dsh/AGENTS.md" # deepseek-harness ($DSH_HOME, default ~/.dsh)
    ".pi/agent/AGENTS.md" # pi
    ".omp/agent/AGENTS.md" # oh-my-pi ($PI_CODING_AGENT_DIR, default ~/.omp/agent)
    ".claude/CLAUDE.md" # Claude Code
    ".codex/AGENTS.md" # Codex
    ".config/opencode/AGENTS.md" # opencode
    ".qwen/QWEN.md" # Qwen Code
  ];
in {
  home.file = builtins.listToAttrs (map (name: {
      inherit name;
      value.source = source;
    })
    targets);
}
