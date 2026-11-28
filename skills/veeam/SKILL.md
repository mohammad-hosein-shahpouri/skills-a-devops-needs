---
name: veeam
description: >
  Veeam Backup & Replication v12 operations — architecture (backup server,
  proxies, repositories, SOBR), backup/backup-copy job design, incremental and
  synthetic operation, immutability and ransomware defense, restore workflows
  (whole-VM, file-level, instant recovery), SureBackup verification, 3-2-1-1-0
  rule implementation, monitoring and alert integration, PowerShell automation,
  and capacity planning best practices.
---

# Veeam Backup & Replication Operations

Running backup infrastructure that restores when it matters: job design,
repository architecture, verification, restore drills, monitoring, and the
automation surface PowerShell gives you.

## When to Use This Skill

Activate when the task involves:

- Designing **backup infrastructure** — backup server sizing, proxy roles
  (hot-add/virtual appliance/network), repository layout, SOBR
- Building **jobs** — VM backup, backup copy (GFS), agent, NAS; scheduling and
  retention
- **Ransomware defense** — immutable/encrypted repositories, hardened Linux
  repos, 3-2-1-1-0 compliance
- **Restore operations** — whole-VM, guest files, application items, instant VM
  recovery, export
- **Verification** — SureBackup, application testing, restore drills
- **Monitoring** — job states, repository capacity, restore-point health,
  integration with Zabbix/Grafana/NOC alerting
- **Automation** — PowerShell module (Get/Set/Start-VBRJob...), reporting
  queries, inventory

## Reference Docs

| Document | Covers |
|----------|--------|
| [Architecture & Components](references/architecture-and-components.md) | Backup server, proxies, gateways, repositories, SOBR, data flow modes |
| [Jobs & Retention](references/jobs-and-retention.md) | Job types, incremental forever, GFS, backup copy, scheduling, retention math |
| [Immutability & Ransomware Defense](references/immutability-and-ransomware-defense.md) | Hardened repositories, immutability periods, encryption, 3-2-1-1-0 |
| [Restore Workflows](references/restore-workflows.md) | Whole-VM, instant recovery, file/item restores, drills |
| [SureBackup & Verification](references/surebackup-and-verification.md) | Virtual lab, application groups, verification jobs, scheduled restore testing |
| [Monitoring & Alerting](references/monitoring-and-alerting.md) | Job/repository health metrics, PowerShell queries, alert thresholds, NOC wiring |
| [Best Practices](references/best-practices.md) | Sizing rules, capacity planning, operational checklists, anti-patterns |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [job-design-notes.md](examples/job-design-notes.md) | Annotated job design: VM backup + backup copy GFS + immutable target |
| [restore-runbook.md](examples/restore-runbook.md) | Restore runbook: instant recovery, file-level, verification steps |
| [health-inventory.ps1](examples/health-inventory.ps1) | PowerShell: jobs, repository capacity, restore points, last-run status |
| [monitoring-queries.md](examples/monitoring-queries.md) | Metrics/queries to wire into Zabbix/Grafana with alert thresholds |
| [dr-checklist.md](examples/dr-checklist.md) | Quarterly DR drill checklist with pass criteria |
