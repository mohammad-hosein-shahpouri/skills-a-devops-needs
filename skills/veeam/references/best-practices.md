# Best Practices

## Sizing Rules

| Component | Rule |
|-----------|------|
| Proxy cores | ~1 core per 2-3 concurrent tasks (hot-add); measure, then scale |
| Repository disk | Points × churn × 1.3-1.5 safety; 25% headroom at all times |
| Backup server | Control plane only; catalog DB on fast local disk |
| Guest interaction proxy | One per site for app-aware processing |

Measure actual churn (% of disk changed per day) from job stats before sizing —
assumed churn is the usual sizing error.

## Job Design

1. Tier the estate: gold (hourly or frequent), silver (daily), bronze (weekly) —
   each tier its own jobs and retention.
2. Backup copy to an **immutable** target is part of the design, not an extra.
3. GFS retention lives on the copy job; primary keeps short operational points.
4. Application-aware processing for anything with a database; verify with real
   app restores, not just success status.
5. Enable **integrity checks** (health check) periodically on the tiers whose
   restore is business-critical.

## Ransomware Posture

1. One copy immutable for at least your incident-response horizon.
2. Backup server workgroup-joined (not domain) with layered credentials.
3. MFA on consoles; console reachable only via jump host.
4. Alerts on job deletion/credential changes — intrusion indicators.
5. Escrowed encryption passwords (config backup and backup files).

## Verification Culture

1. SureBackup weekly for critical app groups; custom scripts must assert real
   health.
2. Monthly random whole-VM restore drill; quarterly full DR run.
3. Track time-to-service and fix the slowest organizational step, not the wizard.
4. Every verified-restore report names: point used, duration, checks passed.

## Operations Discipline

| Practice | Detail |
|----------|--------|
| Change windows | Backup infra changes follow the same review as production |
| Credential rotation | vCenter/guest credentials rotated with coordinated job test |
| Configuration backup | Automatic, encrypted, escrowed password |
| Documentation | Job map: which VMs in which job, retention, target — kept current |
| Capacity review | Monthly repository growth trend; storage ordered before 75% |

## Monitoring (summarized)

- Job result, last-run age, repository capacity, restore-point count, copy lag,
  SureBackup results — all in the NOC pipeline with the thresholds from
  [monitoring-and-alerting](monitoring-and-alerting.md).
- Weekly human review of warnings: warnings precede failures.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| One giant job with exception lists | Unmanageable tiers, missed VMs |
| No immutable copy | Ransomware deletes everything |
| Backups never restored/verified | Hope, not protection |
| Repository on production storage | Single failure kills both |
| Backup server domain-joined with admin creds | Compromised domain owns backups |
| Ignoring Warning results | Failures arrive soon after |
| Retention managed by "repo looks big" | Either bloat or lost history |
| DR plan only on paper | The org freezes at the real event |
