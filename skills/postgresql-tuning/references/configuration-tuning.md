# Configuration Tuning

## Method, Not Magic Numbers

Tune in this order — each step changes what the next one should be:

1. **Measure the workload** — OLTP (many short transactions), OLAP (few heavy
   scans/aggregations), or mixed. Use `pg_stat_statements` call counts, mean times,
   and shared-buffer read ratios.
2. **Set memory from RAM and concurrency**, never from memory of "recommended
   values" for other servers.
3. **Set WAL/checkpoint for write rate** (rows/transactions per second × row size).
4. **Set autovacuum per table** where defaults fail.
5. **Only then tune planner costs** (`random_page_cost` on SSD, cache sizes).
6. Re-measure after every change; one variable at a time.

## Memory Parameters

| Parameter | Starting point | Notes |
|-----------|----------------|-------|
| `shared_buffers` | 25% RAM (up to ~8GB useful) | Large values mostly shift page cache ownership; monitor buffer hit ratio |
| `effective_cache_size` | 50–75% RAM | Planner hint only — no allocation; lies here produce bad plans |
| `work_mem` | 4–16MB global | Raise per session/role for reporting |
| `maintenance_work_mem` | 256MB–1GB | Speeds VACUUM/ANALYZE/CREATE INDEX |
| `hash_mem_multiplier` | 1 (or 2 for analytics) | Multiplies work_mem for hash nodes |
| `temp_buffers` | 8–64MB | Per-session temp usage |

Watch for **work_mem × (sorts+hashes per query) × active sessions** spilling past
RAM; `pg_stat_database.temp_bytes` shows temp spills.

## WAL & Checkpoint Parameters

```ini
wal_level = replica              # logical if you use logical replication/CDC
max_wal_size = 8GB               # size to absorb write bursts between checkpoints
min_wal_size = 1GB               # keep some segments to avoid churn
checkpoint_timeout = 15min       # longer = fewer, bigger checkpoints
checkpoint_completion_target = 0.9
wal_compression = on             # CPU for disk, usually a good trade
wal_buffers = 16MB
synchronous_commit = on          # local is a performance/durability trade — justify it
```

Diagnostics: `pg_stat_bgwriter` (`checkpoints_timed` vs `checkpoints_req`) —
mostly `req` means `max_wal_size` too small; `buffers_checkpoint` share tells you
whether the background writer is doing its job.

## Planner Costs

```ini
random_page_cost = 1.1           # SSD/NVMe (4.0 default assumes spinning disk)
seq_page_cost = 1.0
effective_io_concurrency = 200   # per device parallelism hint
default_statistics_target = 100  # raise to 500 for skewed columns
```

On NVMe, leaving `random_page_cost=4` makes the planner avoid perfectly good index
scans. Verify with `EXPLAIN (BUFFERS)` before/after.

## Concurrency & Connections

```ini
max_connections = 200            # keep low; pool in front
superuser_reserved_connections = 3
idle_in_transaction_session_timeout = '5min'
idle_session_timeout = '30min'
statement_timeout = '30s'        # OLTP default; per-role overrides for reports
lock_timeout = '5s'
deadlock_timeout = '1s'
```

With a pooler (`pgbouncer` transaction mode), `max_connections` can stay small
while thousands of app clients connect. Watch server-side session spikes after
pool mode changes.

## Parallel Query

```ini
max_worker_processes = 8                  # background workers total
max_parallel_workers = 8
max_parallel_workers_per_gather = 2       # start conservative
max_parallel_maintenance_workers = 2
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1
min_parallel_table_scan_size = '8MB'
```

Parallelism trades latency for CPU and memory; on OLTP with tight `statement_timeout`
it can hurt. Measure per workload, cap `per_gather` per role.

## Autovacuum (Defaults Are Too Slow for Busy Tables)

```ini
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = '15s'
autovacuum_vacuum_scale_factor = 0.05      # default 0.2 — lower for hot tables
autovacuum_vacuum_insert_scale_factor = 0.1
autovacuum_vacuum_cost_delay = '2ms'       # default 2ms but 20ms historically
autovacuum_vacuum_cost_limit = 2000        # default 200 — raise with SSD
```

Global values are a compromise; set table-level storage parameters for the few
tables that churn (see [Vacuum & Bloat](vacuum-and-bloat.md)).

## Restart vs Reload

| Change | Method |
|--------|--------|
| `shared_buffers`, `wal_level`, `max_connections`, `max_worker_processes` | restart |
| `work_mem`, `maintenance_work_mem`, autovacuum settings, planner costs | reload (`pg_ctl reload` / `SELECT pg_reload_conf()`) |
| Table storage parameters | `ALTER TABLE ... SET (...)` immediately |

Keep a config repo: `postgresql.conf` in Git, changes reviewed, and
`pg_settings` snapshot diffed (`SELECT name, setting, source FROM pg_settings`).

## Sizing Worksheet

For a 32-core / 128GB OLTP server with a pooler in front:

```text
shared_buffers          32GB      (25%)
effective_cache_size    88GB      (69%)
work_mem                16MB      (global; heavy reports get 256MB via role)
maintenance_work_mem    1GB
max_connections         200
max_parallel_workers    8
max_wal_size            8GB
checkpoint_timeout      15min
```

Then measure: cache hit ratio (`blks_hit/(blks_hit+blks_read)`), temp bytes,
checkpoint mix, autovacuum lag. Adjust one knob per iteration.
