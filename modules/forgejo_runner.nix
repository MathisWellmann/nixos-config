{
  forgejo_url,
  state_dir,
  runner_capacity ? 1,
}: {
  pkgs,
  config,
  lib,
  ...
}: {
  users.users.gitea-runner = {
    isSystemUser = true;
    group = "gitea-runner";
    home = "/var/lib/gitea-runner";
  };
  users.groups.gitea-runner = {};

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      name = "${config.networking.hostName}";
      url = forgejo_url;
      # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
      tokenFile = "/etc/secrets/forgejo_runner";
      labels = [
        # Provide native execution on the host.
        "native:host"
      ];
      hostPackages = with pkgs; [
        nix
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        nodejs
        wget
      ];
      settings = {
        # Execute this many tasks concurrently at the same time.
        runner.capacity = runner_capacity;
        cache.dir = "${state_dir}/cache";
        host.workdir_parent = state_dir;
      };
    };
  };
  # Run as a static user so /var/cache/<name> is a normal directory (not the
  # /var/cache/private/ symlink that DynamicUser would create), and so the UID
  # is stable across rebuilds — required for cargo to exec build scripts it
  # writes into the cache.
  systemd.services.gitea-runner-default.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "gitea-runner";
    Group = "gitea-runner";
    # Grant the runner process the `docker` group so cluster creation isn't denied.
    # Requires the host to enable `virtualisation.docker` (desg0 does), which provides this group.
    SupplementaryGroups = ["docker"];
    ReadWritePaths = [
      state_dir
      "/var/sccache"
    ];
    CacheDirectory = [
      "nexus-target"
      "sccache"
    ];
    LimitNOFILE = 1048576;
  };
  # For CI to accept flake nix config like binary cache substituters, the CI user must be trusted.
  nix.settings.trusted-users = ["gitea-runner"];
}
