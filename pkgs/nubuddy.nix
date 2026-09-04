# nubuddy — the "IPython is all you need" pattern ported to nushell, see
# ../nubuddy/README.md.
#
# Installs the scripts under share/nubuddy/ (so a REPL can `source` them, see
# home/shell.nix) and a `nubuddy` one-shot CLI whose NU_BUDDY_* env defaults
# point at the Qwen3.8 SGLang server on desg0. Already-set env vars win.
{
  lib,
  stdenvNoCC,
  nushell,
  baseUrl ? null,
  model ? null,
  apiKey ? "none",
}: let
  desg0 = import ../hosts/desg0/constants.nix;
  effectiveBaseUrl =
    if baseUrl != null
    then baseUrl
    else "http://${desg0.hostname}:${toString desg0.qwen3_port}/v1";
  effectiveModel =
    if model != null
    then model
    else desg0.qwen3Model;
in
  stdenvNoCC.mkDerivation {
    pname = "nubuddy";
    version = "0.1.0";
    src = ../nubuddy;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm644 nubuddy.nu nubuddy-cli.nu -t $out/share/nubuddy
      mkdir -p $out/bin
      cat > $out/bin/nubuddy <<EOF
      #!${stdenvNoCC.shell}
      export NU_BUDDY_BASE_URL="\''${NU_BUDDY_BASE_URL:-${effectiveBaseUrl}}"
      export NU_BUDDY_MODEL="\''${NU_BUDDY_MODEL:-${effectiveModel}}"
      export NU_BUDDY_API_KEY="\''${NU_BUDDY_API_KEY:-${apiKey}}"
      exec ${lib.getExe nushell} $out/share/nubuddy/nubuddy-cli.nu "\$@"
      EOF
      chmod +x $out/bin/nubuddy
      runHook postInstall
    '';

    passthru = {
      inherit effectiveBaseUrl effectiveModel apiKey;
    };

    meta = {
      description = "An intelligent nushell: LLM tool loop over your shell history and state";
      homepage = "https://nathancooper.io/blog/2026-08-10-ipython-is-all-you-need";
      license = lib.licenses.mit;
      platforms = nushell.meta.platforms;
      mainProgram = "nubuddy";
    };
  }
