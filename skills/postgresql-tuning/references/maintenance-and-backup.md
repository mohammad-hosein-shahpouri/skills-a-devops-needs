# Maintenance, Backup & Recovery

## Backup Strategy: Two Layers

1. **Logical** — `pg_dump` / `pg_dumpall` custom format:
   - Portable, supports selective restore, easy to inspect.
   - Slow for large databases, no PITR, does not preserve all global state
     perfectly at scale.
2. **Physical** — `pg_basebackup` piggybacking WAL archiving:
   - Fast, byte-identical recovery, enables PITR.
   - Tied to the same major version and platform/`pg_checksums` state.

Production normally runs both: physical + continuous WAL for RTO/RPO discipline,
logical dumps for portability and accidental-delete recovery.

## Physical Backup with WAL Archiving

```bash
# postgresql.conf
archive_mode = on
archive_command = 'test ! -f /archive/wal/%f && cp %p /archive/wal/%f'
wal_level = replica
```

```bash
# weekly full base backup
pg_basebackup -D /backups/base/$(date +%F) -Ft -z -P \
  -h db-primary.example.internal -U backup_ro
```

Verify a backup by restoring it to a scratch instance — an unverified backup is
a hope, not a backup.

## PITR (Point-in-Time Recovery)

Restore procedure summary (see
[backup-and-pitr.sh](../examples/backup-and-pitr.sh) for the full script):

1. Stop the instance, move `$PGDATA` aside.
2. Extract the base backup into `$PGDATA`.
3. Ensure `postgresql.conf` has `restore_command` pointing at the archive.
4. Create `recovery.signal` (12+; older versions used `recovery.conf`).
5. Set the target: `recovery_target_time` / `_lsn` / `_name`; choose
   `recovery_target_action = 'promote'` or `'pause'` (pause is the safer choice —
   inspect, then promote).
6. Start, watch logs, validate with `pg_waldump`/`pg_controldata` if needed.

WAL archive integrity matters more than backup tooling: monitor archive
directory growth, `last_archived_wal`/`last_failed_wal` in `pg_stat_archiver`,
and alert on failed archives — a broken archive breaks PITR silently.

## Logical Backup Discipline

```bash
pg_dump -Fc -Z9 -U backup_ro -d appdb -f appdb-$(date +%F).dump
pg_restore --clean --if-exists --no-owner -d appdb_restore appdb-2026-11-28.dump
```

- Restore tests monthly into a throwaway database and run smoke queries.
- `--no-owner`/`--no-privileges` for cross-environment restores; map owners via
  `--role` only when necessary.
- Dump **globals separately** (`pg_dumpall --globals-only`) — roles and
  tablespaces are not in database dumps.
- Large DBs: `-Fd` (directory format) + parallel `pg_dump -j N` / `pg_restore -j N`.

## Routine Maintenance Calendar

| Task | Cadence |
|------|---------|
| Verify autovacuum health (dead tuples, xid age) | daily (automated query) |
| Check WAL archive success | hourly (metric + alert) |
| `pg_stat_statements` top-cost review | weekly |
| Index usage audit / unused-index cleanup | monthly |
| Restore rehearsal (logical) | monthly |
| Base backup + restore test | weekly / quarterly full DR drill |
| `REINDEX CONCURRENTLY` on bloated indexes | as measured, quarterly review |
| Upgrade planning (minor patch) | per release; majors 13→17 with `pg_upgrade` |

## Minor & Major Upgrades

- **Minor** — stop/start binary swap; no `pg_upgrade` needed. Read release notes
  for parameter deprecations.
- **Major** — `pg_upgrade --link` (needs binaries for old and new versions),
  pre-checks with `pg_upgrade --check`, and a `ANALYZE` pass after; extensions
  must be reinstalled/rebuilt.
- Before any upgrade: cold backup, verify restore of that backup, and check
  replication compatibility (logical standby upgrade via publisher/subscriber is
  the zero-downtime path for large fleets).

## Monitoring the Maintenance Layer

```sql
-- autovacuum backlog
SELECT count(*) AS tables_waiting
FROM pg_stat_user_tables WHERE n_dead_tup > 10000;

-- archive health
SELECT last_archived_wal, last_archived_time, last_failed_wal, last_failed_time,
       failed_count
FROM pg_stat_archiver;

-- database size trajectory
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY pg_database_size(datname) DESC;
```

Trend `pg_database_size` weekly: an unexplained jump is either data growth or
bloat (see [Vacuum & Bloat](vacuum-and-bloat.md)) — decide which before adding
disk.

## Anti-Patterns

- `pg_dump` only, with no WAL archive, while claiming PITR capability.
- Backups on the same volume/array as `pg_wal` and `$PGDATA`.
- Never-restored backups.
- `VACUUM FULL` scheduled as regular policy (locks + rewrites).
- Upgrading majors without rehearsal of extensions and `pg_upgrade --check`.
