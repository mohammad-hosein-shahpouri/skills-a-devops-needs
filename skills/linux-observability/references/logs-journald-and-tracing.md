# Logs, Journald & Tracing

## Journald Configuration for Production

```ini
# /etc/systemd/journald.conf
[Journal]
Storage=persistent                 # keep across reboots (default is often volatile)
SystemMaxUse=2G                    # cap total disk use
SystemMaxFileSize=200M
MaxRetentionSec=30day
ForwardToSyslog=no                 # only if nothing else reads syslog
RateLimitIntervalSec=30s
RateLimitBurst=10000               # raise for chatty services; keep enabled
Compress=yes
```

Operational commands:

```bash
journalctl -u nginx --since '30 min ago' -p warning --no-pager
journalctl -k -b -1                       # previous boot kernel log
journalctl _SYSTEMD_UNIT=app.service -o json-pretty | head
journalctl --disk-usage; journalctl --vacuum-size=1G
```

**Rate limiting** is the single most common "missing logs during the incident"
cause: a service storms warnings, journald drops the rest. Raise `RateLimitBurst`
for known-noisy units via `LogRateLimitBurst=` in the unit file, and alert on
`Suppressed` counts.

## Structured Logging

- Application logs should be **one JSON object per line** with stable keys
  (`ts`, `level`, `service`, `trace_id`, `msg`, plus domain fields).
- Trace correlation: inject `trace_id`/`span_id` from the HTTP layer into logs and
  metrics; without it, cross-service incidents are unsolvable in reasonable time.
- Do not log secrets or full request bodies; log identifiers and decisions, with
  sampling for high-volume paths.
- Ship logs to one aggregator (Loki/ELK) with **retention tiers**: hot 7–14 days,
  cold 90, archive beyond; set per-stream limits to prevent a single noisy
  service from eating the cluster budget.

## Kernel and Device Logs

```bash
dmesg -T --level=err,warn
journalctl -k -p err -b
```

Kernel messages that are always incident-worthy: OOM kills, MCE/hardware errors,
link resets, `nvme` timeouts, filesystem errors (`EXT4-fs error`,
`XFS ... corruption`), SYN flood warnings, conntrack table full.

## perf — Sampling Profiler Basics

```bash
perf top -p <pid>
perf record -F 99 -g -p <pid> -- sleep 30
perf report --stdio --sort comm,dso,symbol | head -40
```

- 99Hz sampling reduces aliasing; `-g` gives call graphs.
- Good for "CPU is busy but which function?": kernel vs user split, syscall
  hotspots, lock functions (`futex`, `rwsem`).
- Needs `kernel.perf_event_paranoid` adjusted (often `< 1`) and `perf` matching the
  running kernel version.

## bpftrace — The Fast Diagnostic Layer

No recompilation, low overhead when probes are targeted:

```bash
# block device latency histogram (see full file for more)
bpftrace -e 'tracepoint:block:block_rq_complete { @us = hist(args->nr_sector ? (nsecs - @start[args->dev, args->sector])/1000 : 0); }'

# count syscalls by process, 10 seconds
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }' -d 10

# who is opening files slowly (>5ms)
bpftrace -e 'kprobe:vfs_open { @s[tid] = nsecs; }
             kretprobe:vfs_open /@s[tid]/ { @ms = hist((nsecs-@s[tid])/1000000); delete @s[tid]; }'
```

Practical constraints: probes cost CPU proportional to event rate; run them
targeted and time-boxed (seconds), never leave broad `kprobe` sets running on
production.

## tcpdump and Packet Evidence

```bash
tcpdump -i any -nn -c 200 'host 192.0.2.5 and port 443 and tcp[tcpflags] & (tcp-syn|tcp-rst) != 0'
```

- Capture on the right interface (veth/bond vs physical), with `-c` caps.
- Evidence beats theories for resets, MTU issues, and handshake asymmetry.
- Beware of capturing full payloads in production (privacy and cost); use
  `-s 0` only when necessary and time-boxed.

## Log-to-Metric Bridges

- journald `Suppressed`, `journal_events_total` per unit, and error-level counts
  can be exported (node_exporter systemd collector, or a journald → Loki pipeline)
  and alerted on.
- Do not page on log **content** patterns that also occur benignly; page on rates
  over time or on explicit severity channels.

## Practice Checklist

1. Incident → `journalctl -u <svc> -p warning --since` first; then dmesg err.
2. Missing logs → check rate limiting and disk caps before blaming the app.
3. CPU mystery → `perf top` for hotspots, `bpftrace` for latency attribution.
4. Retain the evidence: ship structured logs with trace ids; that is what makes
   future diagnosis cheaper than this one.
