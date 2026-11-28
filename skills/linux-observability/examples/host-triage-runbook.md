# Host Triage Runbook

Use this order; do not skip ahead to application logs before step 4.

## Step 0 — Scope the report

- Single host or many? (one host = local resource; many = shared dependency)
- Which service and which symptom (slow, errors, unavailable)?
- When did it start, and does it correlate with a deploy/config change?

## Step 1 — Pressure first (the honest saturation signal)

```bash
paste <(cat /proc/pressure/cpu) <(cat /proc/pressure/memory) <(cat /proc/pressure/io)
```

- CPU `some` high → CPU contention: check runqueue (`procs_running`) and
  container throttling (`cpu.stat` → `nr_throttled`)
- Memory `some`/`full` high → reclaim pressure: check `MemAvailable`,
  `pgscan_direct`, process RSS growth
- IO `some` high → storage stall: check `iostat -xz 1` (`await`, `aqu-sz`)

If all three are quiet and the service is slow, the problem is above the host
(application, network path, or dependency) — say so and move on.

## Step 2 — Capacity floors

```bash
awk '/MemAvailable|MemTotal/{print $1, $2/1024 " MB"}' /proc/meminfo
df -hT -x tmpfs -x devtmpfs | awk 'NR==1 || $5+0 > 80'
df -i -x tmpfs -x devtmpfs | awk 'NR==1 || $5+0 > 80'
cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null
cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null
lvs 2>/dev/null | awk '$0 ~ /Data%|Meta%/'
```

Anything above 80% of a hard ceiling is a candidate cause — thin pools,
conntrack, and inodes all fail catastrophically at 100%.

## Step 3 — Attribution

```bash
ps -eo pid,state,%cpu,%mem,rss,comm --sort=-rss | head -15
ps -eo pid,state,wchan:24,comm | awk '$2 ~ /D/'
ss -s
ss -tanp state established | head
```

- A single process with rising RSS → leak (compare with yesterday's snapshot).
- D-state pileup → storage or network filesystem.
- `CLOSE-WAIT` growth → application socket leak.
- `Send-Q` growth on one side → receiver slow, app backpressure.

## Step 4 — Evidence layer

```bash
dmesg -T --level=err,warn | tail -40
journalctl -k -p err -b | tail -40
journalctl -u <service> --since '30 min ago' -p warning --no-pager
cat /proc/mdstat
lsblk -o NAME,ROTA,TYPE,SIZE,MOUNTPOINT
```

Look for: OOM kills, NVMe/SCSI resets, filesystem errors, RAID degraded,
conntrack floods, TLS handshake failures.

## Step 5 — Deep probes (only if 1-4 inconclusive)

```bash
perf top -p <pid>              # CPU hotspots in-kernel/user
bpftrace -e 'tracepoint:block:block_rq_complete { @[comm] = count(); }' -d 5
bpftrace bpftrace-recipes.bt   # targeted latency histograms (one recipe at a time)
```

## Step 6 — Record and follow up

- Write the finding in handoff/incident notes with **numbers** (PSI before/after,
  `await` values, RSS slope).
- If capacity was the cause, file the capacity item; if config, file the change
  with the measurement that justified it.
- If nothing moved and the symptom persists, escalate to the service owner with
  step 1 evidence — "host is healthy, here are the numbers" is a valid,
  useful outcome.
