# lx (https://github.com/wjv/lx): a file lister forked from exa, with
# compounding detail tiers (`-l`/`-ll`/`-lll`), a tree view with recursive
# directory sizes (`-TZ`), and VCS status for git *and* jj repos.
#
# Not in nixpkgs. Built with the `jj` feature (like upstream's release
# binaries), because every repo here is a colocated jj repo: without it the
# VCS column falls back to git and shows jj's detached-HEAD view.
#
# nixpkgs' cargo setup hook forces system libraries for the `*-sys` crates,
# so libgit2-sys gets pkg-config and the nixpkgs libgit2 (1.9.7, the exact
# version libgit2-sys 0.18.8+1.9.7 wraps). LIBGIT2_NO_VENDOR turns a silent
# fallback to the vendored C copy into a build error if the two drift apart.
{
  lib,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
  pkg-config,
  libgit2,
  zlib,
  gitMinimal,
  jujutsu,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "lx";
  version = "0.10.2";

  src = fetchFromGitHub {
    owner = "wjv";
    repo = "lx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kHYHiXUfawBPUGkkd7eP4015w5zaFXrc46DSgmeBKc0=";
  };

  cargoHash = "sha256-Y0K6ssoM7c+T/vQY3WbM+EN/Y9hjjKr+SVNAp01PQSU=";

  buildFeatures = ["jj"];

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];
  buildInputs = [
    libgit2
    zlib
  ];

  env.LIBGIT2_NO_VENDOR = 1;

  # tests/cli_vcs.rs builds its fixture repos with the `git` and `jj` CLIs.
  # Without them the git tests fail and the jj tests skip silently, so the
  # feature this package enables would go untested.
  nativeCheckInputs = [
    gitMinimal
    jujutsu
  ];

  # The man pages ship pre-rendered in the repo. clap_complete has no nushell
  # generator, so only bash/zsh/fish completions are generated.
  postInstall = ''
    installManPage man/lx.1 man/lxconfig.toml.5
    installShellCompletion --cmd lx \
      --bash <("$out/bin/lx" --completions bash) \
      --zsh <("$out/bin/lx" --completions zsh) \
      --fish <("$out/bin/lx" --completions fish)
  '';

  meta = {
    description = "File lister with personality: an exa fork with tree view and git/jj status";
    homepage = "https://github.com/wjv/lx";
    changelog = "https://github.com/wjv/lx/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "lx";
    platforms = lib.platforms.unix;
  };
})
