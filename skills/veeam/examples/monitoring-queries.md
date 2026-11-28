# Monitoring Queries & Thresholds

Wire Veeam health into the NOC pipeline: PowerShell/REST poll → JSON → Zabbix/
Grafana → alert rules. Collectors: see [health-inventory.ps1](health-inventory.ps1).

## Metric map

| Metric | Source | Type |
|--------|--------|------|
| `veeam.job.result{name}` | PowerShell GetLastResult | state (Success/Warning/Failed) |
| `veeam.job.lastrun.hours{name}` | FindLastSession age | gauge |
| `veeam.repo.used.gb{name}` | repository container size | gauge |
| `veeam.repo.free.gb{name}` | repository free | gauge |
| `veeam.points.count{backup}` | restore points per backup | gauge |
| `veeam.copy.lag.hours{job}` | backup copy session lag | gauge |
| `veeam.surebackup.result{group}` | verification job result | state |
| `veeam.configbackup.age.days` | config backup age | gauge |

## Alert rules (NOC-side)

| Rule | Condition | Severity |
|------|-----------|----------|
| Job failed | `job.result == Failed` | critical (page) |
| Job warning | `job.result == Warning` | warning |
| Stale job | `lastrun.hours > 1.5 × interval` | critical |
| Repository floor | `repo.free.gb < 200` (tune per repo) | warning; <100 critical |
| Retention drift | `points.count < policy minimum` | critical |
| Copy lag | `copy.lag.hours > 24` | warning |
| Verification failed | `surebackup.result == Failed` | critical |
| Config backup stale | `configbackup.age.days > 7` | warning |

## REST alternative (v12) — no PowerShell needed

```bash
# Session token then job sessions (host: backup.example.internal)
curl -sk -X POST https://backup.example.internal:9419/api/sessionMngr/login \
     -u 'svc-monitor:<password-from-secret-store>' -c cookies.txt

curl -sk -b cookies.txt \
  https://backup.example.internal:9419/api/v1/jobs \
  | jq '.refs[] | {name: .Name, lastResult: .LastResult}'
```

Poll every 10-15 min; keep the monitor account read-only.

## Grafana panel set

1. Job results over time (state timeline per job)
2. Repository capacity trend (used GB per repo, with 75%/85% thresholds)
3. Restore-point counts (bars vs retention policy line)
4. Copy lag (hours) per copy job
5. SureBackup verification results (weekly grid)

## Noise control

- Maintenance windows: silence the collector during planned backup-infra changes
  (same review as production silences).
- Warning storms from one flaky agent VM: fix the VM; do not mute the job.
- Weekly human review of warnings — warnings are early failures.
