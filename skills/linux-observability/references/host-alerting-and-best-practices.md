# Host Alerting & Best Practices

## Threshold Discipline

1. **Baselines first.** Every threshold is relative to that host class: a CI
   runner at PSI `cpu some` 40 steady is normal; a database at 5 is not.
2. **Duration over magnitude.** `for: 5m` filters 95% of noise; a 10-second
   ceiling breach is not a page.
3. **Saturation before utilization.** Alert on queues and pressure (PSI,
   runqueue, await), not on busy percentages.
4. **One alert per incident.** CPU spike, PSI, and latency alerts firing
   together should be one page plus context, not four.
5. **Every alert has an action.** If the runbook says "watch it", it is a
   dashboard, not an alert.

## Alert Catalogue (host layer)

| Signal | Expression sketch | `for` | Severity |
|--------|-------------------|-------|----------|
| CPU saturation | `PSI cpu some avg10 > 2× baseline` | 10m | warning |
| CPU throttling (containers) | `rate(container_cpu_cfs_throttled_periods_total) > 0` sustained | 10m | warning |
| Memory pressure | `PSI memory some avg10 > 10` | 5m | warning |
| Memory critical | `MemAvailable < 10%` and `PSI memory full avg10 > 5` | 2m | critical |
| OOM kill | `increase(node_vmstat_oom_kill, 10m) > 0` | 0 | critical |
| Swap thrash | `rate(node_vmstat_pswpin) > 1000` | 10m | warning |
| I/O latency | `node_disk_io_time_seconds_total` rate high **and** `PSI io some` elevated | 10m | warning |
| Filesystem full | `node_filesystem_avail_bytes / size < 0.1` | 5m | warning (critical at 0.03) |
| Inodes | `node_filesystem_files_free / files < 0.1` | 5m | warning |
| Interface errors | `rate(node_network_receive_errs_total) > 0` | 5m | warning |
| Conntrack | `nf_conntrack_count / max > 0.8` | 5m | warning |
| Load runaway | `node_load15 > 2× vCPU` **with** high `procs_running` | 10m | warning |
| Time sync | `abs(node_timex_offset_seconds) > 0.5` | 5m | warning |
| Disk health | SMART wear/reallocated crossing vendor threshold | daily | ticket |
| RAID degraded | `node_md_disks{state="failed"} > 0` | 0 | critical |
| Playback of alerts | alert history health check | weekly | ticket |

Rationale: each row is a **saturation or error** signal with a window and a
severity; utilization-only rows were deliberately excluded.

## node_exporter Mapping

| Intent | Metric |
|--------|--------|
| CPU by mode | `node_cpu_seconds_total{mode=...}` |
| Load | `node_load1/5/15` |
| Memory available | `node_memory_MemAvailable_bytes` |
| PSI | `node_pressure_cpu_waiting_seconds_total`, `node_pressure_memory_waiting_seconds_total`, `node_pressure_io_waiting_seconds_total` |
| Disk latency | `node_disk_read_time_seconds_total`, `node_disk_write_time_seconds_total` |
| Disk ops | `node_disk_reads_completed_total`, `node_disk_writes_completed_total` |
| Filesystem | `node_filesystem_avail_bytes`, `node_filesystem_files_free` |
| Network | `node_network_receive_bytes_total`, `node_network_receive_drop_total` |
| Conntrack | `node_nf_conntrack_entries`, `node_nf_conntrack_entries_limit` |
| OOM / swap | `node_vmstat_oom_kill`, `node_vmstat_pswpin`, `node_vmstat_pswpout` |
| Systemd unit state | `node_systemd_unit_state{name="...",state="active"}` |

Rules of thumb: derive `PSI` rates (`rate(...)` over 5m gives the `some` fraction),
and always join filesystem alerts to `fstype` filters to avoid pseudo-filesystems.

## Noise Control

- Exclude virtual/pseudo filesystems: `fstype=~"ext4|xfs|btrfs|nfs*"` for capacity
  alerts.
- Drop `device=~"loop*|ram*|dm-*"` where appropriate (LVM devices double-count).
- Maintenance windows (silences) with an explicit owner and expiry — permanent
  silences are deleted thresholds in disguise.
- Alert on **symptoms users feel** (service latency, error rate) and use host
  saturation as **cause context** in the same notification, not a separate page.

## Capacity Planning Inputs

```text
CPU:   PSI cpu some 95th percentile per vCPU over 7d  → headroom %
Memory:MemAvailable low-water mark per host class      → headroom %
Disk:  bytes/row growth + IOPS p95                     → commit vs device specs
Net:   peak Mbps + connection churn rate               → bond/LB margin
```

Keep 20–30% headroom on all four; storage needs 30% because writeback, snapshots,
and rebuilds spike.

## Security-Adjacent Observability

- Track: package updates pending, reboots required, SELinux/AppArmor denials,
  failed SSH logins (`journalctl _COMM=sshd`), sudo escalations, file integrity
  (AIDE) reports — as **tickets**, not pages, unless actively exploited.
- Exposed ports and new listeners inventory (`ss -lntup` diff) is a cheap,
  high-signal change detector.

## Common Anti-Patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Alerting on `%util` | Fabricated on modern devices; miss real latency |
| Alerting on free memory | Kernel fills RAM with cache by design |
| 5s `for:` windows on 1m data | Flapping and false pages |
| Per-container high-cardinality alerts | Alert noise and query load |
| Global thresholds across host classes | Either silent or spam |
| No runbook link | Page without an action |
| Unclocked silences | Unmonitored production |
| Monitoring only the host, never the service | Slow host symptoms invisible until users complain |

## Triage Order (remember this)

1. PSI (cpu/memory/io) — which resource is actually stalling
2. Capacity numbers — MemAvailable, disk free, conntrack, thin pools
3. Per-process attribution — top RSS, D-state, cgroup throttling
4. Kernel evidence — dmesg err, SMART, RAID status
5. Only then application-level investigation with trace ids
