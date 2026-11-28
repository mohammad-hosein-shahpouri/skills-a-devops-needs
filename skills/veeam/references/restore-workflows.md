# Restore Workflows

## Restore Menu (pick by what the situation needs)

| Need | Method | Speed |
|------|--------|-------|
| VM gone/corrupt, can tolerate minutes | Whole-VM restore to production | Slowest, cleanest |
| VM needed NOW while investigating | **Instant VM Recovery** (run from backup) | Minutes |
| One file/folder | File-level restore (FLR) | Fast |
| Database object/row | Application-item restore (SQL/Exchange) | Fast |
| Different platform/export | Export to VM/disk/image | Medium |
| Site lost | Full DR run (replicas/backups to DR) | Planned process |

## Instant VM Recovery (the incident hero)

1. Pick restore point → Instant VM Recovery → target host/resource pool.
2. VM boots reading directly from the backup file; storage vMotion/quick
   migration back to production storage when validated.
3. Caveats: read I/O amplification on the repository — throttle other jobs
   during instant recovery; networking (MAC/IP choices) needs deliberate answers
   to avoid conflicts.
4. Practice it: instant recovery under time pressure is a learned skill, not a
   wizard walk-through.

## File-Level Restore (FLR)

- Multi-OS FLR: Linux FLR helper needs root-equivalent credentials on the guest;
  Windows uses guest credentials or admin share mode.
- Restore to original (overwrite) vs to a different path — prefer different path
  then swap, so the "restore" never makes things worse irreversibly.
- For many small files, mount the restore point and copy from the OS instead of
  GUI-per-file.

## Application-Item Restores

- SQL: database-level or table-level restore; test login mapping after restore.
- Point-in-time with transaction logs requires log backup chain health — verify
  chain before promising a timestamp.

## Restore Order of Operations (during an incident)

```text
1. Contain: stop the damage (isolate infected VMs) BEFORE restoring
2. Choose point-in-time: BEFORE the incident window
3. Instant recovery for the critical tier; queue the rest as whole-VM restores
4. Verify application health per service, not just VM power state
5. Migrate instant-recovery VMs to production storage when stable
6. Evidence: preserve the infected copies (do not delete) for forensics
```

## Verification (restore is not done until checked)

- VM boots with expected services (SureBackup or manual).
- Application-level check: DB accepts connections, app serves requests.
- Data sanity spot checks (row counts, recent records).
- Record the drill: what was restored, how long each step took, gaps found.

## Drills

- Quarterly: file-level + whole-VM on random VMs (surprise selection).
- Annual: full DR scenario (see [dr-checklist](../examples/dr-checklist.md)).
- Track two numbers: **time to decision** and **time to service** — the wizard
  is fast, the organization is slow; practice the organization.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Never-tested instant recovery | First real use is a disaster |
| Overwriting production on restore | The restore becomes the outage |
| Restoring to a point INSIDE the attack window | Reinfection loop |
| Deleting infected copies immediately | Evidence gone |
| Restoring one VM and calling it verified | Service ≠ VM power state |
