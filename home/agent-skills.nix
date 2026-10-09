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
    hash = "sha256-CESWKMHvCN6Dtc8Fk8V9pP2txQ6b0Y7180GawMciTWc=";
  };

  # Editorial HTML/SVG diagram skill (42 diagram types), pinned to commit
  # f4547ee9 (2026-10-08). Update the ref + hash to upgrade.
  diagramDesign = pkgs.fetchFromGitHub {
    owner = "cathrynlavery";
    repo = "diagram-design";
    rev = "f4547ee95f88e5b28a52517feff6b6c11cc657f9";
    hash = "sha256-L+2YqVybYQ892nLkaHSRKI4pjFcb506jhDz4U8ju6P8=";
  };
in {
  home.file = {
    ".agents/skills/simple-english".source = "${simpleEnglish}/skills/simple-english";
    ".agents/skills/manim-composer".source = "${manimSkill}/skills/manim-composer";
    ".agents/skills/manimce-best-practices".source = "${manimSkill}/skills/manimce-best-practices";
    ".agents/skills/diagram-design".source = "${diagramDesign}/skills/diagram-design";
  };
}
