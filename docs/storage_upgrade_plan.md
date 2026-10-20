# Storage upgrade plan: iggy, ClickHouse, poweredge

Goal: give the latency-critical services (the iggy cluster and, later,
ClickHouse Keeper) their own fast fsync devices. Then build a replicated
ClickHouse on local NVMe, and turn poweredge into a tiered storage node.
Distributed object/block storage (rustfs, Ceph) comes last, only once the
prerequisites hold.

The items are in priority order: the first item gives the most benefit for
the least cost and risk. Each item says why it is at that position.

Legend: `[ ]` open, `[x]` done, `[-]` dropped. "Unverified" marks a claim
that was inferred, not measured or read in the source.

## Current state (2026-10-20)

| Host | Hardware | Relevant storage |
|---|---|---|
| de-msa2 | Minisforum MS-A2 | `nvme_pool` raidz1: 3x Lexar NM790 4TB + 1x Crucial P3 4TB (QLC, DRAM-less). iggy prod/dev data in `/nvme_pool/iggy-{,dev-}cluster` (plain directories, not datasets). |
| desg0 | Supermicro H13SSL-N, EPYC 9654 | Crucial P310 1TB (DRAM-less) + Crucial T710 4TB, ext4. iggy in `/home/iggy`. Free slots: SLOT1 Gen5 x16, SLOT2 Gen5 x8, SLOT3 Gen5 x16. |
| de-n5 | Minisforum N5 | 3x Lexar NM1090 PRO 4TB, 5x HDD (backup target). iggy in `/var/lib/iggy` on the ext4 root. |
| poweredge | Dell PowerEdge R7525 (2x EPYC Rome/Milan, 64 threads, 512 GB, BIOS 2.14.1) | 4x Samsung 870 QVO 8TB (SATA, QLC) behind PERC, Sabrent Rocket Q4 (QLC) boot drive. Usually powered off. |

All NVMe and SSD drives listed above are consumer drives without power-loss
protection (PLP).

Measured on de-msa2 (10 s `zpool iostat -vl`): the Crucial P3 has a write
wait of 349 ms. The Lexars have 4-8 ms. Pool writes are only about 29 MB/s,
so this is a latency problem, not a bandwidth problem. Load average was
about 34. Most of the D-state threads were iggy `iou-wrk` threads. The
Crucial TRIM is suspended at 63% since 2026-10-19.

### Why iggy is sensitive to fsync latency

- nexus creates the topics with `Durability::Persisted`
  (`nexus/tikr-iggy/src/topic.rs:44-51`). A replica must write the op to
  stable storage before it acks. The default `Replicated` mode does not
  wait for this.
- VSR quorum is `f + 1` = 2 of 3 (`iggy/core/consensus/src/impls.rs:837`).
  The primary always counts itself (loopback `prepare_ok`).
- Commit latency is about
  `max(primary_fsync, min over followers(RTT + follower_fsync))`.
  The primary's disk is always on the critical path. The slowest follower
  is not.
- de-msa2 runs `--replica-id 0`, so it is the primary in view 0, the normal
  steady state (unverified: the current view was not checked). That puts
  the slowest disk in the cluster into every commit.
- On ZFS without a SLOG, every fsync goes to the ZIL inside the raidz1. The
  ZIL is only as fast as the Crucial P3.

## P0: no-cost fixes (do now)

- [ ] **Check which replica is iggy primary right now.** This confirms or
  refutes the "de-msa2 is on every commit" analysis before money is spent.
  Use the iggy HTTP API or its metrics.
- [ ] **Make the iggy data directories ZFS datasets on de-msa2.**
  `nvme_pool/iggy-cluster` and `nvme_pool/iggy-dev-cluster` with
  `com.sun:auto-snapshot=false`. Snapshots of a log that deletes its own
  segments every minute only waste space. A dataset can also later move to
  another pool with one `zfs send`.
  - Caveat: stop the replica first, and let the other two replicas keep the
    quorum. Do one environment at a time.
- [ ] **Resume the suspended Crucial TRIM only off-peak and throttled.**
  `zpool trim -r 32M nvme_pool <crucial-vdev>`.
  - Caveat: a plain `zpool trim` runs unthrottled. That is what caused the
    2026-10-19 load spike.
- [ ] **Alert on per-device write latency, not on PSI.**
  `rate(node_disk_write_time_seconds_total) / rate(node_disk_writes_completed_total)`
  per device. iggy's io_uring waits hold PSI io at about 80% even when the
  disks are idle, so PSI cannot show a slow member drive.
