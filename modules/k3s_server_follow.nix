{config, ...}: let
  ips = import ./static_ips.nix;
in {
  age.secrets.k3s_token.file = ../secrets/k3s_token.age;
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s_token.path;
    serverAddr = "https://${ips.de-msa2_ip}:6443";
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
}
