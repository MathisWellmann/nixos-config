_: let
  pool_name = "SATA_SSD_POOL";
in {
  boot = {
    supportedFilesystems = ["zfs"];
    kernelParams = ["zfs.zfs_arc_max=128000000000"]; # 128 GB ARC size limit
    zfs = {
      forceImportRoot = false;
      extraPools = [pool_name];
    };
  };
  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
      pools = [pool_name];
    };
    autoSnapshot.enable = true;
    trim = {
      enable = true;
      interval = "weekly";
    };
  };
}
