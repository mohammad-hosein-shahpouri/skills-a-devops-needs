# Disk & Filesystem

## Latency First, Throughput Second

Application pain from storage is almost always **latency** (queue wait), not raw
MB/s. Read the right numbers:

```bash
iostat -xz 1        # -x extended, -z skip idle devices
```

| Column | Meaning | Practical reading |
|--------|---------|-------------------|
| `r/s`, `w/s` | IOPS | Compare against device capability, not a universal number |
| `rkB/s`, `wkB/s` | Throughput | The headline number everyone over-uses |
| `r_await`, `w_await` | Average latency in ms including queue | > 10ms on SSD is suspicious; > 50ms is an incident |
| `aqu-sz` (`avgqu-sz`) | Queue depth | High queue + high await = saturation |
| `%util` | Busy percentage | Misleading on NVMe/multi-queue: can show 100% while still fast |

`%util` is a fabrication on modern multi-queue devices; **`await` and queue depth
plus PSI `io`** are the honest saturation signals.

## PSI for I/O

```bash
cat /proc/pressure/io
# some = at least one task stalled on I/O
# full = all tasks stalled — throughput truly lost
```

Alert on `io some` sustained 5+ minutes at double the baseline. PSI catches the
case where `%util` looks fine but tasks queue in the block layer.

## Writeback and Dirty Pages

```bash
grep -E 'Dirty|Writeback' /proc/meminfo
sysctl vm.dirty_ratio vm.dirty_background_ratio vm.dirty_expire_centisecs
```

- Dirty pages accumulate in RAM and create **bursty** writes: latency spikes at
  flush boundaries are normal unless tamed.
- Too high ratios → multi-second stalls when the kernel force-flushes; too low →
  lost write-combining throughput.
- Tune for latency-sensitive hosts: `dirty_background_ratio=5`,
  `dirty_ratio=10`, or absolute bytes on large-RAM hosts.
- A single process writing faster than the device can absorb manifests as
  `w_await` spikes and rising `Dirty` — throttle the writer, not the kernel.

## Filesystem Choice and Mount Options

| Filesystem | Notes |
|------------|-------|
| ext4 | Dependable default; `data=ordered`; use for general workloads |
| xfs | Better for large files and parallel metadata; cannot shrink |
| btrfs | Snapshots/compression excellent; RAID5/6 write hole — avoid for parity RAID |
| zfs | Checksums, ARC, snapshots; needs RAM discipline (ARC vs page cache) |

Mount options that matter:

- `noatime` (or `relatime`) — removes per-read metadata writes
- `discard` vs `fstrim` timer — periodic trim is usually better than online discard
- `nobarrier`/`nodelalloc` are old advice; do not copy them blindly to modern ext4
- `nfs` soft vs hard mounts: hard for data integrity, soft risks silent truncation

## Filesystem Capacity Traps

```bash
df -hT                      # type + usage
df -i                       # inode exhaustion (many small files)
du -xhd1 /var | sort -h     # who grew
lsof +D /var/log            # deleted-but-open files holding space
```

- **Deleted-but-open** files keep space until the process closes them (or
  restart) — the classic "df and du disagree" case.
- Inode exhaustion on mail queues, caches, and session-file farms looks like a
  full disk with free blocks.
- Reserved blocks (`ext4` 5% default) on data volumes: `tune2fs -m 1` for non-root
  filesystems.

## Block Layer and Devices

```bash
lsblk -o NAME,ROTA,SCHED,SIZE,TYPE,MOUNTPOINT
cat /sys/block/nvme0n1/queue/scheduler
cat /sys/block/sda/queue/nr_requests
dmesg -T | grep -i -E 'nvme|ata|scsi|error|reset|timeout'
```

- `SCHED=none` (`mq-deadline` for SATA) is right for NVMe; `bfq` favors fairness
  on slow rotating media.
- Controller-level resets, ATA timeouts, and SCSI aborts in `dmesg` are hardware
  events — no amount of tuning fixes a dying drive.
- SMART: `smartctl -a /dev/nvme0` — track media errors, wear level, temperature.

## RAID and LVM Notes

- **MD RAID**: check `/proc/mdstat` and `mdadm --detail` for degraded arrays and
  rebuild progress; rebuilds starve latency.
- **Hardware RAID**: cache with battery-backed write cache vs
  write-through — write-through can multiply latency.
- **LVM**: `lvs`, thin-pool usage (`Data%`, `Meta%`) — a full thin pool stalls
  every write on the volume group. Alert at 80% before the pause happens.
- Multi-device linear/logical volumes: a failing device drags the whole volume's
  latency.

## Practice Checklist

1. "Disk is slow" → `iostat -xz 1` (await well above baseline?), PSI `io`,
   then `Dirty`/`Writeback` counters.
2. Sustained `await` with low `%util` → check PSI, thin pool, RAID rebuild,
   firmware/hardware errors in `dmesg`.
3. Alert set: PSI `io some`, `w_await` p95, thin pool usage, RAID degraded,
   SMART reallocated sectors — not raw `%util` thresholds.
4. Capacity planning: separate IOPS and capacity forecasts; NVMe wear (TBW)
   is a real replacement schedule, not a curiosity.
