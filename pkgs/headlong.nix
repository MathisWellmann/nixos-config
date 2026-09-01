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

    # headlong-web runs `uv run --project <tree>/web`, which writes .venv next
    # to the project — impossible from the read-only store. So bin/headlong-web
    # is a wrapper that re-runs the real script from a writable copy in
    # $XDG_CACHE_HOME, re-copied whenever the store path changes.
    rm "$out/bin/headlong-web"
    cat > "$out/bin/headlong-web" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
store="$(cd "$(dirname "$(realpath "''${BASH_SOURCE[0]}")")/../share/headlong" && pwd)"
cache="''${XDG_CACHE_HOME:-$HOME/.cache}/headlong-web"
if [[ "$(cat "$cache/.headlong-src" 2>/dev/null)" != "$store" ]]; then
  mkdir -p "$cache"
  cp -a "$store/." "$cache/"
  chmod -R u+w "$cache"
  echo "$store" > "$cache/.headlong-src"
fi
exec "$cache/tools/headlong-web" "$@"
EOF
    chmod 755 "$out/bin/headlong-web"

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
