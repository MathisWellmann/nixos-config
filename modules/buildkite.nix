{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    buildkite_agent = lib.mkOption {
      default = "meshify";
      description = "The buildkite agent name that will show up in the web inferface.";
    };
    buildkite_queue = lib.mkOption {
      default = "default-queue";
      description = "The buildkite queue that will be used.";
    };
  };

  config = {
    services.buildkite-agents.${config.buildkite_agent} = {
      enable = true;
      name = "${config.buildkite_agent}";
      # Copy the raw token string into that file and make root the owner.
      tokenPath = /var/buildkite/token_${config.buildkite_agent};
      # To be able to clone private repos, create an ssh key. E.g:
      # ssh-keygen -t rsa -b 4096
      # Then add this key to the repos `deploy keys` section in the settings.
      # See: https://buildkite.com/docs/agent/v3/github-ssh-keys
      privateSshKeyPath = /var/buildkite/ssh_key_${config.buildkite_agent};

      tags = {
        queue = config.buildkite_queue;
      };

      # tools needed for basic nix-build
      runtimePackages = [
        pkgs.gnutar
        pkgs.bash
        pkgs.nix
        pkgs.gzip
        pkgs.git
      ];
    };
  };
}
