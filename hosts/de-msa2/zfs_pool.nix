{lib, ...}: let
  const = import ./constants.nix {};
in {
  boot = {
    supportedFilesystems = ["zfs"];
    kernelParams = ["zfs.zfs_arc_max=32000000000"]; # 32GB ARC size limit
    zfs = {
      forceImportRoot = false;
      extraPools = [
        "nvme_pool"
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
          "nvme_pool"
        ];
      };
      # Must run `sudo zfs set com.sun:auto-snapshot=true $POOL` to set the pool which to snapshot.
      autoSnapshot = {
        enable = true;
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 12;
      };
      # The target and source must have the `lz4` package installed.
      # root user must be able to log in to the target as root without password:
      # `sudo ssh-copy-id root@target`
      autoReplication = {
        enable = true;
        followDelete = true;
        host = "de-n5";
        identityFilePath = "/root/.ssh/id_ed25519";
        localFilesystem = "nvme_pool";
        remoteFilesystem = "hdd_pool";
        username = "root";
      };
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
    nfs.server = let
      common_dirs = [
        "magewe"
        "ilka"
        "pdfs"
        "music"
        "video"
      ];
      exports_for_meshify =
        lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " meshify(rw,sync,no_subtree_check)\n")
        common_dirs;
      # exports_for_poweredge =
      #   lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " ${static_ips.poweredge_ip}(rw,sync,no_subtree_check)\n")
      #   common_dirs;
      exports_for_razerblade =
        lib.strings.concatMapStrings (dir: "/nvme_pool/" + dir + " razerblade(rw,sync,no_subtree_check)\n")
        common_dirs;
    in {
      enable = true;
      exports = lib.strings.concatStrings [
        exports_for_meshify
        exports_for_razerblade
        # exports_for_poweredge
        "/nvme_pool/magewe tensorbook(rw,sync,no_subtree_check)\n"
      ];
    };
  };
  # Wait for `tailscaled` mesh VPN to be ready before starting `nfs-server`, otherwise it will fail to resolve hosts.
  systemd.services.nfs-server = {
    after = ["tailscaled.service"];
    wants = ["tailscaled.service"];
  };
}
