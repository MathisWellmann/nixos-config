# The `monty` binary of pydantic/monty: a sandboxed Python-subset interpreter
# written in Rust (https://github.com/pydantic/monty). Besides the interactive
# REPL and file runner, `monty subprocess` is the crash-isolated worker the
# `@pydantic/monty` npm package (and `pydantic-monty` on PyPI) drives over a
# framed protobuf protocol — that is what `home/plugins/dsh-tool-monty` uses.
#
# Built from crates.io instead of taking the npm platform package's prebuilt
# ELF, which hardcodes `/lib64/ld-linux-x86-64.so.2` and does not run on NixOS
# without nix-ld. Keep the version in lock-step with the `@pydantic/monty`
# npm version vendored in `home/deepseek-harness.nix`: the worker protocol is
# only guaranteed compatible within one release.
{
  lib,
  fetchCrate,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "monty-runtime";
  version = "0.0.23";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-VjCVr9x9AtO4lRhlW0jb7/wyvKYzfgN7MwX2s+zOlv4=";
  };

  cargoHash = "sha256-xJD7N5dOPEC5hu6Rxo0bV0x06NEd+5E1H6EuNC71WGM=";

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
