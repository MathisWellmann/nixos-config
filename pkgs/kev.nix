# Kev (github:jaredpalmer/kev): a Jev-like family of decision models served
# through a TypeSafe System One API.
#
# Builds a self-contained bundle instead of Nix-building torch:
#   $out/kev          the kev source at a pinned revision
#   $out/venv         a uv-synced Python 3.13 venv from the repo's own uv.lock
#                     (torch, transformers, peft + the `serve` extras), plus
#                     flash-linear-attention at the exact version kev's fused
#                     Qwen3.5 kernels pin (FLA_VERSION in kev/fused_qwen35.py)
#   $out/bin/kev-serve    `python -m kev.serve` (the server)
#   $out/bin/kev-prefetch download the checkpoint's weights into the HF cache
#
# The build is hermetic: the fleet builders' build sandboxes resolve DNS
# unreliably, so every wheel is fetched with fetchurl on the build client
# (see pkgs/kev-wheels.nix, generated from the lock) and uv installs from the
# local directory with --no-index. Output stays deterministic: uv verifies
# each wheel against the hash pinned in the lock.
#
# The kev package itself is not installed into the venv (that would need a
# PEP 517 build with network access); the wrappers set PYTHONPATH=$out/kev
# instead, so the venv only ever carries third-party dependencies.
{
  lib,
  stdenvNoCC,
  python313,
  uv,
  makeWrapper,
  writeText,
  # Must equal FLA_VERSION in kev/fused_qwen35.py: kev.serve turns the fused
  # Qwen3.5 kernels on for CUDA only at that exact version (KEV_FUSED=0 to decline).
  flaVersion ? "0.5.2",
}: let
  rev = "5920c5fe4ca8e0970ed4209ac2c9b8e18bea5109";

  # All wheels the linux x86_64 / cp313 resolution needs, pinned from the
  # lock. Fetched by the build client. uv matches wheels by their PEP 427
  # filename, so each store path is renamed back to the original wheel name.
  wheelEntries = map (w: {
    path = builtins.fetchurl {
      inherit (w) url;
      inherit (w) sha256;
    };
    filename = builtins.baseNameOf w.url;
  }) (import ./kev-wheels.nix);

  # writeText so the scripts are store paths (installPhase dedents them; see
  # there). uv sync --frozen downloads each wheel from the exact URL the lock
  # pins, so the wheel URLs are rewritten to the local find-links directory
  # (hashes stay untouched, so uv still verifies every wheel).
  lockRewriteScript = writeText "kev-rewrite-lock.py" ''
    """Point every PyPI wheel URL in uv.lock at a local wheels directory."""
    import re
    import sys
    from pathlib import Path

    wheels_dir = sys.argv[1]
    lock = Path("uv.lock")
    text = lock.read_text()
    pattern = re.compile(r'(url = ")https://files\.pythonhosted\.org/packages/[^"]+/([^"]+\.whl)(")')
    new, count = pattern.subn(rf'\g<1>file://{wheels_dir}/\g<2>\g<3>', text)
    assert count > 0, "no wheel URLs matched; uv.lock format changed?"
    lock.write_text(new)
    print(f"rewrote {count} wheel URLs in uv.lock to {wheels_dir}")
  '';

  prefetchScript = writeText "kev-prefetch.py" ''
    """Download a Kev checkpoint's weights into the Hugging Face cache.

    Fetches the checkpoint repo (LoRA adapter, head.pt, tokenizer) and, for a
    LoRA checkpoint, the base model at the revision pinned inside head.pt - the
    exact two snapshots kev.serve loads. Idempotent: cached files are skipped.
    """
    import sys

    from huggingface_hub import snapshot_download

    from kev.checkpoint import read_meta, resolve_run

    run = sys.argv[1] if len(sys.argv) > 1 else "jaredpalmer/kev-4b"
    path = resolve_run(run)
    meta = read_meta(path)
    print(f"checkpoint: {path} (base {meta.base}@{meta.base_revision}, weights={meta.weights})")
    if meta.weights == "lora":
        snapshot_download(
            meta.base,
            revision=meta.base_revision,
            allow_patterns=["*.json", "*.safetensors", "*.pt", "*.txt", "*.jinja"],
        )
        print(f"base ready: {meta.base}@{meta.base_revision}")
    else:
        print("full-weight checkpoint: nothing else to download")
  '';
