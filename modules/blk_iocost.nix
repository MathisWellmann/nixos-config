# Enable the cgroup-v2 `blk-iocost` controller for the given block devices.
#
# Why: systemd's `IOWeight=` (see `forgejo_runner.nix`, 2026-07-02 incident --
# CI disk I/O stalled etcd fsync/ReadIndex on desg0 and flapped the node
# NotReady) writes the cgroup `io.weight`, but the kernel needs an arbiter to
# actually enforce proportional weights. The two implementations are the BFQ
# scheduler and blk-iocost. On NVMe the scheduler is `none` (BFQ is not even
# built for it), so without this module IOWeight is silently inert.
#
# blk-iocost is enabled per device by writing `MAJ:MIN enable=1` to the
# cgroup-root `io.cost.qos` file. That is runtime state, not persisted by the
# kernel, so a boot-time oneshot re-applies it reproducibly. The default
# linear cost model is used; if weight conformance ever matters enough,
# generate tuned parameters with resctl-bench and write them to
# `io.cost.model`.
{
  # Block device names under /sys/block, e.g. ["nvme0n1"]. The MAJ:MIN is
  # resolved at runtime from sysfs so a device renumbering across kernel
  # updates cannot silently break the enable line.
  devices,
}: {lib, ...}: {
  systemd.services.blk-iocost = {
    description = "Enable cgroup-v2 blk-iocost I/O weight arbitration";
    wantedBy = ["multi-user.target"];
    # Kernel without CONFIG_BLK_CGROUP_IOCOST: skip instead of fail.
    unitConfig.ConditionPathExists = "/sys/fs/cgroup/io.cost.qos";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStringsSep "\n" (dev: ''
      echo "$(cat /sys/block/${dev}/dev) enable=1" > /sys/fs/cgroup/io.cost.qos
    '') devices;
  };
}
