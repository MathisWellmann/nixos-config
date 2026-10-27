# Archify diagram skill and its `archify` CLI, built from one pinned source so
# the CLI on PATH and the skill in `~/.agents/skills` (home/agent-skills.nix)
# never drift apart. The skill dir (`passthru.skill`) is the upstream
# `archify/` folder: zero runtime deps, only `node` (>= 18) is needed.
# Pinned to tag v3.2.0. Update the rev + hash to upgrade.
{pkgs, ...}: let
  src = pkgs.fetchFromGitHub {
    owner = "tt-a1i";
    repo = "archify";
    rev = "208acba8d412335185b2056fedf54b3405df43fb";
    hash = "sha256-pejw78BgKDnttOAGcLvVtWa50azpCjTfESnmdYIjCoI=";
  };
  skill = "${src}/archify";
in
  (pkgs.writeShellScriptBin "archify" ''
    exec ${pkgs.nodejs}/bin/node ${skill}/bin/archify.mjs "$@"
  '').overrideAttrs {passthru = {inherit skill;};}
