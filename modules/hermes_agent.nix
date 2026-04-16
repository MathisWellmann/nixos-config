_: {
    services.hermes-agent = {
      enable = true;
      settings.model.default = "unsloth/Qwen3.5:27B";
      environmentFiles = ["/etc/secrets/hermes-agent.env"];
      addToSystemPackages = true;
    };
}
