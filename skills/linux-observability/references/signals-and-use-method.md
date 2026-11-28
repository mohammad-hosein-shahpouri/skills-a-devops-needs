# Signals & The USE Method

## The Three Question Types

Every monitoring metric answers exactly one of these:

1. **Is it working?** (availability) — `up`, service state, heartbeat
2. **Is it fast enough?** (latency/saturation) — p95/p99, queue depth, pressure
3. **Is it right?** (correctness) — error rates, checksum failures, drift

Most noisy dashboards fail because they measure *activity* (counters of work
done) instead of *satisfaction* (whether the work is being served well).
`CPU 40%` answers no user question; `requests waiting > 1s` does.

## USE: Utilization, Saturation, Errors

For every resource — CPU, memory, disk, network, cgroup, file descriptors,
conntrack — ask three things:

| | Question | CPU example | Memory example | Disk example |
|---|----------|-------------|----------------|--------------|
| **U**tilization | How busy is it? | `/proc/stat` busy% | `MemAvailable` | `iostat %util` |
| **S**aturation | How much work is waiting? | run queue length, PSI `cpu some` | PSI `memory some`, refaults | `iostat` await, PSI `io` |
| **E**rrors | Is it failing? | steal time, throttling | OOM kills, allocation fails | I/O errors, `dmesg` |

**Saturation is the honest signal.** Utilization near 100% on a parallel resource
is fine; saturation above zero means queues — the only utilization that matters
is the one you can correlate with latency.

## PSI — The Modern Saturation Metric

Pressure Stall Information (kernel 4.20+, `/proc/pressure/{cpu,memory,io}`) tells
you how long tasks were stalled waiting for the resource:

```text
some avg10=12.34 avg60=5.10 avg300=2.40 total=1048576
full avg10=0.00  avg60=0.00 avg300=0.00 total=0
```

- `some` — at least one task stalled; good for capacity and alerts
- `full` — every runnable task stalled (real loss of throughput)
- Threshold guidance: alert on `some > 10` sustained 5–10 minutes; investigate
  `full > 5`. Always set per-host baselines — a CI runner lives at higher
  baseline than a database host.

PSI is the single best replacement for guessing at `loadavg` and `%util`.

## Metric Sources Reference

| Need | Source |
|------|--------|
| CPU totals and per-mode | `/proc/stat` |
| Per-process CPU and memory | `/proc/<pid>/stat`, `status`, `smaps_rollup` |
| Memory breakdown | `/proc/meminfo` |
| Pressure | `/proc/pressure/*` |
| Disk counters and latency | `/proc/diskstats`, `/sys/block/*/stat` |
| Filesystem capacity | `statfs`, `df` |
| Network counters and errors | `/proc/net/dev`, `/proc/net/snmp` |
| Socket states | `/proc/net/tcp`, `ss -s` |
| cgroup limits and usage | `/sys/fs/cgroup/**` (v2), `cpu.stat`, `memory.current`, `io.stat` |
| Interrupts | `/proc/interrupts`, `/proc/softirqs` |
| Thermal and frequency | `/sys/class/thermal`, `/sys/devices/system/cpu/cpu*/cpufreq` |

Node exporter wraps most of these; knowing the raw source lets you verify an
alert when the exporter disagrees.

## Sampling and Cost Discipline

- **Counters vs gauges**: rate() counters, read() gauges. Alerting on a raw
  counter value is always wrong.
- **Scrape interval governs resolution**: 15s scrapes cannot resolve a 3-second
  spike — do not write 5-second-duration alerts on 15s data.
- **Cardinality**: per-container or per-device metrics multiply series; keep
  high-cardinality labels out of alerts (`instance` yes, `container_id` no).
- **Query cost**: dashboards with 30 panels × 7-day ranges × 5s refresh are a
  self-inflicted incident; use recording rules for expensive expressions.

## Golden Signals per Layer

| Layer | Latency | Traffic | Errors | Saturation |
|-------|---------|---------|--------|------------|
| Host | PSI stall time | context switches/s | MCE, OOM, dmesg | runqueue, PSI io/mem |
| Network | RTT, retransmit rate | bytes/s, packets/s | drops, resets | qdisc backlog, conntrack |
| Disk | await, queue depth | IOPS, MB/s | EIO, timeouts | %util, PSI io |
| Process | service p95 | requests/s | HTTP 5xx | threads, fds |

Alert at layer boundaries: host saturation that also shows in service latency is
paging-worthy; saturation alone is a ticket.

## What Not to Alert On

- Raw utilization (CPU 80%, disk %util 90%) — thresholds are baselines, not
  universals, and utilization without saturation is healthy.
- Single-sample spikes — every metric spikes; use `for:` windows.
- Free memory as a target — Linux intentionally uses free memory as cache;
  `MemAvailable` and PSI tell the truth.
- Individual process CPU percentages — chase latency, not per-process busyness.
