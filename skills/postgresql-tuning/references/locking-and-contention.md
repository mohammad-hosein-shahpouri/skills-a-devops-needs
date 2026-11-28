# Locking & Contention

## Lock Modes You Actually Meet

| Mode | Blocks | Typical holder |
|------|--------|----------------|
| `AccessShareLock` | Only `ACCESS EXCLUSIVE` | SELECT |
| `RowShare` / `RowExclusive` | Conflicting DDL | SELECT FOR UPDATE / INSERT, UPDATE, DELETE |
| `ShareUpdateExclusive` | Other maintenance, no DML | VACUUM, CREATE INDEX CONCURRENTLY |
| `ShareLock` / `ShareRowExclusive` | INSERT/UPDATE/DELETE or DDL | Some maintenance/DDL |
| `AccessExclusiveLock` | Everything | DDL, VACUUM FULL, explicit LOCK |

**Critical rule:** an `AccessExclusiveLock` waits behind long SELECTs and then
**queues everything behind it** — a seemingly innocent `ALTER TABLE` on a busy
table can stall traffic for minutes. Always set `lock_timeout` before DDL:

```sql
SET lock_timeout = '5s';
ALTER TABLE orders ADD COLUMN note text;
```

If it times out, retry during low traffic — never raise `lock_timeout` to "make
it work" on hot tables.

## Finding Blockers

```sql
-- blocked PIDs and their blockers (9.6+)
SELECT pid, pg_blocking_pids(pid) AS blocked_by,
       now() - query_start AS waited, state,
       left(query, 80) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY waited DESC;

-- lock inventory aggregated by object
SELECT l.locktype, c.relname, l.mode, count(*)
FROM pg_locks l LEFT JOIN pg_class c ON c.oid = l.relation
WHERE l.granted = false OR l.mode = 'AccessExclusiveLock'
GROUP BY 1,2,3 ORDER BY count(*) DESC;
```

Walk the blocker chain to the root (`pg_blocking_pids` is recursive: a blocker can
itself be blocked), fix the root, not the leaves.

## Deadlocks

- Postgres detects cycles after `deadlock_timeout` (1s) and aborts one victim with
  `ERROR: deadlock detected`.
- Prevention favors **consistent lock ordering**: all code paths acquire rows in
  the same order (e.g. sort by primary key before multi-row update).
- Keep transactions short and outside user interaction; batch jobs do not hold
  locks across HTTP calls.
- Read `pg_stat_database.deadlocks` and the log lines — deadlocks are a code
  smell, not a database defect.

## Hot Rows (contention without locks waiting visibly)

Patterns: a counter row updated by every request, sequence-like IDs, a single
`status` row, shared session/ledger table.

Mitigations:

1. **Shard the counter** — N rows, pick row by hash of request, read sums.
2. **Batch writes** — accumulate in app memory and flush periodically.
3. **`ON CONFLICT` upserts** with `DO UPDATE` still lock the row — sharding still
   needed for extreme rates.
4. **Queue in app** — use a real queue (SKIP LOCKED):

```sql
SELECT id, payload FROM jobs
WHERE status = 'pending'
ORDER BY created_at
FOR UPDATE SKIP LOCKED
LIMIT 10;
```

`SKIP LOCKED` turns a hot-row queue into parallel consumers — one of the
highest-value PostgreSQL tricks.

## Isolation & Read Behavior

- Default `READ COMMITTED`: each statement sees the latest committed data.
- `REPEATABLE READ` gives statement-to-statement consistency and turns some
  conflicts into `serialization_failure` errors — expect retries.
- `SELECT FOR UPDATE` locks rows for the transaction; `NOWAIT` fails fast,
  `SKIP LOCKED` skips free rows.
- `advisory locks` (`pg_advisory_lock`, `pg_try_advisory_xact_lock`) coordinate
  application-level resources (cron single-run, migration guard) without touching
  row locks:

```sql
SELECT pg_try_advisory_xact_lock(hashtext('nightly-report'));   -- true = got it
```

## Contention in DDL & Maintenance

- `CREATE INDEX` (non-concurrent) takes `ShareLock` and blocks writes for the
  whole build — always use `CONCURRENTLY` in production.
- `VACUUM FULL` takes `AccessExclusiveLock` — schedule windows or use `pg_repack`.
- `ALTER TABLE ... SET TABLESPACE`/`TYPE` rewrites with an exclusive lock;
  column type changes on big tables deserve a dedicated plan (new table +
  backfill + swap).
- `TRUNCATE` is exclusive but instant; dropping old partitions beats deleting
  rows with `DELETE` (which creates bloat and lock volume).

## Monitoring & Alerting

| Metric | Source | Alert when |
|--------|--------|-----------|
| Blocked sessions | `pg_stat_activity` + `pg_blocking_pids` | >0 sustained >30s |
| Lock wait time | `pg_locks` granted=false | >5s repeatedly |
| Deadlocks/min | `pg_stat_database.deadlocks` delta | Any regular occurrence |
| Sessions `idle in transaction` | `pg_stat_activity.state` | > N for > 5 min |
| `lock_timeout` errors | application logs | Rising trend |

## Anti-Patterns

- No `lock_timeout` in migrations — the classic production stall.
- `SELECT ... FOR UPDATE` on wide, long-running loops.
- Long transactions spanning external API calls.
- Assuming "not visible in pg_locks" means no contention — hot rows show up as
  latency, not blocked PIDs; watch `pg_stat_statements` mean time on the same
  query id.