- [ ] **Fix the desg0 GPU PCIe link.** The RTX PRO 6000 (`41:00.0`, SLOT5)
  links at Gen5 **x4 (downgraded)** instead of x16, which is a quarter of
  its PCIe bandwidth. Check the slot bifurcation in the BIOS, any riser, and
  that the card is fully seated. Do this when desg0 is open for P2.

## P1: Optane for iggy on de-msa2 (highest-value hardware)

Why first: de-msa2 is probably the primary, so its fsync latency is in every
commit. A dedicated Optane drive takes iggy off the raidz1 and away from the
Crucial at once. The other pool users are not affected by the change.

- [ ] Buy an **Intel Optane P1600X 118 GB** (M.2 2280, Gen3 x4,
  discontinued, cheap used). Its fsync latency is about 10-20 us. 118 GB
  holds both iggy environments, because each topic is capped at 1 GiB with
  24 h retention.
- [ ] Check that the MS-A2 has a free M.2 slot. 4 slots are already used by
  `nvme_pool`, so check this before ordering.
- [ ] Format the drive as a single device with XFS or ext4. Do not put it in
  a raidz or a shared pool. A single-drive ZFS pool also works but adds
  about 50-100 us per sync.
- [ ] Change `dataPath` for de-msa2 in `nexus/env/tikr/iggy-clusters.nix`.
  Then let the replica resync from the other two.
- Caveats:
  - A single drive has no local redundancy. This is acceptable because iggy
    replicates 3 ways, and a dead drive becomes a replica rebuild.
  - Never set `sync=disabled` as a "fix". That silently breaks the
    `Persisted` guarantee: acked trades could be lost on a correlated power
    loss.

## P2: replace the QLC Crucial P3 in de-msa2 `nvme_pool`

Why second: after P1, iggy no longer uses the pool. But every other
workload on it (ZIL for NFS/SMB sync writes, scrub, TRIM, ClickHouse later)
still runs at the Crucial's speed. raidz runs at the speed of its slowest
member.

- [ ] Replace it with a **4 TB TLC drive with DRAM** (ideally a fourth
  Lexar NM790, so the vdev uses one model) and run `zpool replace`.
- Caveats:
  - The resilver takes hours and stresses the pool. Run it when nothing
    else is scheduled (scrub is on Sat 01:00, TRIM on Wed 01:00).
  - Do not run the resilver at the same time as a scrub or TRIM.

## P3: Optane on the other two iggy replicas

Why third: with P1 done, the primary is fast. But after a view change
(restart, crash, maintenance) a slow node can become primary, and a single
fast follower is not enough when one node is down. Latency is only
independent of which node is primary when all 3 replicas are fast.

- [ ] **desg0:** either a **P5800X** (U.2, Gen4) on a PCIe adapter, or a
  P1600X in M.2. Both have about the same fsync latency. The P5800X only
  helps if desg0 also gets ClickHouse Keeper or other sync-heavy work.
  - Caveats for the U.2 adapter:
    - A single-drive x4 card needs no bifurcation and works in any free
      slot. Cards with 2-4 drives and no switch chip need x4x4x4x4
      bifurcation in the BIOS.
    - Buy an adapter and cable rated for Gen4. Cheap Gen3 parts link at Gen4
      and then throw errors. Check `lspci -vv` for `LnkSta: 16GT/s, x4`, and
      check `dmesg` for AER errors.
    - The P5800X draws about 18-21 W under load and has no fan. It needs
      direct airflow, or it throttles under sustained writes.
- [ ] **de-n5:** a P1600X (M.2). Check for a free M.2 slot first.
- [ ] Optionally move iggy replication traffic to the fastest link. With
  Optane, fsync is about 10-20 us and the LAN round trip (about 50-200 us)
  becomes the limit. The roster uses the `192.168.0.x` addresses today.
  - Caveat: iggy 0.9+ binds the consensus listener to the literal roster
    IP, with `hostNetwork`. Changing the IP touches `iggy-clusters.nix`,
    the firewall (`modules/nexus_iggy_cluster.nix`) and the port-probe
    CronJobs.

## P4: replicated ClickHouse (1 shard x 3 replicas)

Why here: it builds on fast local NVMe and fast fsync devices (Keeper), and
it shares the always-on hosts with iggy.

- [ ] **ClickHouse Keeper on the 3 always-on hosts: de-msa2, desg0, de-n5.**
  Keeper needs a quorum of 2. Without quorum, every replicated table goes
  read-only and inserts fail.
  - Caveat: Keeper must never run on hosts that are switched off to save
    power (poweredge, meshify, superserver, ...).
  - Caveat: the Keeper log and snapshots need low fsync latency. Put them
    on the P1/P3 Optane next to iggy. Both data sets are small. On de-n5,
    never put them on the HDDs.
