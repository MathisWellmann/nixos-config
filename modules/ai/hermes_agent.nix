{model, ...}: _: {
  services.hermes-agent = {
    enable = true;
    settings.model.default = model;
    environmentFiles = ["/etc/secrets/hermes-agent.env"];
    addToSystemPackages = true;
  };
}
