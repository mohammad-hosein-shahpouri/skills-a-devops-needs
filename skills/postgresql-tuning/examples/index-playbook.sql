-- Index design and maintenance playbook
-- Schema: synthetic orders table for illustration; no real data.

-- ─── Baseline: measure before touching anything ─────────────────────────────
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, status, total_cents, created_at
FROM orders
WHERE customer_id = 42 AND created_at >= now() - interval '1 day'
ORDER BY created_at DESC
LIMIT 100;

-- ─── Rule 1: composite index matching the predicate shape ───────────────────
-- Equality on customer_id, range on created_at => (customer_id, created_at)
CREATE INDEX CONCURRENTLY idx_orders_customer_created
    ON orders (customer_id, created_at DESC);

-- Verify the plan picked the index and how many buffers it touches
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, status, total_cents, created_at
FROM orders
WHERE customer_id = 42 AND created_at >= now() - interval '1 day'
ORDER BY created_at DESC
LIMIT 100;

-- Check the index is valid (CONCURRENTLY can leave INVALID indexes)
SELECT indexrelid::regclass, indisvalid, indisready
FROM pg_index
WHERE indrelid = 'orders'::regclass;

-- ─── Rule 2: partial index for a hot subset ─────────────────────────────────
-- Only open orders matter for the operational dashboard
CREATE INDEX CONCURRENTLY idx_orders_open
    ON orders (created_at DESC)
    WHERE status IN ('pending', 'processing');

EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM orders
WHERE status IN ('pending', 'processing')
  AND created_at >= now() - interval '1 hour';

-- ─── Rule 3: covering index to avoid heap fetches ───────────────────────────
CREATE INDEX CONCURRENTLY idx_orders_cover_total
    ON orders (customer_id, created_at DESC) INCLUDE (total_cents);

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, created_at, total_cents
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;
-- Expect "Index Only Scan"; Heap Fetches should be near zero (if not: VACUUM/ANALYZE)

-- ─── Rule 4: expression index for function predicates ──────────────────────
CREATE INDEX CONCURRENTLY idx_orders_month
    ON orders (date_trunc('month', created_at));

EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM orders
WHERE date_trunc('month', created_at) = date_trunc('month', now());

-- ─── Rule 5: BRIN for huge append-only time series ─────────────────────────
CREATE INDEX CONCURRENTLY idx_orders_created_brin
    ON orders USING brin (created_at) WITH (pages_per_range = 64);

-- ─── Maintenance: find bloat-free index usage ───────────────────────────────
SELECT indexrelid::regclass AS index_name,
       idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY pg_relation_size(indexrelid) DESC;

-- ─── Maintenance: rebuild a bloated index online ───────────────────────────
REINDEX INDEX CONCURRENTLY idx_orders_customer_created;

-- ─── Maintenance: drop a confirmed-unused index safely ─────────────────────
-- Review idx_scan over a full statistics window first, then:
-- DROP INDEX CONCURRENTLY idx_orders_month;

-- ─── Notes ─────────────────────────────────────────────────────────────────
-- * CONCURRENTLY waits for old transactions; can fail — retry, do not force.
-- * Every index costs write throughput; measure pg_stat_statements before/after.
-- * On write-heavy tables set fillfactor 80-90 to enable HOT updates.
-- * After bulk load: ANALYZE orders; then re-run EXPLAIN to compare estimates.
