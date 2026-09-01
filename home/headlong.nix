# Headlong, pointed at the SGLang server on desg0 (see
# hosts/desg0/sglang_qwen3_container.nix): OpenAI-compatible API on
# qwen3_port, no API key (the server runs without `--api-key`).
#
# The endpoint is written to ~/.headlong/.env — headlong's own state file,
# which every tool layers *below* real environment variables (bin/llm,
# bin/shellm, headlong-init). The lines mirror what `headlong-init` itself
# persists (provider + chat-completions URL + model), so an unattended
# headlong-init validates this config instead of re-asking.
#
# Written as a real file, not a store symlink: headlong-init rewrites this
# file in place under `set -e`, and a symlink into the store would die on
# the first `touch`. Note: keys headlong-init adds to the file (Docker
# sandbox consent) are reset to defaults by the next activation.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  desg0 = import ../hosts/desg0/constants.nix;
  headlongHome = "${config.home.homeDirectory}/.headlong";
  # The live, writable headlong tree the `headlong-web` wrapper runs from
  # (see pkgs/headlong.nix): headlong's own app-dir convention, auto-resolved
  # by every tool. Identities live here, so links must point into this tree —
  # its `persona` resolves an identity from its own location.
  headlongApp = "${config.home.homeDirectory}/.headlong/app";
  # Make an identity's name a command (`galt`, `galt stop`, ...) by symlinking it
  # to the live tree's `persona` tool. headlong's own `headlong-init` does this
  # per identity, but web-created identities skip it — so link the ones we want.
  mkIdentityCmd = name: pkgs.runCommand "headlong-cmd-${name}" {} ''
    mkdir -p $out/bin
    ln -s ${headlongApp}/tools/persona $out/bin/${name}
  '';
in {
  home.packages = [
    inputs.self.packages.${system}.headlong
    pkgs.bun # headlong-web builds its viewer frontend with bun on first start
    (mkIdentityCmd "galt") # new web identities: use `persona <name>`, or add another mkIdentityCmd
    (mkIdentityCmd "ada")
  ];

  home.activation.writeHeadlongEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # DRY_RUN is only *set* in dry-run mode (unset under `set -u` on live runs).
    if [[ -v DRY_RUN ]]; then
      echo "dry run: would write ${headlongHome}/.env"
    else
      mkdir -p "${headlongHome}"
      {
        printf 'LLM_PROVIDER=openai-compatible\n'
        printf 'SHELLM_API_URL=http://${desg0.hostname}:${toString desg0.qwen3_port}/v1/chat/completions\n'
        printf 'SHELLM_MODEL=${desg0.qwen3Model}\n'
      } > "${headlongHome}/.env"
      chmod 600 "${headlongHome}/.env"
    fi
  '';
}
