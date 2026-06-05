{config, ...}: {
  age.secrets.k3s_token.file = ../secrets/k3s_token.age;
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    tokenFile = config.age.secrets.k3s_token.path;
  };
  networking.firewall.allowedTCPPorts = [
    2379 # HA
    2380 # HA
    6433 # K8s supervisor and Kubernetes API server
    10250 # Kubelet metrics and API
  ];
}
