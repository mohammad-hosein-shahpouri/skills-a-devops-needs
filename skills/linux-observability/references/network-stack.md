# Network Stack

## Socket-Level Truth

```bash
ss -s                   # summary: total, TCP states
ss -tanp state established '( sport = :443 )'
ss -lntup               # listeners
netstat -s | head -30   # protocol counters (retransmits, drops)
```

| State pile you see | Means |
|--------------------|-------|
| `TIME-WAIT` thousands | churn, short-lived connections — reuse/pipelining, not a leak |
| `CLOSE-WAIT` growth | app not closing sockets — code bug |
| `ESTABLISHED` with `Send-Q` growing | receiver slow / window closed — app-level backpressure |
| `SYN-RECV` high | SYN flood or slow accepts (backlog full) |

`ss -ti` shows per-socket cwnd, rtt, retransmits — the only place to see a
single-connection problem while the aggregate looks fine.

## Drops, Retransmits, Errors

```bash
ip -s link show          # RX/TX errors, dropped, overruns
nstat -az | grep -i -E 'drop|retrans|reset|listen|overflow|synflood|congest'
```

Categorize before blaming the network:

| Counter | Layer |
|---------|-------|
| `rx_dropped` / `tx_dropped` | driver/queue (ring buffer too small, single queue) |
| `TcpRetransSegs` | path loss or congestion (or middlebox) |
| `ListenOverflows` / `ListenDrops` | accept backlog exhausted — app cannot keep up |
| `PruneCalled`, `OutOfWindow` | memory pressure / window issues |
| `conntrack: table full, dropping packet` | nf_conntrack limit |

Ring buffer and queue tuning (verify before changing):

```bash
ethtool -S eth0 | grep -i -E 'drop|err|miss|no_buffer'
ethtool -g eth0                # rings
ethtool -l eth0                # channels (queues vs cores)
tc -s qdisc show dev eth0      # backlog/drops on egress
```

## Latency, Bandwidth, and BDP

- Throughput ceiling ≈ window / RTT. A 200ms RTT path with 256KB window cannot
  exceed ~1.3MB/s regardless of link speed.
- `tcpprof`/`mtr` distinguish path loss from endpoint problems.
- Congestion control matters on long-fat paths: modern kernels default `cubic`;
  BBR helps lossy/high-BDP links — verify with `sysctl net.ipv4.tcp_congestion_control`.
- **TLS handshake cost** is a latency factor per connection: reuse sessions,
  enable TLS 1.3, keep certificate chains short.

## DNS (the cheapest outage to create)

```bash
resolvectl statistics 2>/dev/null || cat /etc/resolv.conf
dig +stats example.com @127.0.0.53
```

- Slow resolution multiplies with every connection — measure resolver latency
  separately from app latency.
- Nameserver outages cause exactly the "everything is slow, nothing is broken"
  symptom; alert on resolver health.
- `getent hosts name` uses the full NSS chain (nsswitch, mDNS, LDAP) — it can be
  slow while `dig` is fast, pointing at the NSS config, not DNS.

## conntrack, NAT, and Firewalling

```bash
sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_count
dmesg | grep -i conntrack
```

- Full conntrack table silently drops new flows — the classic gateway incident.
  Raise `nf_conntrack_max`, shorten timeouts for short-lived flows, and alert at
  80% usage.
- For proxied/CDN front ends, conntrack and socket churn are the dominant costs
  — measure connections per second and ephemeral port exhaustion
  (`net.ipv4.ip_local_port_range`, `TIME-WAIT` reuse).

## Queueing Discipline (egress)

```bash
tc -s qdisc show dev eth0
sysctl net.core.default_qdisc
sysctl -a | grep -E 'net.core.(rmem|wmem)'
```

- Large `backlog` with `dropped` climbing = egress oversubscribed.
- BUFFERBLOAT path: excessive queue = latency for everyone; shaping with fq/fq_codel
  keeps latency low under contention.
- Socket buffer ceilings (`rmem_max`/`wmem_max`) constrain single-flow throughput;
  raise with care, monitor memory.

## Practice Checklist

1. "Network is slow" → first split: DNS, handshake, first-byte, transfer; each
   has distinct counters.
2. Aggregate fine but some clients slow → `ss -ti` per-socket rtt and retransmits,
   then path loss (`mtr`).
3. Drops rising → ring buffers, channels, qdisc backlog, conntrack — in that
   order.
4. Alerts worth having: retransmit ratio over baseline, listener overflows,
   conntrack utilization, qdisc drops, interface errors; not raw byte rates alone.
