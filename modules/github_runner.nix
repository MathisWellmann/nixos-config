# Configure a Github Runner.
# Set the `tokenFile` to the correct location where the secret is stored.
{pkgs, config,...}: let
  hostname = config.networking.hostName;
in {
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
    home = "/var/lib/github-runner";
    createHome = true;
  };
  users.groups.github-runner = { };

  # TODO: support more repos, which will require setting distinct `tokenFile`s per repo.
  services.github-runners."${hostname}-lfest-rs" = {
    enable = true;
   
    url = "https://github.com/MathisWellmann/lfest-rs";
    
    tokenFile = "/run/secrets/gh_runner_token";
    
    user = "github-runner";
    group = "github-runner";
    
    extraLabels = [ "nixos" "${pkgs.stdenv.hostPlatform.system}" ];
    
    # Optional: runner group (enterprise/org feature)
    runnerGroup = "default";
    
    # Work directory (isolated from system)
    workDir = "/var/lib/github-runner/work";
  };

  systemd.tmpfiles.rules = [
    # Ensure runner directories have strict permissions
    "d /var/lib/github-runner 0700 github-runner github-runner -"
    "d /var/lib/github-runner/work 0700 github-runner github-runner -"
  ];
}
