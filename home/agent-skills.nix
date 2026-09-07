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

  # Manim video-writing skills (composer + manim-CE best practices), pinned to
  # commit cef04501 (2026-01-23). Update the ref + hash to upgrade.
  manimSkill = pkgs.fetchFromGitHub {
    owner = "adithya-s-k";
    repo = "manim_skill";
    rev = "cef045011722d285692e3381d12d4d637da56e18";
    hash = "sha256-eZUQ2OqGoPELvziz3ValJ7TQeLukplSPL9yNcCpzt1w=";
  };
in {
  home.file.".agents/skills/simple-english".source = "${simpleEnglish}/skills/simple-english";
  home.file.".agents/skills/manim-composer".source = "${manimSkill}/skills/manim-composer";
  home.file.".agents/skills/manimce-best-practices".source = "${manimSkill}/skills/manimce-best-practices";
}
