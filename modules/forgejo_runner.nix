{
  forgejo_url,
  state_dir,
  runner_capacity ? 1,
  # Persistent cargo cache the nexus CI workflow writes to (set via
  # `CARGO_HOME`/`CARGO_TARGET_DIR` in `.forgejo/workflows/ci.yml`). It lives
  # outside the runner's `state_dir` and systemd's `CacheDirectory`, so nothing
  # ever prunes it -- the per-job `target/<job>` dirs accumulate until they fill
  # the host disk (they reached 320G on desg0 and tipped the node into
  # disk-pressure eviction). The timer below bounds it. Empty string disables.
  ci_cache_dir ? "/var/cache/nexus-ci",
  # Per-job target dirs untouched for longer than this are pruned.
  ci_cache_prune_age_days ? 3,
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

  # Bound the persistent cargo CI cache so it cannot grow without limit and
  # fill the host disk (see `ci_cache_dir` above). Runs daily: drops the
  # incremental-compilation dirs outright (useless in fresh-checkout CI; the
  # workflow also sets `CARGO_INCREMENTAL=0`, this reaps any pre-existing ones)
  # and removes per-job `target/<job>` dirs not modified for the configured age.
  systemd.services.nexus-ci-cache-prune = lib.mkIf (ci_cache_dir != "") {
    description = "Prune the persistent cargo CI cache to bound disk usage";
    serviceConfig.Type = "oneshot";
    path = [pkgs.coreutils pkgs.findutils];
    script = ''
      cache=${lib.escapeShellArg ci_cache_dir}/target
      # Nothing to do until the CI cache has been created by a first run.
      [ -d "$cache" ] || exit 0
      # Incremental compilation artifacts: large and worthless in CI.
      find "$cache" -type d -name incremental -prune -exec rm -rf {} +
      # Stale per-job target dirs (no build in the retention window).
      find "$cache" -mindepth 1 -maxdepth 1 -type d \
        -mtime +${toString ci_cache_prune_age_days} -exec rm -rf {} +
    '';
  };
  systemd.timers.nexus-ci-cache-prune = lib.mkIf (ci_cache_dir != "") {
    description = "Daily prune of the persistent cargo CI cache";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
