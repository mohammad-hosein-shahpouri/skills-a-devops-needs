---
name: postgresql-tuning
description: >
  PostgreSQL performance tuning and operations on vanilla (non-operator)
  deployments — process and memory architecture, postgresql.conf tuning for
  OLTP/OLAP/mixed workloads, autovacuum and bloat control, query analysis with
  EXPLAIN and pg_stat_statements, index design and maintenance, lock contention
  and deadlocks, connection management and pooling, checkpoint and WAL tuning,
  partitioning, backup/recovery and PITR, and monitoring queries for PostgreSQL
  13 through 17.
---

# PostgreSQL Tuning & Operations

Vanilla PostgreSQL tuning for production: configuration, query performance,
vacuum and bloat, locking, connections, storage, maintenance, and the diagnostic
queries that show whether any of it is actually working.

## When to Use This Skill

Activate when the task involves:

- Tuning **`postgresql.conf`** — `shared_buffers`, `work_mem`, `effective_cache_size`,
  checkpoints, WAL, autovacuum, connection limits
- Diagnosing **slow queries** — `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_statements`,
  plan-node analysis, index selection
- **Index** design and maintenance — B-tree/GIN/GiST/BRIN/hash, covering indexes,
  bloat, reindex strategy
- **Bloat and autovacuum** — per-table thresholds, wraparound risk, rewrite
  (`VACUUM FULL` vs `pg_repack`)
- **Lock contention and deadlocks** — `pg_locks`, `pg_blocking_pids`, hot rows,
  advisory locks, isolation levels
- **Connection management** — max_connections, pooling, `pgbouncer` sizing,
  idle-in-transaction
- **Storage and WAL** — checkpoints, `wal_compression`, archiving, PITR,
  `pg_basebackup`
- **Partitioning** — declarative ranges/lists, maintenance jobs, pruning
- **Monitoring** — health queries, capacity planning, alert thresholds

## Reference Docs

| Document | Covers |
|----------|--------|
| [Architecture & Processes](references/architecture-and-processes.md) | Process model, memory areas, WAL and checkpointer, background workers, storage layout |
| [Configuration Tuning](references/configuration-tuning.md) | `postgresql.conf` key parameters, workload profiles, sizing rules, restart vs reload |
| [Query Analysis & Indexes](references/query-analysis-and-indexes.md) | `EXPLAIN` reading, `pg_stat_statements`, plan nodes, index types and design rules |
| [Vacuum & Bloat](references/vacuum-and-bloat.md) | MVCC garbage, autovacuum tuning, bloat measurement, rewrites, wraparound |
| [Locking & Contention](references/locking-and-contention.md) | Lock modes, `pg_locks`, blocking trees, deadlock avoidance, hot-row patterns |
| [Maintenance, Backup & Recovery](references/maintenance-and-backup.md) | Vacuum/reindex cadence, physical and logical backup, WAL archiving, PITR, upgrades |
| [Best Practices](references/best-practices.md) | Checklists, monitoring queries, capacity planning, anti-patterns |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [postgresql-conf-tuning.conf](examples/postgresql-conf-tuning.conf) | Annotated production `postgresql.conf` for a 32-core / 128GB OLTP server |
| [monitoring-queries.sql](examples/monitoring-queries.sql) | Health queries: cache ratio, bloat, locks, replication lag, autovacuum backlog |
| [index-playbook.sql](examples/index-playbook.sql) | Index design and maintenance patterns with `EXPLAIN` before/after |
| [autovacuum-tuning.sql](examples/autovacuum-tuning.sql) | Table-level autovacuum overrides and bloat-check queries |
| [backup-and-pitr.sh](examples/backup-and-pitr.sh) | `pg_basebackup` + WAL archive setup and point-in-time restore procedure |