- [ ] **ReplicatedMergeTree replicas on local NVMe:** de-msa2 and desg0 are
  always on. poweredge is an intermittent third replica. It catches up
  through its replication queue when it powers on.
  - Use `internal_replication = true`.
  - Use `insert_quorum = 2` only if you accept that inserts fail while one
    of the two always-on replicas is down.
- [ ] Storage for each replica: a dedicated dataset on the NVMe pool,
  `recordsize=1M`, `compression=off` or `lz4` (ClickHouse compresses
  itself), `atime=off`. Use mirrors or raidz1, not stripes: a single disk
  failure would otherwise mean re-fetching the whole replica over the
  network.
- [ ] Send interserver traffic (`interserver_http_host`, port 9009) over the
  Mellanox network.
- [ ] Deploy with the **Altinity clickhouse-operator**
  (`ClickHouseKeeperInstallation` + `ClickHouseInstallation`) through
  ArgoCD. Pin the pods with node affinity, and use local PVs (local-path or
  OpenEBS ZFS-LocalPV), never network-backed volumes.
- [ ] **Backups:** `BACKUP ... TO S3(...)` or `clickhouse-backup` to rustfs
  (`s3.k3s.lan`), plus a copy on de-n5. Replication does not protect
  against a bad `DROP`/`ALTER`.
  - Caveat: rustfs on the same hosts is not an off-site copy.
- Caveats:
  - Avoid QLC drives for ClickHouse data. Constant merges rewrite data and
    cause wear and sustained-write slowdowns.
  - Do not use S3 as primary storage. With ReplicatedMergeTree each replica
    stores its own copy in S3 (3x data, plus rustfs EC overhead). Zero-copy
    replication is not recommended for production (known data-loss and
    orphan bugs). `SharedMergeTree` is ClickHouse Cloud only.
  - The current ClickHouse manifests in the `nexus` repo (`clickhouse` and
    `clickhouse-dev` namespaces) were not reviewed. Check the table engines
    and volumes there before planning the migration.

## P5: poweredge storage rebuild

Why here: poweredge is powered off most of the time, so it is the least
urgent host. It becomes important as the third ClickHouse replica and as the
bulk storage node.

- [ ] **Check the installed backplane** (front bays, or iDRAC Storage ->
  Enclosures). The R7525 options are: 8x/12x 3.5" SAS/SATA, 8x 2.5"
  SAS/SATA/NVMe (universal), 16x 2.5" SAS/SATA, 24x 2.5" NVMe.
  - Caveat: a 3.5" chassis needs a different front cage, not just a new
    backplane.
- [ ] **Two pools, one per media class.** Never put NVMe and SATA in the
  same vdev or as peer data vdevs in one pool.
  - `fast`: 8x NVMe as 4x 2-way mirror (IOPS) or 2x raidz1 of 4 (75%
    usable). Used for ClickHouse, DBs, VM/container images, ncps.
  - `bulk`: 16x SATA/SAS SSD as 2x raidz2 of 8. Used for media, backups,
    `recordsize=1M`.
  - Both pools: `ashift=12`, `atime=off`, PERC in HBA/eHBA mode.
  - Not chosen: a single pool with an NVMe `special` vdev. It cannot be
    removed from a pool with raidz vdevs, which blocks a later move of the
    disks to Ceph.
  - Skip L2ARC (512 GB of RAM is enough ARC). A SLOG only helps the `bulk`
    pool's NFS sync writes, and only with a PLP drive.
- [ ] **Buy TLC NVMe drives with PLP (U.2, Gen4)** for the `fast` pool:

  | Drive | Form factor | Endurance | Notes |
  |---|---|---|---|
  | Kioxia CD6-R / CD6-V | U.2 15 mm | 1 / 3 DWPD | Good default. Dell-branded version exists. |
  | Samsung PM9A3 | U.2 7 mm | 1 DWPD | Often the best value used. |
  | Micron 7450 PRO / MAX | U.3 | 1 / 3 DWPD | Most even latency under mixed load. |
  | Kioxia CM6, Samsung PM1733/1735, Micron 7400/9400, Solidigm D7-P5510/P5520/P5620 | U.2/U.3 | 1-3 DWPD | Also fine. |

  - 1 DWPD is enough for ClickHouse and Ceph at this scale. Take 3 DWPD if
    it costs about the same.
  - Avoid: Solidigm D5-P5316/P5336/P5430 (QLC despite PLP), Gen3 drives
    (CD5, PM983, P4510, SN640), and archive/read-optimized models.
  - Gen5 drives also work (they run at Gen4 in the R7525). Only buy them if
    they cost about the same as Gen4 drives.
