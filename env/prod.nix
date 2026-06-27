{
  imports = [
    ./argocd.nix
    ./cert_manager.nix
    ./host_ingress.nix
  ];

  # Where should the generated manifests be stored?
  nixidy.target.repository = "https://github.com/MathisWellmann/nixos-config.git";
  nixidy.target.branch = "main";
  nixidy.target.rootPath = "./manifests/prod";

  # Let ArgoCD automatically sync, prune and self-heal all applications,
  # so pushing rendered manifests to the repo is all that is needed.
  nixidy.defaults.syncPolicy.autoSync = {
    enable = true;
    prune = true;
    selfHeal = true;
  };
}
