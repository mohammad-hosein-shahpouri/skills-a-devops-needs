-- Health and capacity queries for a PostgreSQL primary/standby pair
-- Run with a read-only monitoring role. Replace 'appdb' placeholders as needed.

-- ─── 1. Sessions and connection saturation ───────────────────────────────────
SELECT state,
       count(*) AS sessions,
       round(100.0 * count(*) / current_setting('max_connections')::int, 1) AS pct
FROM pg_stat_activity
GROUP BY state
ORDER BY sessions DESC;

-- Long-running / idle-in-transaction sessions (bloat and lock culprits)
SELECT pid, usename, state, now() - xact_start AS xact_age,
       now() - state_change AS state_age, left(query, 60) AS query
FROM pg_stat_activity
WHERE (state = 'idle in transaction' AND now() - state_change > interval '5 min')
   OR (state <> 'idle' AND now() - xact_start > interval '10 min')
ORDER BY xact_age DESC;

-- ─── 2. Cache efficiency ────────────────────────────────────────────────────
SELECT datname,
       blks_hit, blks_read,
       round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
       round(temp_bytes / 1024.0 / 1024, 1) AS temp_mb,
       deadlocks, xact_rollback
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1');

-- ─── 3. Autovacuum backlog and dead tuples ──────────────────────────────────
SELECT relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC NULLS LAST
LIMIT 20;

-- Transaction ID wraparound risk
SELECT relname, age(relfrozenxid) AS xid_age
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY xid_age DESC
LIMIT 10;

-- ─── 4. Lock waits ──────────────────────────────────────────────────────────
SELECT pid, pg_blocking_pids(pid) AS blocked_by,
       now() - query_start AS waited, state, left(query, 70) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0
ORDER BY waited DESC;

-- ─── 5. Checkpoint and WAL pressure ─────────────────────────────────────────
SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint,
       buffers_clean, buffers_backend, maxwritten_clean
FROM pg_stat_bgwriter;
-- checkpoints_req growing fast => max_wal_size too small or sudden write burst

-- ─── 6. Table and index size, bloat proxy ───────────────────────────────────
SELECT relname, n_live_tup,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       pg_size_pretty(pg_relation_size(relid)) AS heap_size,
       pg_size_pretty(pg_indexes_size(relid)) AS index_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;

-- Unused indexes (candidates for review, not blind drops)
SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_read,
       pg_size_pretty(pg_relation_size(indexrelid)) AS idx_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- ─── 7. Replication health ──────────────────────────────────────────────────
SELECT client_addr, state, sync_state,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_lag,
       replay_lag AS replay_lag_time
FROM pg_stat_replication;

SELECT slot_name, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;

-- ─── 8. Archive health ──────────────────────────────────────────────────────
SELECT last_archived_wal, last_archived_time,
       last_failed_wal, last_failed_time, failed_count
FROM pg_stat_archiver;

-- ─── 9. Temp file usage (work_mem pressure) ─────────────────────────────────
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY temp_bytes DESC;
