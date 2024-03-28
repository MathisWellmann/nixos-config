{pkgs, ...}: let
  agent_name = "meshify";
in {
  services.buildkite-agents.${agent_name} = {
    enable = true;
    name = "${agent_name}";
    # Copy the raw token string into that file and make root the owner.
    tokenPath = /var/buildkite/token_${agent_name};
    tags = {
      queue = "default-queue";
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
}
