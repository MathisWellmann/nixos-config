# Backport of nixpkgs master build fixes for Rust packages broken on the
# pinned nixos-unstable.
#
# nixpkgs #537108 made `rustPlatform.cargoSetupHook` force system libraries
# (`ZSTD_SYS_USE_PKG_CONFIG=1`, `AWS_LC_SYS_USE_SYSTEM=1`,
# `LIBSQLITE3_SYS_USE_PKG_CONFIG=1`, ...) instead of letting the `*-sys`
# crates build their vendored C copies. Every package that does not declare
# `pkg-config` and the library now panics in a build script. Upstream fixes
# them one by one; these are the ones we use, copied from master:
#   polaris    pkg-config + zstd
#   rustfs     1243b7622a "rustfs: fix build, devendor zstd and aws-lc"
#   codebook   dcbf911a9d "codebook: use system libs"
#   eilmeldung d11e239654 "eilmeldung: use system aws-lc and sqlite"
# Drop an entry once `nix flake update` brings in a nixos-unstable that has
# the fix; the extra inputs are harmless duplicates until then.
final: prev: let
  addInputs = pkg: {
    native ? [],
    build ? [],
  }:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ native;
      buildInputs = (old.buildInputs or []) ++ build;
    });
  native = [final.pkg-config];
in {
  polaris = addInputs prev.polaris {
    inherit native;
    build = [final.zstd];
  };
  rustfs = addInputs prev.rustfs {
    inherit native;
    build = [final.zstd final.aws-lc];
  };
  codebook = addInputs prev.codebook {
    inherit native;
    build = [final.aws-lc];
  };
  eilmeldung = addInputs prev.eilmeldung {
    inherit native;
    build = [final.aws-lc final.sqlite];
  };
}
