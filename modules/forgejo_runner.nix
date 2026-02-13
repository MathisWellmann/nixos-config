{
  forgejo_url,
  state_dir,
  runner_capacity ? 1,
}: {
  pkgs,
  config,
  ...
}: {
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
  # Ensure systemd allows writing to that ZFS directory.
  systemd.services.gitea-runner-default.serviceConfig = {
    ReadWritePaths = [
      state_dir
    ];
    # Raise open file limits.
    LimitNOFILE = 1048576;
  };
}
