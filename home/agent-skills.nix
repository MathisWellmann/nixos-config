# Agent Skills for the agent CLIs (`maki`, `deepseek-harness`, `pi`): all of
# them scan `~/.agents/skills/` (the Agent Skills standard directory), so one
# symlink per skill in the Nix store serves every agent.
{pkgs, ...}: let
  # ASD-STE100 "Simple English" writing skill.
  # Pinned to commit be3277ce (2026-08-20). Update the ref + hash to upgrade.
  simpleEnglish = pkgs.fetchFromGitHub {
    owner = "AminBlg";
    repo = "SimpleEnglish";
    rev = "be3277cefe78a27d84315b272c34b2135caf9a66";
    hash = "sha256-H4RaTiUSQup+FYbHLXCZpJuww0A7uXsTkEYsrN2keps=";
  };
in {
  home.file.".agents/skills/simple-english".source = "${simpleEnglish}/skills/simple-english";
}
