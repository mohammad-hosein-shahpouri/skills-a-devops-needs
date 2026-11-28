# CPU & Scheduling

## Load Average Is Not CPU Utilization

```bash
cat /proc/loadavg      # 1m 5m 15m running/total lastpid
```

`loadavg` counts **runnable plus uninterruptible (D-state) tasks**. A load of 20
on 8 CPUs can mean:

- genuinely CPU-saturated (runqueue high), or
- I/O stall — tasks waiting on disk in `D` state, or
- NFS/network filesystem hangs (classic D-state pileup).

Discriminate before acting:

```bash
# runnable vs blocked split
grep procs_running /proc/stat; grep procs_blocked /proc/stat
ps -eo state,pid,comm | awk '$1=="D"'   # who is uninterruptible
cat /proc/pressure/cpu                 # actual CPU stall
```

On containers, `loadavg` is host-wide (unless lxcfs) — a container reading 40 may
be innocent; check cgroup `cpu.stat` instead.

## Per-CPU Accounting

```bash
# /proc/stat fields: user nice system idle iowait irq softirq steal guest guest_nice
awk '/^cpu /{print "user",$2,"sys",$4,"idle",$5,"iowait",$6,"steal",$9}' /proc/stat
mpstat -P ALL 1       # per-CPU instantaneous
sar -u 1 3             # historical from sysstat sa data
```

Mode meanings that matter:

- **`sys`** high → syscalls, context switches, packet processing
- **`softirq`** high → network/block softirq (single-queue NIC without RPS)
- **`steal`** high → hypervisor took the CPU (noisy neighbor, oversubscribed VM)
- **`iowait`** high → CPU waiting on block I/O; not "CPU busy", it is stall time

## cgroup v2 CPU Signals

```bash
cat /sys/fs/cgroup/<path>/cpu.stat
# usage_usec, user_usec, system_usec
# nr_periods, nr_throttled, throttled_usec   <- quotas hit
cat /sys/fs/cgroup/<path>/cpu.max            # "50000 100000" = 50% quota
```

`nr_throttled` growing means the container hit its quota — a *latency* incident
even when host CPU looks idle. This is the most common "the container is slow but
the node is fine" cause.

## Runqueue and Scheduling Latency

| Signal | Read |
|--------|------|
| `procs_running` | Runnable tasks; > CPUs sustained = queueing |
| PSI `cpu some` | Fraction of time tasks stalled waiting for CPU |
| sched delay via bpftrace | Actual time between wakeup and running |
| `ctxt` in `/proc/stat` | Context switches/s — sudden spikes usually syscall churn |

```bash
# scheduler latency probe (see bpftrace-recipes.bt for the full script)
bpftrace -e 'tracepoint:sched:sched_wakeup { @q[args->pid] = nsecs; }
             tracepoint:sched:sched_switch /@q[args->prev_pid]/ {
               @us = hist((nsecs - @q[args->prev_pid])/1000); delete @q[args->prev_pid];
             }'
```

## CPU Frequency, Throttling, Thermal

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
grep -m1 "^cpu MHz" /proc/cpuinfo
cat /sys/class/thermal/thermal_zone*/temp       # millidegrees
dmesg | grep -i -E 'throttl|mce|hardware error'
```

- `powersave` governor on servers can halve performance under bursty load;
  `performance` is the usual production choice.
- Thermal throttling and MCE events are **error** signals, not utilization —
  alert on their presence.

## NUMA

```bash
numactl --hardware
cat /sys/devices/system/node/node*/meminfo | head
```

Cross-node memory access doubles latency; on multi-socket hosts pin
latency-sensitive processes (`numactl --cpunodebind --membind`) and check
`numastat -p <pid>` for foreign-page ratios.

## Practice Checklist

1. Load high → split runnable vs D-state; PSI before conclusions.
2. CPU idle + slow app → check cgroup throttling and steal time.
3. `sys`/`softirq` heavy → suspect syscall rate, packet rate, or disk completion
   storm before adding cores.
4. Alert on PSI `cpu some` and runqueue depth per vCPU — not on raw utilization.
5. Capacity rule of thumb: sustained PSI `some` above baseline plus rising
   tail latency means you need CPU or fewer threads, in that order of evaluation.
