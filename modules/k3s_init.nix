{ pkgs, config, ... }: {
  imports = [./k3s_registries.nix];
  age.secrets.k3s_token.file = ../secrets/k3s_token.age;
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    tokenFile = config.age.secrets.k3s_token.path;
  };
  networking.firewall = {
    allowedTCPPorts = [
      2379 # HA
      2380 # HA
      6443 # K8s supervisor and Kubernetes API server
      10250 # Kubelet metrics and API
    ];
    allowedUDPPorts = [
      8472 # Flannel VXLAN, required for cross-node pod networking
    ];
  };

  # K3s re-applies its built-in traefik chart on startup, wiping any manual
  # patch, so re-apply the pin after every k3s start.
  #
  # Why pinned to de-n5: on desg0 (kernel 7.1.6) the Go-based traefik proxy
  # crawls at ~0.3 MiB/s while everything below it (raw TCP to the pod, the
  # backend, other nodes with kernel 6.18) runs at full 10 Gbit speed -- a
  # kernel 7.1.6 x Go runtime regression in socket wakeups. Remove this once
  # desg0 is on a working kernel.
  systemd.services.traefik-node-pin = {
    description = "Pin the k3s built-in traefik deployment to de-n5";
    wantedBy = ["multi-user.target"];
    after = ["k3s.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      k3s=${pkgs.k3s}/bin/k3s
      # Retry: the API may not be accepting requests right after k3s starts.
      for i in $(seq 1 60); do
        "$k3s" kubectl -n kube-system patch deployment traefik --type strategic \
          --patch '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"de-n5"}}}}}' \
          >/dev/null && exit 0
        sleep 2
      done
      echo "traefik-node-pin: failed to pin traefik to de-n5" >&2
      exit 1
    '';
  };
}
