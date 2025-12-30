
{...}: let
  const = import ./constants.nix;
in {
  boot = {
    supportedFilesystems = ["zfs"];
    kernelParams = ["zfs.zfs_arc_max=32000000000"]; # 32GB ARC size limit
    zfs = {
      forceImportRoot = false;
      extraPools = [
        "hdd_pool"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    const.nfs_port
  ];
  services = {
    zfs = {
      autoScrub = {
        enable = true;
        interval = "weekly";
        pools = [
          "hdd_pool"
        ];
      };
      # Must run `sudo zfs set com.sun:auto-snapshot=true $POOL` to set the pool which to snapshot.
      autoSnapshot = {
        enable = true;
        hourly = 24;
        daily = 7; # Keep 7 daily snapshots
        weekly = 4;
        monthly = 12;
      };
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}
