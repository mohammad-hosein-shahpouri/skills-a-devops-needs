# Memory & Pressure

## The Numbers That Tell the Truth

```bash
grep -E 'MemTotal|MemFree|MemAvailable|Cached|Buffers|SwapTotal|SwapFree|Dirty|Writeback|SReclaimable|Slab' /proc/meminfo
```

| Field | Meaning |
|-------|---------|
| `MemTotal` | Physical RAM minus kernel reservations |
| `MemFree` | Truly unused — Linux keeps this low by design |
| `MemAvailable` | Best estimate of memory available for new work (free + reclaimable cache) |
| `Cached` | Page cache (file-backed, reclaimable) |
| `Buffers` | Block device metadata cache (small) |
| `Dirty` | Pages modified in memory, not yet written |
| `Writeback` | Pages currently being written |
| `SReclaimable` | Kernel slab that can be reclaimed |

**Never alert on `MemFree`.** It sits near zero on any healthy server because the
kernel uses spare RAM as page cache. Use `MemAvailable` percentage and PSI.

## Page Cache and Reclaim

- Reads populate the page cache; writes mark pages dirty and writeback flushes
  them asynchronously.
- Under pressure the kernel evicts clean pages first, then dirty pages
  (requiring writeback), then anonymous pages (requiring swap).
- **Refaults** (files evicted and immediately re-read) are a direct sign of
  working-set thrash. PSI `memory full` plus high `pgscan`/`pgsteal` is the
  same story in `vmstat` terms.
- `vmstat 1`: watch `si`/`so` (swap in/out), `bi`/`bo` (block I/O), `pgscan_kswapd`
  style counters come from `/proc/vmstat`(`pgscan_direct`, `pgsteal_direct`).

```bash
grep -E 'pgscan_direct|pgsteal_direct|pgscan_kswapd|pgsteal_kswapd|compact_stall|oom_kill' /proc/vmstat
cat /proc/pressure/memory
```

`pgscan_direct` growing means allocation had to reclaim synchronously — latency
spikes follow. `compact_stall` points at fragmentation hurting huge pages.

## Swap: Not Evil, But a Signal

- A little swap usage is normal with `vm.swappiness` defaults; sustained swap I/O
  (`si`/`so` non-zero) is a saturation event.
- Databases and JVM heaps usually want `vm.swappiness=1` and no swap for the
  working set; web apps tolerate modest swap.
- Alert on swap-in rate, not swap occupancy: 4GB of resident swap pages can sit
  idle forever, while 10MB/s swap-in destroys tail latency.

## OOM Killer

```bash
dmesg | grep -i -E 'out of memory|oom-kill'
journalctl -k | grep -i oom
cat /proc/<pid>/oom_score /proc/<pid>/oom_score_adj
```

- The kernel kills the highest `oom_score` process — not necessarily the largest.
  Tune `oom_score_adj` for critical daemons (`-1000` = never).
- Container OOM: cgroup `memory.events` shows `oom` count and `high`/`max`
  pressure; the container runtime kills the whole cgroup rather than one process.
- OOM events mean someone promised memory the machine did not have — treat as
  capacity or leak incident, not bad luck.

## cgroup v2 Memory Control

```bash
cat /sys/fs/cgroup/<path>/memory.current
cat /sys/fs/cgroup/<path>/memory.max             # hard limit
cat /sys/fs/cgroup/<path>/memory.events          # low/high/max/oom counters
cat /sys/fs/cgroup/<path>/memory.stat            # anon, file, slab, pgscan, workingset_refault
```

- `memory.high` throttles reclaim before the hard limit — use it to soften
  contention instead of relying on OOM.
- `workingset_refault_file` in `memory.stat` is container-local pressure evidence.
- Heap-sizing mistakes inside containers (JVM `-Xmx` bigger than `memory.max`)
  show up as container OOM kills with the host looking calm.

## Leaks and Working-Set Analysis

```bash
# per-process RSS and growth candidates
ps -eo pid,rss,vsz,comm --sort=-rss | head -15
cat /proc/<pid>/smaps_rollup     # Rss, Pss (shared properly accounted)
pmap -x <pid> | tail -1
```

- Distinguish **RSS** (physical footprint) from **VSZ** (virtual — often huge and
  harmless).
- Slab growth (`/proc/slabinfo`) with stable process RSS points to kernel
  objects (dentry/inode cache from millions of small files, or a driver leak).
- Long-term trend beats instantology: sample `MemAvailable` and process RSS
  hourly and alert on slope.

## Practice Checklist

1. Slow host → `cat /proc/pressure/memory` first; then `MemAvailable`, then
   process RSS.
2. `pgscan_direct` or refaults rising → working set exceeds RAM: add memory,
   reduce caches, or fix a leak — swap tuning will not save it.
3. OOM killed → size limits against actual peak working set; fix `-Xmx`/heap
   settings versus cgroup `memory.max`.
4. Alert on: PSI `memory some` > threshold, `MemAvailable` < 10%, swap-in rate,
   any OOM kill event, `pgscan_direct` rate.
