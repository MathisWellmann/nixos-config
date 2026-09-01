# Headlong (https://github.com/laude-institute/headlong) — agent microharness
# whose core is Bash: `shellm` plus the CLIs around it. No build step.
#
# Layout mirrors `install.sh --symlinks`: the repo tree lives at
# $out/share/headlong and the CLIs are symlinks into $out/bin. That is what
# `headlong-init`'s `_resolve_app_dir` expects ($script_dir/../bin/shellm +
# ../install.sh), and tools find each other the same way, so the whole tree
# stays coherent. web/, identities/ and thinkers/ assets resolve from the
# same tree. Runtime deps (jq, git, curl, optionally docker) come from the
# caller's PATH.
{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "headlong";
  # No releases or tags upstream; the rev pins the tree.
  version = "24e7ce7";

  src = fetchFromGitHub {
    owner = "laude-institute";
    repo = "headlong";
    rev = "24e7ce77404357aef7b3fc87567e7be908258853";
    # fetchFromGitHub hashes the unpacked tree (narHash), not the tarball.
    hash = "sha256-RfFmVz+LM8DV/8WrFOmGt7T2RVt2YzygJomc9+rF+Vo=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/headlong" "$out/bin"
    cp -r . "$out/share/headlong/"
    for tool in bin/* tools/*; do
      [[ -f "$tool" && -x "$tool" ]] || continue
      ln -s "$out/share/headlong/$tool" "$out/bin/$(basename "$tool")"
    done

    # Tools that write into their own tree can't run from the read-only store:
    # headlong-web builds its viewer frontend (uv writes .venv next to web/),
    # headlong-init creates identities under .identities/ plus the dash .venv.
    # So both are wrappers that re-run the real script from ~/.headlong/app,
    # headlong's own writable app-dir convention (auto-resolved by every tool,
    # persistent, not a deletable cache), keeping the store tree as the
    # pristine source and re-copying it whenever the store path changes
    # (never touching user data).
    for tool in headlong-web headlong-init; do
      rm "$out/bin/$tool"
      sed "s|tools/TOOL|tools/$tool|" <<'EOF' > "$out/bin/$tool"
#!/usr/bin/env bash
set -euo pipefail
store="$(cd "$(dirname "$(realpath "''${BASH_SOURCE[0]}")")/../share/headlong" && pwd)"
app="$HOME/.headlong/app"
if [[ "$(cat "$app/.headlong-src" 2>/dev/null)" != "$store" ]]; then
  mkdir -p "$app"
  cp -a "$store/." "$app/"
  chmod -R u+w "$app"
  echo "$store" > "$app/.headlong-src"
fi
exec "$app/tools/TOOL" "$@"
EOF
      chmod 755 "$out/bin/$tool"
    done

    runHook postInstall
  '';

  meta = {
    description = "Headlong agent microharness: persistent agents whose core is a Bash recursive language model (shellm)";
    homepage = "https://github.com/laude-institute/headlong";
    license = lib.licenses.asl20;
    mainProgram = "shellm";
    platforms = lib.platforms.linux;
  };
}
