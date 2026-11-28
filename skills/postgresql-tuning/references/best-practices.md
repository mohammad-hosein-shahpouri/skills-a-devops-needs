# Best Practices

## Tuning Discipline

1. **One knob at a time, measured.** Record the value, the workload metric, the
   result; revert if the metric does not move. Config changes without a
   measurement line are folklore.
2. **Start from the workload, not from blog numbers.** 32GB `shared_buffers` on
   a 16GB host is a swap disaster; 4GB on a 256GB analytics box is waste — size
   from RAM and concurrency.
3. **`postgresql.conf` lives in Git**, reviewed like code, with `pg_settings`
   snapshots for drift detection.
4. **Per-table beats global** for autovacuum and fillfactor; global values are
   compromise values.
5. **Planner cost changes come after statistics work** — fix `ANALYZE`, extended
   statistics, and predicate shape before touching `random_page_cost`.

## Query Hygiene

1. `pg_stat_statements` ranked weekly — top total time first, then mean time.
2. Every slow-query fix ends with an `EXPLAIN (ANALYZE, BUFFERS)` before/after
   captured in the ticket.
3. Indexes are added by design review, not reflexively; unused indexes are
   deleted on a monthly audit.
4. No `SELECT *` in hot paths; keyset pagination over `OFFSET`.
5. Batch transactions: thousands of small commits is normal; one enormous
   transaction holding locks for hours is an incident.

## Connections

1. Pool in front (`pgbouncer` transaction mode) — `max_connections` stays in the
   low hundreds.
2. `idle_in_transaction_session_timeout` and `statement_timeout` are mandatory
   on production roles; reports get their own longer timeout role.
3. Monitor server-side session counts and pool queue depth together — mismatched
   numbers are the usual "the database is slow" story.

## Safety Rails

1. `lock_timeout` on every migration and DDL statement; retry in a quiet window
   instead of competing.
2. `CREATE INDEX CONCURRENTLY` for production tables; validate `indisvalid`
   afterwards.
3. Inactive replication slots are a disk bomb — alert on `active=false` older
   than the SLA.
4. Wraparound age and archive failures are top-tier alerts, not dashboards no one
   reads.

## Monitoring Set (the minimum viable)

```sql
-- availability & connections
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
-- cache hit ratio
SELECT round(sum(blks_hit)*100.0 / NULLIF(sum(blks_hit+blks_read),0),2)
FROM pg_stat_database;
-- dead tuple pressure
SELECT relname, n_dead_tup, last_autovacuum FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;
-- replication lag
SELECT client_addr, state, sent_lsn - replay_lsn AS lag_bytes FROM pg_stat_replication;
-- xid age
SELECT max(age(datfrozenxid)) FROM pg_class WHERE relkind='r';
```

Alert on: connection saturation, cache hit ratio drop, dead-tuple growth, xid
age > 1.5B, replication lag, archive failures, lock waits, temp spill growth.

## Capacity Planning

- Track: database size, table growth rate, NVPS-like write rate (WAL bytes/min),
  connections peak, `pg_stat_statements` total time growth.
- Disk headroom ≥ 30% for WAL spikes, vacuum rewrites, and base backups.
- Memory headroom ≥ 20% — OS page cache is a participant in performance.
- CPU headroom ≥ 20% — parallel queries and checkpoints compete with app work.

## Common Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Huge `work_mem` globally | Memory blowups and OOM killer |
| No pooler, `max_connections=1000` | Contention and memory sprawl |
| `VACUUM FULL` on schedule | Lock storms |
| `random_page_cost=4` on NVMe | Index scans avoided, seq scans everywhere |
| `fsync=off` "for speed" | Data loss on power event |
| Long transactions over HTTP | Bloat + lock waits + wraparound pressure |
| Ignoring replication slots | WAL fills the disk |
| Backups never restored | Recovery discovered broken during incident |
