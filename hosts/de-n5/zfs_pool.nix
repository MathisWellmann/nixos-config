_: let
  const = import ./constants.nix {};
in {
  boot = {
    supportedFilesystems = ["zfs"];
    kernelParams = ["zfs.zfs_arc_max=24000000000"]; # 24GB ARC size limit
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
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
}
