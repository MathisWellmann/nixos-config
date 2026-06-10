{
  # Where should the generated manifests be stored?
  nixidy.target.repository = "https://github.com/MathisWellmann/nixos-config.git";
  nixidy.target.branch = "main";
  nixidy.target.rootPath = "./manifests/prod";

  # Define the nginx application
  applications.nginx = {
    # Deploy to the "nginx" namespace
    namespace = "nginx";

    # Automatically create the namespace
    createNamespace = true;

    # Define Kubernetes resources
    resources = {
      # Deployment
      deployments.nginx.spec = {
        replicas = 2;
        selector.matchLabels.app = "nginx";
        template = {
          metadata.labels.app = "nginx";
          spec.containers.nginx = {
            image = "nginx:1.25.1";
            ports.http.containerPort = 80;
          };
        };
      };

      # Service
      services.nginx.spec = {
        selector.app = "nginx";
        ports.http.port = 80;
      };
    };
  };
}