- [ ] **Backplane upgrade (only if NVMe bays are missing):** NVMe bays
  connect to CPU PCIe lanes over SlimSAS cables. No storage controller is
  needed for NVMe, and ZFS sees plain `/dev/nvme*` devices.
  - Caveat: skip the PERC H755N (hardware RAID for NVMe). It hides the
    drives from ZFS and limits them to the controller's x16 link.
  - Caveat: the cable kit depends on the backplane and riser layout (PGR7W
    and C47DK come from a Dell forum thread). Check the part numbers
    against the Service Tag before ordering.
  - Caveat: 24x NVMe uses 96 lanes. Check which riser slots stay usable for
    the Mellanox NICs and any GPU.
  - Cheaper alternative for a few drives: a PCIe-to-U.2 adapter card with
    x4x4x4x4 bifurcation. This loses hot-swap.
- [ ] Optional: an **Optane P5800X** in poweredge as a SLOG for `bulk`, or
  for Keeper if poweredge ever becomes always-on.
- [ ] Replace the 870 QVO (QLC) drives over time. Their sustained writes
  drop to about 80-160 MB/s per drive once the SLC cache is full.
- [ ] Platform limit: the R7525 takes EPYC 7002/7003 (up to 64 cores per
  socket), DDR4-3200 (32 DIMMs, up to 4 TB) and PCIe Gen4. Some CPUs above
  225 W need the high-performance fans. EPYC 9004/9005 and DDR5 need a new
  platform (for example the R7625).

### Checklist for used drives

```bash
nvme smart-log /dev/nvmeX                       # percentage_used (<10% is normal), media_errors, power_on_hours
nvme id-ctrl /dev/nvmeX | grep -E '^(mn|fr) '   # exact model and firmware
nvme id-ns -H /dev/nvmeX | grep 'LBA Format'    # 4K format available?
nvme format /dev/nvmeX --lbaf=<4K index>        # switch to 4Kn before pool creation (wipes the drive)
```

- `nvme-cli` is not in poweredge's config yet.
- Use one model and capacity per vdev.
- Third-party drives show as "not Dell certified" in the iDRAC and need
  vendor tools for firmware updates.
- U.3 drives work in U.2 bays. Dell 14G/15G carriers are needed.
- Gen4 15 mm drives draw about 15-25 W each under load. With 24 drives,
  check that the server has high-performance fans.

## P6: distributed storage (deferred)

Why last: it needs hardware and an always-on topology that the fleet does
not have yet. ZFS on each host plus `zfs send` replication (as already done
to de-n5) covers redundancy across machines until then.

- [ ] **rustfs as a cold tier for ClickHouse:** a storage policy with `hot`
  on local NVMe and `cold` on an S3 disk, plus
  `TTL ts + INTERVAL 90 DAY TO VOLUME 'cold'`. Only do this once the hot
  data outgrows the NVMe.
  - Caveat: the rustfs distributed mode is new (1.0 GA in 2026-09; a 1.0
    beta had quorum bugs, issue #2794). Production multi-node mode needs at
    least 4 servers.
  - Caveat: it uses read/write quorums, so hosts that power off reduce
    redundancy or block writes.
- [ ] **Ceph (Rook) across hosts, one device class per media type.**
  Prerequisites:
  - At least 3 always-on nodes (size=3, failure domain = host). EC 4+2
    needs 6 hosts. Hosts that power off need `noout` around each shutdown.
  - PLP drives only. BlueStore WAL/DB sync writes make consumer/QLC SSDs
    drop to a few hundred IOPS per OSD.
  - 25 GbE or faster for NVMe OSDs (Mellanox cluster network). At least
    10 GbE for SATA OSDs.
  - About 4-5 GB RAM per OSD.
  - Ceph does not run on top of ZFS. OSDs take whole raw disks, so moving a
    disk class from ZFS to Ceph wipes those disks.
  - Use Rook, so it fits the existing k3s + ArgoCD + nixidy stack.

## Target layout

| Workload | IO pattern | Device |
|---|---|---|
| iggy log + offsets (`Persisted`) | small appends, fsync per batch | Optane (P1600X / P5800X), single drive, one per replica |
| ClickHouse Keeper | Raft log, fsync per op | Same Optane as iggy |
| ClickHouse data | large sequential writes, constant merges | TLC PLP U.2 in mirrors |
| Backups, cold data, media | bulk sequential | SATA SSD pool (`bulk`), rustfs, de-n5 HDDs |

## Open questions

- Which replica is iggy primary in steady state (P0)?
- Does each MS-A2/N5 have a free M.2 slot for a P1600X?
- Which backplane is installed in poweredge, and which exact EPYC model
  (`lscpu` or iDRAC)?
- The iggy quorum analysis comes from the local iggy checkout
  (2026-05-27), which is older than the iggy 0.11 that nexus uses. Check it
  against 0.11.
