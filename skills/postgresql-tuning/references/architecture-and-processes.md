# Architecture & Processes

## Process Model

Every client connection gets a **backend process** (`postgres`), forked by the
**postmaster**. Everything else is a background worker:

| Process | Role |
|---------|------|
| `postmaster` | Supervises children, handles crash recovery and shutdown modes |
| `checkpointer` | Writes checkpoint records, flushes dirty buffers, advances redo |
| `background writer` | Opportunistically writes dirty buffers ahead of checkpoints |
| `walwriter` | Writes/flushes WAL buffers asynchronously |
| `autovacuum launcher` + workers | Schedule and run vacuum/analyze per table |
| `archiver` | Copies completed WAL segments to the archive (if enabled) |
| `logical replication launcher` + apply workers | WALSender/walreceiver + apply per subscription |
| `parallel workers` | Serve `max_parallel_workers_per_gather` plans |

Consequence for tuning: with `max_connections=300`, you have 300 forked processes
plus workers — connection count is a **memory and scheduling** cost, not just a
limit. Pool aggressively before raising it.

## Memory Areas

| Area | Scope | Controlled by |
|------|-------|---------------|
| `shared_buffers` | Shared by all backends | Startup; typically 25% of RAM |
| WAL buffers | Shared | `wal_buffers` (auto = 1/32 shared_buffers, cap 16MB) |
| `work_mem` | Per sort/hash operation, per backend | Runtime; `sort`+`hash` occurrences × connections |
| `maintenance_work_mem` | Per maintenance op (VACUUM, CREATE INDEX) | Runtime |
| `temp_buffers`, `hash_mem_multiplier` | Session-local | Runtime |
| OS page cache | Outside PostgreSQL | `effective_cache_size` tells the planner what it can assume |

The classic mistake: raising `work_mem` globally. With 200 sessions × 5 concurrent
sorts × 64MB, worst case is tens of GB. Set a modest global value and raise it
per session/role for known heavy queries.

## Storage Layout

```text
$PGDATA/
├── base/<dboid>/<relfilenode>   # heap, index, toast files
├── pg_wal/                      # WAL segments (16MB each by default)
├── pg_xact/                     # commit status (CLOG)
├── pg_stat/ pg_stat_tmp/        # statistics
└── postgresql.conf, pg_hba.conf
```

- **Pages** are 8KB; rows live in heap pages, TOAST stores large values out-of-line.
- **relfilenode** changes on rewrite operations (`VACUUM FULL`, `CLUSTER`,
  `TRUNCATE`-based rewrites) — file names in `base/` are not stable identifiers;
  use `pg_relation_filepath()`.
- **fsync** discipline: `fsync=on` in production, storage with battery-backed or
  NVMe-grade write cache; `full_page_writes=on` unless storage guarantees torn-page
  protection (almost never true).

## MVCC & the Reason Bloat Exists

- Updates write a **new row version**; the old version stays until VACUUM proves
  no snapshot can see it. Deletes only mark dead.
- `xmin/xmax` plus the commit log decide visibility; long-running transactions or
  abandoned replication slots pin the horizon and block cleanup — the two most
  common causes of runaway bloat.
- `pg_stat_activity.state = 'idle in transaction'` is a bloat generator;
  set `idle_in_transaction_session_timeout`.

## WAL & Checkpoints

```text
change → WAL record (buffers) → walwriter flush → pg_wal segments
                                                  → archiver copies → recycle
checkpoint: flush all dirty buffers, write checkpoint record, advance redo
```

- Checkpoints must complete before `max_wal_size` fills; otherwise WAL grows and
  the checkpointer works overtime (`checkpoints_req` climbing in
  `pg_stat_bgwriter`).
- Tune for **spread checkpoints**: `checkpoint_timeout` 15m,
  `max_wal_size` sized so timed checkpoints dominate
  (see [Configuration Tuning](configuration-tuning.md)).

## Replication & HA Topology (context)

- **Streaming replication** — physical, WAL-based; standby in continuous recovery,
  `hot_standby=on` allows read queries.
- **Logical replication** — per-table, publisher/subscriber; schema changes are
  not replicated.
- **Replication slots** retain WAL until the consumer confirms — a dead slot is
  a disk-filling incident. Monitor `pg_replication_slots.active` and
  `pg_wal` growth.
- For HA orchestration see operators (Patroni) — this skill covers the database
  itself, not the failover manager.

## Where the Planner Fits

- Costs are based on `pg_statistic` (ANALYZE), `random_page_cost` /
  `seq_page_cost`, `effective_cache_size`, and table size estimates.
- Stale statistics after bulk loads → bad plans; always `ANALYZE` after heavy
  changes (autovacuum analyze is normally sufficient but not immediate).
- Extended statistics (`CREATE STATISTICS`) fix correlated-column estimates.
