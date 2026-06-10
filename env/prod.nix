{
  imports = [
    ./argocd.nix
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

  applications.nginx = {
    namespace = "nginx";
    createNamespace = true;

    resources = {
      # Deployment with ConfigMap volume
      deployments.nginx.spec = {
        replicas = 2;
        selector.matchLabels.app = "nginx";
        template = {
          metadata.labels.app = "nginx";
          spec = {
            containers.nginx = {
              image = "nginx:1.25.1";
              ports.http.containerPort = 80;
              volumeMounts."/usr/share/nginx/html".name = "html";
            };
            volumes.html.configMap.name = "nginx-html";
          };
        };
      };

      # Service
      services.nginx.spec = {
        selector.app = "nginx";
        ports.http.port = 80;
      };

      # ConfigMap with HTML content
      configMaps.nginx-html.data."index.html" = ''
        <!DOCTYPE html>
        <html>
          <body>
            <h1>Hello from nixidy!</h1>
          </body>
        </html>
      '';
    };
  };
}
