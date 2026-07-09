# A standalone package that exposes only the `hf` (Hugging Face) CLI.
#
# nixpkgs ships the `hf` binary as part of `python3Packages.huggingface-hub`,
# but that also drops `huggingface-cli` and `tiny-agents` into `$PATH` and is
# not usable as a top-level `pkgs` attribute. This wrapper builds a derivation
# that exposes just the `hf` entrypoint.
#
# Docs: https://huggingface.co/docs/huggingface_hub/guides/cli
{
  lib,
  python3Packages,
  symlinkJoin,
  makeWrapper,
  # Include the `hf_xet` extra for fast, chunk-based transfers (recommended).
  withXet ? true,
}: let
  # huggingface-hub with the optional extras we want available to the CLI.
  hfHub = python3Packages.huggingface-hub.overridePythonAttrs (old: {
    dependencies =
      (old.dependencies or [])
      ++ lib.optionals withXet python3Packages.huggingface-hub.optional-dependencies.hf_xet;
  });
in
  symlinkJoin {
    name = "hf-${hfHub.version}";
    paths = [hfHub];
    nativeBuildInputs = [makeWrapper];

    # Keep only the `hf` entrypoint (drop `huggingface-cli` and `tiny-agents`).
    postBuild = ''
      find "$out/bin" -mindepth 1 -maxdepth 1 ! -name hf -delete
    '';

    meta = {
      description = "The Hugging Face Hub command-line interface (`hf`)";
      homepage = "https://huggingface.co/docs/huggingface_hub/guides/cli";
      license = lib.licenses.asl20;
      mainProgram = "hf";
    };
  }
