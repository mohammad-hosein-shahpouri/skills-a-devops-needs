-- Autovacuum tuning for churn-heavy tables + bloat verification queries
-- Synthetic schema (orders, sessions, events) for illustration.

-- ─── 1. Identify the problem tables ─────────────────────────────────────────
SELECT relname,
       n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum, last_autoanalyze, vacuum_count, autovacuum_count
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
ORDER BY dead_pct DESC NULLS LAST
LIMIT 15;

-- ─── 2. Tighten autovacuum per table (do not touch global defaults) ─────────
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_threshold      = 500,
    autovacuum_analyze_scale_factor  = 0.01,
    autovacuum_vacuum_cost_delay     = 1,
    autovacuum_vacuum_cost_limit     = 5000,
    fillfactor                       = 80
);

ALTER TABLE sessions SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor  = 0.02,
    fillfactor                       = 85
);

-- Verify effective settings
SELECT relname, reloptions
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname IN ('orders', 'sessions') AND n.nspname = 'public';

-- ─── 3. Bloat verification (needs pgstattuple extension) ───────────────────
-- Exact measure for the worst offender
SELECT * FROM pgstattuple('orders');
-- dead_tuple_percent / free_percent high with stable live count => bloat

-- ─── 4. Table-level bloat proxy without extension ──────────────────────────
SELECT relname, n_live_tup,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       round(pg_total_relation_size(relid)::numeric / NULLIF(n_live_tup, 0), 0) AS bytes_per_row
FROM pg_stat_user_tables
WHERE n_live_tup > 0
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 15;
-- Track bytes_per_row weekly: sudden increase = bloat, not growth

-- ─── 5. Blockers that make vacuum ineffective ──────────────────────────────
SELECT pid, state, now() - xact_start AS xact_age, left(query, 60) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND now() - xact_start > interval '10 min';

SELECT slot_name, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
WHERE NOT active OR pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) > 1024*1024*1024;

-- ─── 6. Freeze / wraparound watch ──────────────────────────────────────────
SELECT relname, age(relfrozenxid) AS xid_age,
       round(100.0 * age(relfrozenxid) / 2000000000, 2) AS pct_to_wraparound
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY xid_age DESC
LIMIT 10;

-- ─── 7. Reclaim options, in order of preference for production ─────────────
-- a) Online rewrite for big tables (extension required)
--    pg_repack --table public.orders --no-order --wait-timeout 60
-- b) Partition drop for append-only tables (instant, no bloat)
--    DETACH PARTITION orders_2024_01 CONCURRENTLY; DROP TABLE orders_2024_01;
-- c) VACUUM FULL only on small tables in a window
--    SET lock_timeout = '5s'; VACUUM (FULL, ANALYZE) small_table;
