# Monitoring & Alerting

## What to Watch (protection-system health)

| Signal | Why it matters |
|--------|----------------|
| Job result (Success/Warning/Failed) | The primary heartbeat |
| Last run age per job | A job silently not running is worse than a failure |
| Repository free space | Full repo = protection outage |
| Restore point count per VM vs policy | Retention drift/deletion |
| Backup copy lag | Second copy falling behind |
| SureBackup verification results | Restore-point health |
| Config backup age | Ability to rebuild the backup server |
| License expiry | Feature loss risk |

## Sources

| Source | Gives |
|--------|-------|
| PowerShell module (`Get-VBRJob`, `Get-VBRBackupRepository`...) | Everything, scriptable |
| REST API (v12) | Job/session/repository state for HTTP polling |
| Enterprise Manager REST | Cross-instance queries |
| Veeam ONE | Rich built-in dashboards/reports |
| Windows event/Application logs | Server-level issues |

## PowerShell Health Queries (see [health-inventory.ps1](../examples/health-inventory.ps1))

```powershell
Get-VBRJob | Select-Object Name, @{n='LastResult';e={$_.GetLastResult()}},
    @{n='LastRun';e={$_.FindLastSession().CreationTime}}
Get-VBRBackupRepository | Select-Object Name,
    @{n='UsedGB';e={[math]::Round($_.GetContainerSizeInBytes().Used/1GB)}}
```

Design pattern: a scheduled task dumps job/repository state to JSON or pushes
metrics; the NOC monitor reads that — decouples monitoring from the backup
server's own health.

## Alert Thresholds (NOC wiring)

| Alert | Condition | Severity |
|-------|-----------|----------|
| Job failed | last result = Failed | critical |
| Job warning | last result = Warning | warning |
| Stale job | last run > 1.5× schedule interval | critical |
| Repository full | used > 75% | warning; >85% critical |
| Restore points below policy | points < retention minimum | critical |
| Backup copy lag | copy behind > 24h | warning |
| SureBackup failed | any verification failure | critical |
| Config backup stale | > 7 days | warning |
| Repository integrity check failed | any | critical |
| License expiring | < 30 days | warning |

## Integration Pattern (NOC)

1. Scheduled PowerShell (every 5-15 min) collects job/repo state on the backup
   server (or via REST from a monitor host).
2. Push to Zabbix trapper / Grafana Cloud / HTTP API — one payload per run.
3. NOC alert rules live in the monitor, not in Veeam email — email alerts become
   noise; the NOC pipeline pages by severity.
4. Keep a weekly human review: warning trends (long jobs, slow growth) before
   they become critical.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Email alerts as the only channel | Failures buried |
| Monitoring the backup server only when it breaks | Silent protection outage |
| No alert on stale runs | "Success... yesterday" disaster |
| Repository capacity as a monthly human check | Full repo at the worst moment |
| Ignoring Warning results | Warnings precede failures |
