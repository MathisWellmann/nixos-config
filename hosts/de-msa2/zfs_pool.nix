{
  config,
  lib,
  ...
}: let
  const = import ./constants.nix;
  static_ips = import ../../modules/static_ips.nix;
  zpool = "${config.boot.zfs.package}/bin/zpool";
  # Per-vdev TRIM rate. Unthrottled TRIM on the QLC/DRAM-less Crucial P3 in
  # the raidz1 pushed its latency to ~100ms, and raidz runs at the speed of
  # its slowest member, so iggy's io_uring workers piled up in D-state
  # (load ~45 on 2026-10-19). ~1 TiB free per vdev at 32 MiB/s is ~9h.
  trim_rate = "32M";
in {
  boot = {
    supportedFilesystems = ["zfs"];
    # To shrink the limit immediately:
    # sudo sh -c 'echo 17179869184 > /sys/module/zfs/parameters/zfs_arc_max'
    # Then clearing the caches:
    # sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
    kernelParams = [
      "zfs.zfs_arc_max=32000000000" # 32GB ARC size limit
      # Default 2. One in-flight discard per vdev leaves the slow Crucial P3
      # more queue slots for foreground reads/writes while TRIM runs.
      "zfs.zfs_vdev_trim_max_active=1"
    ];
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
      # Scrub (Sat) and TRIM (Wed) are 3.5 days apart so they never overlap.
      # Both used to be `weekly` (Mon 00:00 + up to 6h random delay) and ran
      # together. A scrub takes ~1.5 days, TRIM ~9h at `trim_rate`. The
      # guards in `systemd.services` below cover catch-up runs after downtime
      # (`Persistent = yes`).
      autoScrub = {
        enable = true;
        interval = "Sat *-*-* 01:00:00";
        randomizedDelaySec = "1h";
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
        host = static_ips.de-n5_ip;
        identityFilePath = "/root/.ssh/id_ed25519";
        localFilesystem = "nvme_pool";
        remoteFilesystem = "hdd_pool";
        username = "root";
      };
      trim = {
        enable = true;
        interval = "Wed *-*-* 01:00:00";
        randomizedDelaySec = "1h";
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

      # Media dirs on the external btrfs drive that moved here from the
      # decommissioned `elitedesk` (2026-08-08). poweredge still mounts by IP
      # because it does not resolve Tailscale names.
      media_dirs = [
        "movies"
        "series"
      ];
      media_exports =
        lib.strings.concatMapStrings (
          dir:
            "/mnt/external_hdd/"
            + dir
            + " meshify(rw,sync,no_subtree_check)\n"
            + "/mnt/external_hdd/"
            + dir
            + " razerblade(rw,sync,no_subtree_check)\n"
            + "/mnt/external_hdd/"
            + dir
            + " ${static_ips.poweredge_ip}(rw,sync,no_subtree_check)\n"
        )
        media_dirs;
    in {
      enable = true;
      exports = lib.strings.concatStrings [
        exports_for_meshify
        exports_for_razerblade
        # exports_for_poweredge
        "/nvme_pool/magewe tensorbook(rw,sync,no_subtree_check)\n"
        media_exports
      ];
    };
  };
  systemd.services = {
    # Wait for `tailscaled` mesh VPN to be ready before starting `nfs-server`, otherwise it will fail to resolve hosts.
    nfs-server = {
      after = ["tailscaled.service"];
      wants = ["tailscaled.service"];
    };
    # Each job waits for the other to finish, so a late catch-up run cannot
    # overlap. `zpool wait` returns at once when nothing runs (also for a
    # suspended trim). It can block for hours, so no start timeout.
    zfs-scrub.serviceConfig = {
      ExecStartPre = "${zpool} wait -t trim nvme_pool";
      TimeoutStartSec = "infinity";
    };
    # Replaces the upstream ExecStart:
    # - `-r` rate-limits TRIM (it is unthrottled by default). Also needed on
    #   resume: `zpool trim` without `-r` resumes at full speed.
    # - `-w` keeps the unit active until TRIM is done, so the scrub guard
    #   above can see it in systemd too.
    # - Only nvme_pool, and no `|| true`, so a failed TRIM shows up as a
    #   failed unit.
    zpool-trim.serviceConfig = {
      ExecStartPre = "${zpool} wait -t scrub nvme_pool";
      ExecStart = lib.mkForce "${zpool} trim -w -r ${trim_rate} nvme_pool";
      TimeoutStartSec = "infinity";
    };
  };
}
