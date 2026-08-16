# DeepSeek Harness (`dsh`), an open-source agent harness by DeepSeek AI.
#
# Upstream is a large pnpm monorepo that publishes prebuilt bundles to npm, so
# this packages the published `@deepseek-ai/dsh` CLI tarball instead of
# building the monorepo from source.
#
# The `package-lock.json` next to this file is *not* shipped by upstream; it is
# generated from the tarball's `package.json` and pins the whole dependency
# closure so `buildNpmPackage` can fetch it offline. Regenerate on version
# bumps (see the comment on `version` below).
#
# Docs: https://github.com/deepseek-ai/deepseek-harness
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
  python3,
  # `node-pty` is compiled from source through node-gyp during `npm rebuild`.
  node-gyp,
  makeWrapper,
  versionCheckHook,
  # `dsh plugin ...` forwards to pnpm inside the booted profile directory.
  pnpm,
}: let
  version = "0.1.0-rc.6";
in
  buildNpmPackage {
    pname = "deepseek-harness";
    inherit version;

    # Upstream only tags the monorepo sporadically; the npm tarball is the
    # canonical release artifact and already contains the built `lib/`.
    src = fetchurl {
      url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
      hash = "sha256-G4qaCtPH/q7OR5JuC9N8oVHHzPqZeVOvpf0BJheE6tw=";
    };

    # To regenerate after a version bump:
    #   nix-prefetch-url <tarball> && tar xf <tarball> && cd package
    #   npm install --package-lock-only --ignore-scripts
    #   cp package-lock.json <this dir>/
    # then set `npmDepsHash` to the value `nix build` reports.
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';
    npmDepsHash = "sha256-yvKSLb3oCpmIIhkrdFPVui9Hpxz68wBLqibDAFlBfbU=";

    nodejs = nodejs_24;

    # Published tarball ships the built `lib/`; there is no build script.
    dontNpmBuild = true;

    nativeBuildInputs = [
      python3
      node-gyp
      makeWrapper
    ];

    # The `cordis-plugin-hmr` service (loaded by every profile) needs Node's
    # internal ESM loader. It reaches it either via `--expose-internals` or via
    # the `node-addon-require-builtin` addon, which probes the running Node
    # binary's machine code and fails on nixpkgs' Node 24 build ("Unsupported/
    # no-getter"), so `dsh web` dies with "--expose-internals is required for
    # HMR service". The flag is rejected inside NODE_OPTIONS, so it has to be
    # on the command line: call node directly instead of the shebang script.
    #
    # PATH is appended (not prefixed) so a project-local toolchain still wins.
    postInstall = ''
      rm "$out/bin/dsh"
      makeWrapper ${lib.getExe nodejs_24} "$out/bin/dsh" \
        --add-flags --expose-internals \
        --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        --suffix PATH : ${lib.makeBinPath [nodejs_24 pnpm]}
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "--version";

    meta = {
      description = "DeepSeek Harness (dsh): a plugin-based open-source agent harness";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      mainProgram = "dsh";
      platforms = lib.platforms.unix;
    };
  }
