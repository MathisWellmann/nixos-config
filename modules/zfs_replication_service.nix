{pkgs, ...}: let
  script = import ../scripts/zfs_replication.nix { inherit pkgs; };
in {
  systemd = {
    services.zfs-replication = {
      description = "ZFS Replication Service";
      # script = pkgs.writeShellScript "zfs-replication-script" script;
      inherit script;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        # Allow access to ZFS
        AmbientCapabilities = "CAP_SYS_ADMIN CAP_DAC_READ_SEARCH";
        # If your system uses /etc/ssh/ keys
        Environment = ["HOME=/root"];
        After = "network-online.target";
        Wants = "network-online.target";
      };
    };
    timers.zfs-replication = {
      description = "ZFS Replication Timer";
      partOf = ["zfs-replication.service"];
      timerConfig = {
        OnCalendar = "hourly"; # Runs every hour
        Persistent = true; # Run immediately if missed (e.g., system was off)
        Unit = "zfs-replication.service";
      };
      wantedBy = ["timers.target"];
    };
  };
}
