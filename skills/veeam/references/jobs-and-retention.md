# Jobs & Retention

## Job Types

| Job | Purpose |
|-----|---------|
| VM backup (vSphere/Hyper-V) | Primary protection of VMs |
| Backup copy | Second copy to another repo/offsite (GFS-capable) |
| Agent backup | Physical servers/workloads outside hypervisor |
| NAS/file backup | File shares with FLR |
| Replication | Standby VM copy (RPO in minutes, separate from backups) |

## Incremental Forever + Retention Model

- One initial full (`VBK`), then incrementals (`VIB`); retention deletes old
  points; synthetic operations can merge.
- **Retention = number of restore points** (days-based or GFS-based), not a
  time-to-live on disk usage — size repositories from points × churn.
- GFS (grandfather-father-son): weekly fulls kept N weeks, monthly N months,
  yearly N years — implemented via **backup copy jobs**, not the primary job.

## Backup Copy Jobs (the second copy)

- Mode **immediate copy** (per-job, near-continuous protection) vs periodic
  (legacy, scheduled).
- GFS on the copy job is where long-term retention lives: e.g. keep
  7 daily (primary), 4 weekly + 12 monthly on the immutable target.
- Health check option re-verifies backup files on the target periodically.

## Scheduling

| Concern | Practice |
|---------|----------|
| RPO | Primary backup interval defines RPO ceiling — hourly jobs for critical tiers |
| Load windows | Stagger job start times; concurrent tasks bound proxy load |
| Backup windows shrinking | Move to backup-copy-driven offsite during day; primary at night |
| App-consistency | Schedule around DB log backup cycles; use application-aware processing |

## Retention Math (size the repository)

```text
daily increment ≈ VM churn (measure: % of disk per day)
repo size ≈ Σ (full size + points × avg increment) × safety 1.3-1.5
GFS targets add: weekly fulls × weeks + monthly × months
```

Track `used/capacity` per repository weekly; alarms at 75% — backup repos
filling up is an outage of the protection system, not just disk pressure.

## Application-Aware Processing

- For VMs running databases: enable app-aware snapshots so VSS produces
  consistent backups; verify with the application's own restore tests.
- Guest interaction proxies handle the in-guest jobs; size one per site.
- DB log backup (for SQL) gives point-in-time restore beyond VM-level points.

## Job Hygiene

1. Group VMs by RPO/retention tier (gold/silver/bronze) — different jobs, not one
   giant job with exceptions.
2. Exceptions list is a smell: a VM moved out of a job permanently needs a new
   tier, not an infinite exclusion.
3. Every job has an owner and a purpose comment; orphan jobs get deleted.
4. Enable job **verification/copy checks** for the tiers whose restore is
   business-critical.
5. vCenter credential changes break all jobs at once — rotate credentials with a
   coordinated test.

## Retention Pitfalls

| Mistake | Consequence |
|---------|-------------|
| Retention in days on incrementals only | No GFS → one bad full = lost history |
| Backup copy disabled "temporarily" | Single-copy estate = ransomware target |
| Retention too long on primary | Repository bloat, slow merges |
| No encryption on backup copies | Offsite copy is a data-leak surface |
| Forgetting config backup of the backup server | Rebuilding all job definitions by hand |
