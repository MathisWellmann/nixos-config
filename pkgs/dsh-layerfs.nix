# dsh-layerfs (github.com/Ephemeral-AI-Lab/layerfs, `dsh/`): the LayerFS × DSH
# plugin bundle, ready to be linked into a dsh profile. Agents in a session
# bound to a LayerFS project fork, mount, merge and publish Branches through
# the LayerFS JavaScript SDK from bash, and the conversation gets Work and
# History tabs. Nothing of it is published, so it is built from source.
#
# Two derivations:
# - `tree`: the repository's `dsh/` and `sdk/js` (plus the SDK skill), with
#   the browser bundle built. It must keep the checkout layout, because the
#   Host reaches its neighbours by relative path (`../../../../sim/` for the
#   simulator's model, `../../../scenarios/`, the skill under `.agents/`).
#   `dsh/node_modules` links the workspace packages, the SDK and dsh's own
#   `@deepseek-ai/*` packages: Node resolves from the real path of a module,
#   so the Host's peer imports must resolve inside this tree, to the same
#   files dsh itself loaded (one module instance, shared services).
# - the plugin root: the bundle's manifest and patches, with absolute links to
#   `@dsh-layerfs/host` and `@dsh-layerfs/client` in the tree. The home module
#   copies a plugin root into another derivation; absolute links survive that
#   copy, relative ones would not.
#
# The client bundle can only be built with dsh's own tsdown preset
# (`packages/client/tsdown.client.ts` of a deepseek-harness checkout at a
# version inside the bundle's `engines.dsh`). Only the preset and the four
# TypeScript files it imports are fetched; tsdown and lightningcss come from
# `dsh-layerfs/package-lock.json`, pinned to the versions dsh's lockfile uses.
#
# Live projects (real LayerFS Stores in Docker Sandboxes) additionally need a
# Linux `layerfs-daemon`, the SDK's napi addon and a runtime image; none of
# that is built here, so only Sim projects work until the `layerfs-host` row
# gets `image` and `daemon`.
{
  lib,
  stdenv,
  fetchgit,
  fetchNpmDeps,
  npmHooks,
  nodejs_24,
  runCommand,
  deepseek-harness,
}: let
  version = "0.1.0-unstable-2026-10-21";

  layerfsSrc = fetchgit {
    url = "https://github.com/Ephemeral-AI-Lab/layerfs";
    rev = "af1eeef109a36e2c187a0a0058c880f4607ca617";
    # The full checkout is several GB of benchmark data and Rust core.
    sparseCheckout = ["dsh" "sdk/js" ".agents/skills/layerfs-js-sdk"];
    hash = "sha256-JMoPa5swjpI4q1AtMxNNco3BK09YXZ7Tr9TofL8vQEw=";
  };

  # Must match the installed dsh (0.2.1-rc.2) and stay inside `engines.dsh`
  # (`>=0.2.1-alpha.4 <0.3.0`) of the bundle's packages.
  dshRev = "687f282e8625c6b8d11ff58211a90524be2e4317"; # tag dsh-v0.2.1-rc.2
  dshSrc = fetchgit {
    url = "https://github.com/deepseek-ai/deepseek-harness";
    rev = dshRev;
    nonConeMode = true;
    sparseCheckout = [
      "/package.json"
      "/packages/client/tsdown.client.ts"
      "/packages/client/modules/src/client/manifest.ts"
      "/packages/client/web/src/platform.ts"
      "/scripts/client-build-environment.ts"
      "/scripts/experimental-package-policy.ts"
      "/scripts/bundle-input-isolation.ts"
    ];
    hash = "sha256-OYRnEgYbCa651cJuepiB2uZ4QG9mXT7gsoiKhXvOmaY=";
  };

  dshModules = "${deepseek-harness}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";

  tree = stdenv.mkDerivation {
    pname = "dsh-layerfs-tree";
    inherit version;
    src = layerfsSrc;

    npmDeps = fetchNpmDeps {
      src = ./dsh-layerfs;
      hash = "sha256-Vqb8e7Knbr2arZ/VhwclbuLuktDRz1MsvG0/cumOt4s=";
    };
    # The build tools get their own folder: the dsh checkout's root
    # `package.json` is read by the preset (the client's build version).
    npmRoot = "build-deps";
    nativeBuildInputs = [nodejs_24 npmHooks.npmConfigHook];

    # prePatch, not postPatch: npmConfigHook is itself a postPatch hook and
    # runs before the `postPatch` string.
    prePatch = ''
      mkdir build-deps
      cp ${./dsh-layerfs/package.json} build-deps/package.json
      cp ${./dsh-layerfs/package-lock.json} build-deps/package-lock.json
      cp -r ${dshSrc} deepseek-harness
      chmod -R u+w deepseek-harness
      ln -s ../build-deps/node_modules deepseek-harness/node_modules
    '';

    # The preset stamps the dsh commit into the bundle and would otherwise ask
    # `git`, which the sparse fetch leaves no repository for.
    env = {
      DSH_CLIENT_COMMIT_HASH = dshRev;
      NODE_ENV = "production";
    };

    buildPhase = ''
      runHook preBuild
      export DSH_SOURCE="$PWD/deepseek-harness"
      (cd dsh/packages/client && node "$DSH_SOURCE/node_modules/.bin/tsdown")
      test -s dsh/packages/client/lib/client.js
      test -s dsh/packages/client/lib/index.js
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dsh sdk .agents $out/
      modules=$out/dsh/node_modules
      mkdir -p $modules/@deepseek-ai $modules/@dsh-layerfs $modules/@layerfs
      ln -s ${dshModules}/* $modules/@deepseek-ai/
      for p in host client model view mock; do
        ln -s ../../packages/$p $modules/@dsh-layerfs/$p
      done
      ln -s ../../../sdk/js $modules/@layerfs/sdk
      runHook postInstall
    '';
  };
in
  runCommand "dsh-layerfs-${version}" {
    passthru = {inherit tree;};
    meta = {
      description = "LayerFS × DSH plugin bundle for DeepSeek Harness";
      homepage = "https://github.com/Ephemeral-AI-Lab/layerfs/tree/main/dsh";
      license = lib.licenses.mit;
    };
  } ''
    mkdir -p $out/node_modules/@dsh-layerfs
    cp -r ${tree}/dsh/packages/dsh-layerfs/. $out/
    ln -s ${tree}/dsh/packages/host $out/node_modules/@dsh-layerfs/host
    ln -s ${tree}/dsh/packages/client $out/node_modules/@dsh-layerfs/client
  ''
