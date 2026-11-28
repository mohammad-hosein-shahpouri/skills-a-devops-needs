# Query Analysis & Indexes

## Reading EXPLAIN

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT * FROM orders WHERE customer_id = 42 AND created_at > now() - interval '1 day';
```

Read bottom-up, outermost node last. For every node check:

| Signal | Meaning |
|--------|---------|
| `rows=` (est) vs `actual rows=` | >10x off = stale stats, correlated columns, or bad selectivity assumption |
| `loops=` high | Nested loop repeating; multiply `actual time × loops` for true cost |
| `Buffers: shared hit/read` | Cache behavior; high `read` on slow storage is the cost |
| `Rows Removed by Filter` | Index used but filter wasteful — index does not match predicate |
| `Sort Method: external merge Disk:` | `work_mem` too small for this query |
| `Heap Fetches` (index-only scan) | Visibility map stale → vacuum needed |

Plan node names that matter: `Seq Scan`, `Index Scan`, `Index Only Scan`,
`Bitmap Heap Scan` + `Bitmap Index Scan`, `Nested Loop`, `Hash Join`,
`Merge Join`, `Sort`, `HashAggregate`, `Gather` (parallel), `Parallel Seq Scan`,
`Append`/`MergeAppend` (partitions).

## pg_stat_statements — The Real Workload

```sql
-- enable once: shared_preload_libraries = 'pg_stat_statements'
SELECT queryid, calls, round(total_exec_time::numeric,1) AS total_ms,
       round(mean_exec_time::numeric,2) AS mean_ms,
       rows, shared_blks_read, shared_blks_hit, temp_blks_written,
       left(query, 90) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

Rules of interpretation:

- Rank by **total** time for capacity work, by **mean** for latency work.
- `shared_blks_read` dominated = cache and/or index problem.
- `temp_blks_written` > 0 = `work_mem` pressure or plan issue.
- Normalize query text: same `queryid` across parameter values; do not chase
  one-off literals (`pg_stat_statements.track_utility` off by default).
- Reset the extension stats deliberately (`SELECT pg_stat_statements_reset()`) and
  not during an incident.

## Index Types and When Each Wins

| Type | Best for |
|------|----------|
| B-tree | Equality/range/order by, most columns — the default |
| Composite B-tree | Multi-column predicates with **leftmost prefix** discipline; equality then range |
| Covering (`INCLUDE`) | Avoid heap fetches for a few extra columns without index size blowup |
| Partial (`WHERE`) | Hot subset of a table (e.g. `WHERE status <> 'done'`) — small and fast |
| Expression | Queries filtering on functions (`lower(email)`, `date_trunc('day', ts)`) |
| GIN | `jsonb`, full-text (`tsvector`), arrays |
| GiST | Geometry, ranges, `tsvector` alternatives |
| BRIN | Huge append-only tables with natural correlation (time-series) — tiny index, block-range pruning |
| Hash | Equality-only, no ordering; rarely the right choice over B-tree |

## Index Design Rules

1. One composite index beats several single-column ones for a fixed predicate set.
2. Leftmost prefix matters: `(a, b)` serves `a` and `a, b` but not `b` alone.
3. Do not index low-selectivity columns alone (gender-like) — planner prefers scan.
4. Every index costs writes; write-heavy tables with 8 indexes pay triple on
   updates. Audit `index_scan`/`index_tup_read` per index (`pg_stat_user_indexes`).
5. Drop unused indexes — `idx_scan = 0` after a full statistics window (and not
   inside a replica-only workload).
6. Partial + expression indexes belong in code review, not emergency chat.
7. Concurrent creation in production: `CREATE INDEX CONCURRENTLY` (waits for
   older transactions; two phases; can leave INVALID indexes — check
   `pg_index.indisvalid` and `REINDEX CONCURRENTLY`).

## Join and Sort Tuning

- **Nested loop** wins when outer rows are few and inner has an index;
  otherwise hash/merge joins. Bad nested loops with high `loops` = missing index
  on inner or wrong estimate.
- **Hash join** needs memory: `hash_mem_multiplier × work_mem`.
- **Sort** spill → raise `work_mem` per role, or add an index matching ORDER BY.
- **Aggregation** on big sets: consider pre-aggregation tables or `BRIN` time
  partitions before raising memory.

## Statistics

```sql
ANALYZE VERBOSE orders;                                   -- refresh after bulk load
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500; -- skewed column
CREATE STATISTICS orders_dep (dependencies)
  ON status, created_at FROM orders;                       -- correlated columns
```

`pg_stats` shows `n_distinct`, histogram bounds, and correlation; MB/UB/UC in
`pg_class` feed planner size math — keep vacuum/analyze current or all of this
degrades.

## Anti-Patterns

- `SELECT *` in hot paths (defeats covering indexes, inflates transfer).
- `OFFSET` pagination on large tables — keyset pagination instead.
- `LIKE '%x%'` — no index; use `pg_trgm` GIN or full-text.
- Changing `random_page_cost` alone to "fix" a bad index plan — first check
  statistics and predicate shape.
- Adding indexes reactively per slow query — accumulate a review of index usage
  monthly instead.
