# Vacuum & Bloat

## Why Bloat Happens (in one paragraph)

Under MVCC, each update writes a new row version and leaves the old one dead but
still occupying a page slot until VACUUM reclaims it. If VACUUM cannot keep pace
with update/delete churn — or is blocked by long transactions, `idle in transaction`
sessions, or replication slots holding back the oldest snapshot — dead tuples
accumulate: tables grow, sequential scans slow down, index-only scans lose
efficiency.

## Autovacuum Mechanics

- The **launcher** wakes every `autovacuum_naptime` and queues tables that crossed
  their threshold: `dead_tuples > threshold + scale_factor × live_tuples`.
- Workers respect `autovacuum_vacuum_cost_delay` / `_cost_limit` throttling.
- **Analyze** runs on its own thresholds (`autovacuum_analyze_scale_factor`).
- **Wraparound prevention** vacuum runs automatically when `age(datfrozenxid)`
  approaches 200M; it can force a freeze-only pass and is not throttled the same
  way.

```sql
SELECT relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY dead_pct DESC NULLS LAST LIMIT 20;
```

## Per-Table Overrides (the fix for hot tables)

```sql
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.02,   -- vacuum after 2% of rows change
  autovacuum_vacuum_threshold     = 500,
  autovacuum_analyze_scale_factor = 0.01,
  autovacuum_vacuum_cost_delay    = 1,
  autovacuum_vacuum_cost_limit     = 5000
);
```

Also raise `fillfactor` for update-heavy tables so HOT updates can stay on the
same page:

```sql
ALTER TABLE sessions SET (fillfactor = 80);   -- leaves room for updates
```

HOT updates avoid index churn; they require the index columns unchanged and space
on the page — fillfactor is the lever.

## Measuring Real Bloat (beyond dead tuples)

`n_dead_tup` is a statistic, not proof of fragmentation. Two practical windows:

```sql
-- pgstattuple (install extension) — exact per-table
SELECT * FROM pgstattuple('orders');
-- returns table_len, tuple_count, dead_tuple_count, free_percent
```

```sql
-- approximation without extension: compare live rows to physical size
SELECT relname, n_live_tup,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       round(pg_total_relation_size(relid)::numeric / NULLIF(n_live_tup, 0), 0) AS bytes_per_row
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 15;
```

A sudden rise in bytes-per-row with stable row count is the bloat signature.

## Reclaiming Space

| Method | Blocking | Use when |
|--------|----------|----------|
| `VACUUM` (plain) | No (I/O heavy) | Routine; reusable space inside pages stays with the table |
| `VACUUM FULL` | Exclusive lock, rewrites table | Small tables during a maintenance window only |
| `pg_repack` | Minimal, online rewrite | Large production tables; requires extension and table PK |
| `CLUSTER` | Exclusive lock; rewrites by index order | Physical ordering matters (rare) |
| Partition detach/drop | Fast | Append-only partitions — the best "vacuum" is dropping old ones |

`VACUUM` never shrinks the file; it only makes pages reusable. Do not expect
significantly smaller files after routine vacuum — that is normal.

## Freeze & Wraparound

- Each table has `relfrozenxid`; `age(relfrozenxid)` must stay far below 2B.
- Monitor:

```sql
SELECT relname, age(relfrozenxid) AS xid_age
FROM pg_class JOIN pg_namespace n ON n.oid = relnamespace
WHERE relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY xid_age DESC LIMIT 10;
```

- Warning threshold: activity at 1.5B+, act well before. Emergency
  `VACUUM FREEZE` is slow, unthrottled, and blocks availability — plan instead.
- `autovacuum_freeze_max_age` (default 200M) forces anti-wraparound vacuum; low
  values mean more intrusive vacuums, high values postpone them.

## Blockers to Vacuum (the usual suspects)

```sql
-- Long transactions
SELECT pid, state, now()-xact_start AS age, left(query, 60)
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND now() - xact_start > interval '10 min';

-- Replication slots holding WAL/snapshots
SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
FROM pg_replication_slots;
```

Fixes: set `idle_in_transaction_session_timeout`, kill stuck sessions, drop
inactive slots (after confirming the consumer is gone), shorten batch transaction
scope.

## Routine Cadence

- Let autovacuum do the continuous work; do not schedule `VACUUM FULL` jobs as
  policy.
- Per-table analyze right after bulk loads (`ANALYZE VERBOSE table`).
- `REINDEX CONCURRENTLY` (or `REINDEX DATABASE CONCURRENTLY`) for index bloat
  separately from table bloat; check `pg_stat_user_indexes` and index size per
  row.
- Partitioned tables: vacuum parent runs children; monitor per partition.
