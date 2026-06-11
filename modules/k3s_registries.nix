{config, ...}: {
  # Trust the plain-HTTP Forgejo container registry on de-msa2, so the
  # cluster can pull images like `de-msa2:2999/mathiswellmann/tikr-iggy`.
  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      "de-msa2:2999":
        endpoint:
          - "http://de-msa2:2999"
  '';
  # k3s only reads `registries.yaml` at startup.
  systemd.services.k3s.restartTriggers = [
    config.environment.etc."rancher/k3s/registries.yaml".source
  ];
}
