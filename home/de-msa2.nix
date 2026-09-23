# de-msa2 home: the shared home plus the DeepSeek Harness CLI.
{
  lib,
  pkgs,
  osConfig,
  ...
}: {
  imports = [
    ./home.nix
    ./deepseek-harness.nix
  ];

  # DeepSeek Harness (`dsh`), pointed at the vLLM server on `desg0`.
  programs.deepseek-harness.enable = true;

  # Fleet k3s API for kubectl, `ax` and `kubectl-ate` as m (the default
  # kubeconfig; there is no other cluster here). Loopback is in the API cert.
  home.file.".kube/config".source = import ./k3s_kubeconfig.nix {
    inherit pkgs;
    server = "https://127.0.0.1:6443";
    tokenFile = osConfig.age.secrets.k3s_meshify_admin_token.path;
  };

  # Jeff's life log writes to /var/lib/monty-persona/sessions (the persona
  # service cannot write into /home/m, which is 0700). Expose it as the
  # harness's sessions root: m has group access, so the harness lists jeff's
  # lives next to its own sessions and writes its own there, too.
  # home-manager has no runtime-symlink option (`.source` strings are
  # evaluated as paths), so link it in at activation instead.
  home.activation.dshSessions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -d "$HOME/.dsh/sessions" ] && [ ! -L "$HOME/.dsh/sessions" ]; then
      echo "warning: ~/.dsh/sessions is a real directory; not linking the persona sessions root" >&2
    else
      run mkdir -p "$HOME/.dsh"
      run ln -sfn /var/lib/monty-persona/sessions "$HOME/.dsh/sessions"
    fi
  '';
}
