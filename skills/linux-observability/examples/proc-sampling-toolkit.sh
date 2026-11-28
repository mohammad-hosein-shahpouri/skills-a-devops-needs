#!/usr/bin/env bash
# Host snapshot toolkit — reads directly from /proc and /sys (no dependencies
# beyond coreutils/util-linux). Safe to run read-only on production.

set -uo pipefail

line() { printf '\n=== %s ===\n' "$1"; }

line "Identity"
uname -srm
printf 'uptime: %s\n' "$(cut -d' ' -f1 /proc/uptime)"
printf 'loadavg: %s\n' "$(cat /proc/loadavg)"

line "CPU"
# /proc/stat: cpu user nice system idle iowait irq softirq steal guest guest_nice
awk '/^cpu /{
    total=$2+$3+$4+$5+$6+$7+$8+$9
    printf "user %.1f%% sys %.1f%% idle %.1f%% iowait %.1f%% steal %.1f%%\n",
           100*$2/total, 100*$4/total, 100*$5/total, 100*$6/total, 100*$9/total
}' /proc/stat
printf 'cpus: %s\n' "$(nproc)"
grep -E 'procs_running|procs_blocked' /proc/stat

line "CPU pressure (PSI)"
cat /proc/pressure/cpu 2>/dev/null || echo "PSI not available (kernel < 4.20?)"

line "Memory"
awk '/MemTotal|MemAvailable|SwapTotal|SwapFree|Dirty|Writeback|Cached|Buffers/ {
    printf "%-14s %8.1f MB\n", $1, $2/1024
}' /proc/meminfo

line "Memory pressure (PSI)"
cat /proc/pressure/memory 2>/dev/null || true

line "VM counters (oom / reclaim / swap)"
grep -E 'oom_kill|pgscan_direct|pgsteal_direct|pswpin|pswpout|compact_stall' /proc/vmstat 2>/dev/null || true

line "IO pressure (PSI)"
cat /proc/pressure/io 2>/dev/null || true

line "Disk devices"
for d in /sys/block/*/; do
    name=$(basename "$d")
    [ -e "$d/queue/rotational" ] || continue
    printf '%-12s rotational=%s model=%s size=%sGB\n' \
        "$name" "$(cat "$d/queue/rotational")" \
        "$(cat "$d/device/model" 2>/dev/null | tr -d '\n')" \
        "$(( $(cat "$d/size") * 512 / 1024 / 1024 / 1024 ))"
done

line "Filesystem capacity"
df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -hT

line "Inode usage"
df -i -x tmpfs -x devtmpfs 2>/dev/null || df -i

line "Top processes by RSS"
ps -eo pid,ppid,state,%cpu,%mem,rss,comm --sort=-rss | head -12

line "Uninterruptible (D-state) tasks"
ps -eo pid,state,wchan:24,comm | awk '$2 ~ /D/' | head -15

line "Network interfaces"
ip -s link show 2>/dev/null | grep -E '^[0-9]+:|RX:|TX:' | head -40

line "Socket summary"
ss -s 2>/dev/null | head -12

line "Protocol counters (drops/retransmits)"
nstat -az 2>/dev/null | grep -i -E 'TcpRetrans|TcpExtListenOverflows|TcpExtListenDrops|TcpExtTCPTimeouts|IpExtInDiscards' || true

line "Conntrack usage"
if [ -r /proc/sys/net/netfilter/nf_conntrack_count ]; then
    printf 'count=%s max=%s\n' \
        "$(cat /proc/sys/net/netfilter/nf_conntrack_count)" \
        "$(cat /proc/sys/net/netfilter/nf_conntrack_max)"
fi

line "Kernel warnings and errors (current boot)"
dmesg -T --level=err,warn 2>/dev/null | tail -25 || echo "dmesg needs privileges"

line "RAID status"
[ -r /proc/mdstat ] && cat /proc/mdstat || echo "no md arrays"

line "Time sync offset"
if command -v chronyc >/dev/null 2>&1; then
    chronyc tracking | head -5
elif command -v timedatectl >/dev/null 2>&1; then
    timedatectl show -p NTPSynchronized
fi

# Notes:
# - Everything here is read-only; run as any user with /proc and dmesg access
#   (dmesg may need privileges depending on kernel.dmesg_restrict).
# - For trends, schedule the same script hourly and diff the outputs; symtoms
#   usually appear as a delta, not as a single reading.
