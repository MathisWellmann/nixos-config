# The `monty` binary of pydantic/monty: a sandboxed Python-subset interpreter
# written in Rust (https://github.com/pydantic/monty). Besides the interactive
# REPL and file runner, `monty subprocess` is the crash-isolated worker the
# `@pydantic/monty` npm package (and `pydantic-monty` on PyPI) drives over a
# framed protobuf protocol — that is what `home/plugins/dsh-tool-monty` uses.
#
# Built from crates.io instead of taking the npm platform package's prebuilt
# ELF, which hardcodes `/lib64/ld-linux-x86-64.so.2` and does not run on NixOS
# without nix-ld. Keep the version in lock-step with the `@pydantic/monty`
# npm version vendored in `pkgs/dsh-tool-monty.nix`: the worker protocol is
# only guaranteed compatible within one release.
#
# nixpkgs' cargo setup hook exports `ZSTD_SYS_USE_PKG_CONFIG=1`, so the
# `zstd-sys` dependency needs pkg-config and the system zstd; without them its
# build script panics.
{
  lib,
  fetchCrate,
  rustPlatform,
  pkg-config,
  zstd,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "monty-runtime";
  version = "1.5.0";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-wtrDWGlhVAjHzsr0sbaGUA97KAgNhnC2+QVzH8Wg/7A=";
  };

  cargoHash = "sha256-UIFY1otb222pnncMvKTy4Gf+eGNhOuB/3cMGtFZrz0o=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [zstd];

  # The crate's tests spawn the built binary through tempfiles; not needed
  # for a runtime package and they lengthen the build considerably.
  doCheck = false;

  meta = {
    description = "Sandboxed Python-subset interpreter in Rust (REPL and subprocess worker)";
    homepage = "https://github.com/pydantic/monty";
    license = lib.licenses.mit;
    mainProgram = "monty";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
