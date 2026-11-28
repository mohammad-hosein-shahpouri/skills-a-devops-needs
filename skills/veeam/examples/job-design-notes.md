# Job Design Notes — annotated production pattern

Environment sketch: vSphere cluster, one Veeam proxy, Linux hardened repo
(primary), S3 object storage with Object Lock (secondary). Names synthetic.

## Tier model

| Tier | VMs | Primary schedule | Primary retention | Secondary (copy job) |
|------|-----|------------------|-------------------|----------------------|
| Gold | DB and core app VMs | every 4h | 7 days points | GFS: 4 weekly, 12 monthly, immutable 30d |
| Silver | standard app VMs | daily 23:00 | 14 days | GFS: 4 weekly, 6 monthly |
| Bronze | dev/test | daily 02:00 | 7 days | weekly copy only |

## Primary job (gold) — design notes

- Schedule: every 4h — RPO ceiling is 4h; coordinate with DB log shipping
  (application-aware processing + log backup) for tighter RPO.
- Proxy: hot-add, 8 cores, max tasks 6 — measured against actual churn.
- Application-aware processing: enabled (SQL role) with guest interaction proxy.
- Encryption: AES-256, password in escrow.
- Change block tracking verified; increments measured at 1-3% of disk per day.

## Secondary copy job (GFS) — design notes

- Immediate copy mode (continuous) to SOBR capacity tier (S3 + Object Lock).
- Immutability: 30 days — exceeds incident response horizon.
- GFS: 4 weekly (Sunday), 12 monthly (1st), annual 1 (Jan 1).
- Health check on the copy: quarterly integrity verification.

## Why this shape

1. Primary short + operational; long-term history on the immutable copy —
   ransomware deleting the primary leaves the immutable copy intact.
2. GFS on the copy avoids primary repo bloat.
3. Hourly gold points keep restore decision granularity for databases.

## Operations checklist per job

- [ ] Owner named in job description
- [ ] Retention matches the tier table above (review quarterly)
- [ ] Warning results triaged within one business day
- [ ] SureBackup app group references the job's VMs (weekly)
- [ ] Repository trend chart reviewed monthly

## Common adjustments

| Symptom | Adjustment |
|---------|------------|
| Job duration creeping past window | Add proxy tasks; split job by disk I/O profile |
| Repository growth faster than forecast | Re-measure churn; shorten primary retention; check deleted-VM leftovers |
| Copy lag > 24h | Raise copy job bandwidth; check WAN accelerator if used |
| App-aware failures | Guest credentials expired; check guest interaction proxy |
