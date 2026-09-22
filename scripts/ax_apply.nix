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
    # ax reaches ax-server through a `kubectl port-forward`, so a kubeconfig
    # for the fleet is required. On a k3s node run it as root; the k3s admin
    # config is picked up when KUBECONFIG is unset.
    if [[ -z "''${KUBECONFIG:-}" && -r /etc/rancher/k3s/k3s.yaml ]]; then
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
