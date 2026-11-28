---
name: linux-observability
description: >
  Linux host observability and troubleshooting — USE method, /proc and cgroup v2
  metrics, PSI pressure signals, CPU scheduling and load semantics, memory and
  reclaim behavior, disk and filesystem I/O analysis, network stack tracing,
  journald and log design, eBPF/bpftrace dynamic tracing, Prometheus node
  exporter mapping, and host-level alerting thresholds for RHEL/Debian systems.
---

# Linux Host Observability

Systematic host diagnosis and monitoring design: what to measure, where to read
it, how the kernel's numbers actually behave, and which signals deserve an alert.

## When to Use This Skill

Activate when the task involves:

- Diagnosing **host performance** — high load with idle CPU, memory pressure,
  I/O wait, network drops
- Designing **host metrics** — node exporter, `/proc` sources, cgroup v2,
  PSI pressure, alert thresholds
- Reading **`loadavg`**, `vmstat`, `iostat`, `sar`, `ss` output correctly
- Understanding **cgroup v2** limits and why containers throttle
- **Memory reclaim** — page cache, swap behavior, OOM killer, `MemAvailable`
- **Disk and filesystem** — latency vs throughput, `iostat -x`, writeback,
  filesystem choice and mount options
- **Network** — socket states, retransmits, drops, ring buffers, conntrack
- **eBPF tracing** — `bpftrace` one-liners for latency and syscall analysis
- **Log strategy** — journald retention, rate limiting, structured logs

## Reference Docs

| Document | Covers |
|----------|--------|
| [Signals & The USE Method](references/signals-and-use-method.md) | USE, golden signals, which metric answers which question, sampling costs |
| [CPU & Scheduling](references/cpu-and-scheduling.md) | Load average semantics, run queues, PSI, steal time, cgroup CPU throttling |
| [Memory & Pressure](references/memory-and-pressure.md) | Page cache, reclaim, `MemAvailable`, swap, OOM, PSI memory, cgroup limits |
| [Disk & Filesystem](references/disk-and-filesystem.md) | Latency vs throughput, `iostat`, writeback, filesystem and mount choices |
| [Network Stack](references/network-stack.md) | Socket states, retransmits, drops, qdisc backlog, conntrack, ring buffers |
| [Logs, Journald & Tracing](references/logs-journald-and-tracing.md) | journald config, structured logging, bpftrace recipes, perf basics |
| [Host Alerting & Best Practices](references/host-alerting-and-best-practices.md) | Alert thresholds, noise control, node exporter mapping, anti-patterns |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [proc-sampling-toolkit.sh](examples/proc-sampling-toolkit.sh) | Snapshot of load, pressure, memory, CPU, disk, network from `/proc` |
| [node-exporter-rules.yaml](examples/node-exporter-rules.yaml) | Prometheus alerting rules for host saturation with sensible thresholds |
| [sysctl-baseline.conf](examples/sysctl-baseline.conf) | Conservative sysctl baseline with inline justification |
| [bpftrace-recipes.bt](examples/bpftrace-recipes.bt) | Ready-to-run probes: block latency, syscall outliers, scheduler delays |
| [host-triage-runbook.md](examples/host-triage-runbook.md) | Step-by-step triage order when a host is reported slow |
