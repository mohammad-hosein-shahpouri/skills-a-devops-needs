# HA & Hardening

## HA Modes

| Mode | Behavior | Use |
|------|----------|-----|
| **Active-Passive** | One unit passes traffic; standby syncs config + sessions | Default production choice; predictable |
| **Active-Active** | Both units process traffic (session-shared) | Throughput scale; more moving parts |

- Pair peers need: same model/OS, direct HA heartbeat link, dedicated HA1/HA2
  (config + sync) cables or VLANs, unique but coordinated HA cluster config.
- Session sync keeps connections alive through failover — verify it is enabled
  or expect TCP resets on switchover.
- **FGCP-style peer logic**: priority decides primary; preempt controls whether
  the higher-priority unit takes back over after recovery (usually off to avoid
  flap).

## Failover Testing (do it on schedule, not by accident)

1. Announce window; run synthetic monitors.
2. `execute ha force sync` after any config change; confirm sync status.
3. Fail the primary (reboot or cable pull) during traffic.
4. Measure: connection survival (keep-alive flows), SSL session continuity,
   time to service recovery.
5. Fail back during a quiet window; confirm no config drift between peers.

Config drift between HA peers is the classic silent risk: any manual change on
the primary must sync; audit periodically (`diagnose autoupdate version`,
config checksum tools per release).

## Upgrades

1. Read upgrade path notes; note interstitial versions (do not skip path steps).
2. Backup config (`execute backup config tftp`/REST) before every upgrade.
3. Upgrade standby first (active-passive), force failover, upgrade the other.
4. Post-upgrade: signature DB version, license status, sync state, a synthetic
   attack-log test (known test request), health checks green.

## Admin Hardening

- Dedicated admin profiles: read-only for NOC dashboards, restricted write for
  operators, full only for change windows.
- Admin access: trusted-host restrictions, HTTPS admin with strong TLS policy,
  admin-session timeout short.
- Local admin accounts named per human/service, with expiry; no shared admin.
- Disable unused services on interfaces (ping/admin/SNMP per interface policy).
- Log every admin action (`log admin`) and forward it with attack logs.

## Platform Hardening

- Management network separate from data plane; management reachable only from
  jump/NOC ranges.
- Firmware: security-fix cadence; subscribe to PSIRT advisories for your model.
- Backup: scheduled config export (REST) to a git-adjacent store with retention —
  config restore must be tested like backups (see the Veeam lesson: an
  untested config backup is a hope).
- Time sync (NTP) — attack log correlation depends on it.

## Monitoring Hooks for HA Health

| Signal | Meaning |
|--------|---------|
| HA sync status != synchronized | Config drift / heartbeat issue |
| Peer uptime reset | Unexpected failover occurred |
| Signature DB age | Update pipeline broken |
| License/expiry | Feature loss risk |
| CPU/Concurrent sessions | Capacity trend |

## Anti-Patterns

- Manual config on the primary during an incident without post-incident sync and
  documentation.
- Failover never tested until the real one.
- Standby running older firmware "temporarily" for months.
- Management interface exposed to the internet.
- HA heartbeat on the same VLAN as production traffic (storm = split brain).