in
  stdenvNoCC.mkDerivation {
    pname = "kev";
    version = "2026-09-26-${lib.substring 0 8 rev}";

    # fetchGit instead of fetchFromGitHub: GitHub's codeload tarballs are
    # regenerated over time (non-deterministic bytes for the same rev), while a
    # git revision is immutable, so the checkout hash is stable forever.
    src = builtins.fetchGit {
      url = "https://github.com/jaredpalmer/kev";
      inherit rev;
    };

    nativeBuildInputs = [
      python313 # the repo's .python-version (requires-python >=3.12,<3.14)
      uv
      makeWrapper
    ];

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"

      # Source into the store: $out/kev is the path that survives the build.
      # cp -a keeps the fetchGit checkout's read-only modes (directories and
      # files, e.g. uv.lock), and uv + the lock rewrite must write in place.
      cp -a "$src/." "$out/kev"
      chmod -R u+w "$out/kev"

      # Place every wheel under its PEP 427 filename in one find-links
      # directory. uv identifies wheels by filename (the store name is not a
      # valid wheel name); hardlink first, copy when the store and the build
      # tmpdir are on different filesystems.
      wheelsDir="$TMPDIR/kev-wheels"
      mkdir -p "$wheelsDir"
      ${lib.concatMapStrings (e: "ln -f '${e.path}' \"$wheelsDir/${e.filename}\" 2>/dev/null || cp '${e.path}' \"$wheelsDir/${e.filename}\"\n") wheelEntries}

      # uv's cache lives in the ephemeral build sandbox; the venv itself is
      # self-contained (hardlinks/copies out of that cache).
      export UV_CACHE_DIR="$TMPDIR/uv-cache"
      cd "$out/kev"

      # uv sync --frozen downloads each wheel from the exact URL the lock
      # pins, so point the wheel URLs at the local directory first (hashes
      # stay, so every wheel is still verified).
      "${python313}/bin/python3.13" -c 'import sys, textwrap; sys.stdout.write(textwrap.dedent(sys.stdin.read()))' \
        < ${lockRewriteScript} > "$out/kev/rewrite-lock.py"
      "${python313}/bin/python3.13" "$out/kev/rewrite-lock.py" "$wheelsDir"

      # No package index: the repo's lockfile is the source of truth for every
      # dependency (--frozen), and every wheel now comes from the local
      # directory. --no-install-project skips building the kev package itself
      # (see the file header for why).
      uv sync --frozen --no-index --extra serve --no-install-project \
        --find-links "$wheelsDir" --python "${python313}/bin/python3.13"
      mv "$out/kev/.venv" "$out/venv"
      uv pip install --no-index --find-links "$wheelsDir" \
        --python "$out/venv/bin/python" "flash-linear-attention==${flaVersion}"

      # Nix interpolation (not just a shell reference) so deadnix sees the
      # binding. alejandra re-indents the content of multi-line string
      # literals to the expression's indent, so dedent the common prefix back:
      # the script must start at column 0 to be valid Python.
      "${python313}/bin/python3.13" -c 'import sys, textwrap; sys.stdout.write(textwrap.dedent(sys.stdin.read()))' \
        < ${prefetchScript} > "$out/kev-prefetch.py"

      # Torch's C++ extension modules need the host C++ runtime (libstdc++
      # and its libgcc dependency) at run time. The build closure always
      # contains the host gcc runtime libraries (stdenv pulls them in for the
      # toolchain), but nothing exports them for a service, so vendor them
      # into the output. The closure is fixed by this derivation, so this
      # stays reproducible.
      mkdir -p "$out/lib"
      stdcxxFile=$(find /nix/store -maxdepth 3 -type f -name 'libstdc++.so.6.*' ! -name '*gdb.py' -path '*-gcc-*-lib/*' ! -path '*xgcc*' 2>/dev/null | head -1)
      libgccFile=$(find /nix/store -maxdepth 3 -type f -name 'libgcc_s.so.1' -path '*-gcc-*-libgcc/*' ! -path '*xgcc*' 2>/dev/null | head -1)
      [ -n "$stdcxxFile" ] || { echo "build closure lacks the host libstdc++ runtime" >&2; exit 1; }
      [ -n "$libgccFile" ] || { echo "build closure lacks the host libgcc runtime" >&2; exit 1; }
      cp -f "$stdcxxFile" "$libgccFile" "$out/lib/"
      ln -sf "$(basename "$stdcxxFile")" "$out/lib/libstdc++.so.6"

      # The CUDA runtime ships inside the nvidia-* wheels in the venv.
      # PYTHONPATH carries the kev package (not pip-installed; see the file
      # header).
      # makeShellWrapper takes the wrapped program's flags only via
      # --add-flags (a shell-quoted string appended before "$@").
      makeWrapper "$out/venv/bin/python" "$out/bin/kev-serve" \
        --prefix PATH : "$out/venv/bin" \
        --prefix PYTHONPATH : "$out/kev" \
        --prefix LD_LIBRARY_PATH : "$out/lib" \
        --add-flags '-m kev.serve'
      makeWrapper "$out/venv/bin/python" "$out/bin/kev-prefetch" \
        --prefix PATH : "$out/venv/bin" \
        --prefix PYTHONPATH : "$out/kev" \
        --prefix LD_LIBRARY_PATH : "$out/lib" \
        --add-flags "$out/kev-prefetch.py"
    '';

    meta = with lib; {
      description = "Kev: Jev-like decision models (LoRA + pointer head on Qwen) with a TypeSafe System One server";
      homepage = "https://github.com/jaredpalmer/kev";
      license = licenses.asl20;
      platforms = platforms.linux; # the torch cu12 wheel path; the MLX/Mac path is out of scope here
      mainProgram = "kev-serve";
    };
  }
