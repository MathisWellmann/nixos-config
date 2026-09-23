{
  pkgs,
  ax,
}:
pkgs.writeShellApplication {
  name = "ax_apply";
  runtimeInputs = [ax pkgs.kubectl];
  text = ''
    # Apply ax API objects (they live in ax's Redis, not in Kubernetes).
    #
    #   ax_apply                 re-apply shared objects from manifests/ax/:
    #                            Gateways, Models, Workspaces (in that order)
    #   ax_apply FILE...         apply exactly these files (e.g. a Task)
    #
    # ax reaches ax-server through `$AX_SERVER` or a `kubectl port-forward`
    # with the current kubeconfig (de-msa2 and meshify ship one for m, see
    # home/k3s_kubeconfig.nix). Run it as m, not via sudo: ax writes its
    # tunnel state to ~/.ax and sudo keeps HOME, leaving root-owned files.
    if [[ $EUID -eq 0 && -z "''${KUBECONFIG:-}" && -r /etc/rancher/k3s/k3s.yaml ]]; then
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi

    files=("$@")
    if [[ ''${#files[@]} -eq 0 ]]; then
      shopt -s nullglob
      dir=${../manifests/ax}
      files=("$dir"/gateway-*.yaml "$dir"/model-*.yaml "$dir"/workspace-*.yaml)
    fi

    for f in "''${files[@]}"; do
      echo "== $(basename "$f")"
      ax apply -f "$f"
    done
  '';
}
