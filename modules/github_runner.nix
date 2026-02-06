# Configure a Github Runner.
# Set the `tokenFile` to the correct location where the secret is stored.
{
  pkgs,
  config,
  ...
}: let
  hostname = config.networking.hostName;
  repos = ["lfest-rs" "trade_aggregation-rs" "openresponses-rs" "sliding_features-rs"];
in {
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
    home = "/var/lib/github-runner";
    createHome = true;
  };
  users.groups.github-runner = {};

  # For each repo, construct a github runner.
  services.github-runners = builtins.listToAttrs (map (repo: {
      name = "${hostname}-${repo}";
      value = {
        enable = true;

        url = "https://github.com/MathisWellmann/${repo}";

        tokenFile = "/run/secrets/gh_runner_token_${repo}";

        user = "github-runner";
        group = "github-runner";

        extraLabels = ["nixos" "${pkgs.stdenv.hostPlatform.system}"];

        # Optional: runner group (enterprise/org feature)
        runnerGroup = "default";

        # Work directory (isolated from system)
        workDir = "/var/lib/github-runner/${repo}";
      };
    })
    repos);

  # Ensure runner directories have strict permissions
  systemd.tmpfiles.rules =
    map (
      repo: "d /var/lib/github-runner/${repo} 0700 github-runner github-runner -"
    )
    repos;
}
