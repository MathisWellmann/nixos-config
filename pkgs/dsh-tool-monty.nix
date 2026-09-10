# The dsh-tool-monty plugin (home/plugins/dsh-tool-monty) with its runtime
# dependencies vendored into `node_modules`, ready to be linked into a dsh
# profile.
#
# The profile ships no `npm install`, so the complete eager import chain of
# `@pydantic/monty`'s Node entry is copied in as real directories (Node walks
# up from the real path of the importing file, so a symlinked store path
# would leave the inner deps unresolvable): the package itself, its
# platform-specific napi addon, and the two OpenTelemetry API packages its
# `dist/telemetry.js` imports at module load.
#
# The platform package's prebuilt `monty` worker ELF is dropped: it hardcodes
# `/lib64/ld-linux-x86-64.so.2`. The plugin instead spawns the nix-built
# `monty-runtime` binary, whose path is baked into the bundle patch's
# `binaryPath` here so the plugin needs no machine-local override. The napi
# addon (`monty.linux-x64-gnu.node`) links only glibc and is `dlopen`ed by
# the dsh node binary, so it needs no patching.
{
  lib,
  stdenv,
  fetchzip,
  runCommand,
  callPackage,
  monty-runtime ? callPackage ./monty-runtime.nix {},
}: let
  version = "0.0.23";

  platform =
    {
      "x86_64-linux" = {
        name = "linux-x64-gnu";
        hash = "sha256-/pDYB8Qm/xNT0b+jUSd77cjvu0eHkzR5F05WAuybVkI=";
      };
      "aarch64-linux" = {
        name = "linux-arm64-gnu";
        hash = "sha256-tqTdIlJEDpfBfAaoipBGG+eL4g2cyVDkXF6XfNqXROo=";
      };
    }
    .${stdenv.hostPlatform.system}
    or (throw "dsh-tool-monty: no @pydantic/monty platform package for ${stdenv.hostPlatform.system}");

  monty = fetchzip {
    url = "https://registry.npmjs.org/@pydantic/monty/-/monty-${version}.tgz";
    hash = "sha256-LUFhYWbJlbMIemoMaWaln/lXSKdtHfmNSuQCAdJAuTI=";
  };
  montyPlatform = fetchzip {
    url = "https://registry.npmjs.org/@pydantic/monty-${platform.name}/-/monty-${platform.name}-${version}.tgz";
    hash = platform.hash;
  };
  otelApi = fetchzip {
    url = "https://registry.npmjs.org/@opentelemetry/api/-/api-1.9.1.tgz";
    hash = "sha256-k/mwwN5FRQvE4ucyu9QzjKPuxEb/Krd0V2wf6wbdr3M=";
  };
  otelApiLogs = fetchzip {
    url = "https://registry.npmjs.org/@opentelemetry/api-logs/-/api-logs-0.222.0.tgz";
    hash = "sha256-MpzfWWzKfRv9zLrHfp7VCRjLPaX0b3MQ0v4fZs/1R3w=";
  };
in
  runCommand "dsh-tool-monty" {
    passthru = {inherit monty-runtime version;};
    meta = {
      description = "DeepSeek Harness plugin: persistent sandboxed Python REPL tool (Monty)";
      license = lib.licenses.mit;
      platforms = builtins.attrNames {
        "x86_64-linux" = null;
        "aarch64-linux" = null;
      };
    };
  } ''
    mkdir -p $out
    cp -r ${../home/plugins/dsh-tool-monty}/. $out/
    chmod -R u+w $out

    mkdir -p $out/node_modules/@pydantic $out/node_modules/@opentelemetry
    cp -r ${monty} $out/node_modules/@pydantic/monty
    cp -r ${montyPlatform} $out/node_modules/@pydantic/monty-${platform.name}
    cp -r ${otelApi} $out/node_modules/@opentelemetry/api
    cp -r ${otelApiLogs} $out/node_modules/@opentelemetry/api-logs
    chmod -R u+w $out/node_modules
    # Not runnable on NixOS and never used: the plugin passes `binaryPath`.
    rm -f $out/node_modules/@pydantic/monty-${platform.name}/monty

    substituteInPlace $out/cordis.patch.yml \
      --replace-fail "binaryPath: monty" "binaryPath: ${monty-runtime}/bin/monty"
  ''
