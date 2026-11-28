# Queue Mode Deployment Baseline

Reference layout for running n8n as a real NOC pipeline component (webhooks that
must not drop alerts).

## Topology

```text
                    ┌──────────────┐
 senders ──▶ TLS LB ─▶ main (editor + │──▶ PostgreSQL (executions, credentials)
                    │  webhook intake)│──▶ Redis (queue + dedupe)
                    └──────────────┘
                         │ queue
              ┌──────────┼──────────┐
              ▼          ▼          ▼
          worker 1   worker 2   worker 3      (execution only)
```

## Main process env (excerpt)

```text
N8N_HOST=n8n.example.internal
WEBHOOK_URL=https://n8n.example.internal/
N8N_ENCRYPTION_KEY=${SECRET}
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=n8n-db.internal
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis.internal
QUEUE_BULL_REDIS_PASSWORD=${SECRET}
EXECUTIONS_DATA_SAVE_ON_SUCCESS=none          # per-workflow overrides possible
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_MAX_AGE=336                   # 14 days
EXECUTIONS_DATA_PRUNE=true
```

## Worker env (excerpt)

```text
N8N_ENCRYPTION_KEY=${SECRET}                  # same key as main
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis.internal
N8N_CONCURRENCY_PRODUCTION_LIMIT=10
```

## Sizing rules

| Component | Start with | Adjust by |
|-----------|------------|-----------|
| Main | 2 vCPU / 4GB | webhook rate; intake latency p95 |
| Worker | 2 vCPU / 2GB, concurrency 10 | queue depth; node CPU vs wait profile |
| Redis | 1 vCPU / 1GB | queue depth, persistence (AOF) needs |
| Postgres | 2 vCPU / 4GB + SSD | execution insert rate; prune lag |

## Health and metrics

- `GET /healthz` on main — LB liveness.
- Prometheus metrics or sidecar: queue depth, executions per minute, worker
  saturation.
- Alert on: queue depth sustained growth (workers behind), intake latency p95
  over sender timeout budget, DB prune backlog.

## Reliability rules

1. Webhook intake must be fast — enqueue only; execution is the workers' job.
2. Redis persistence (AOF) so queued executions survive a Redis restart.
3. Workers deployable independently (rolling) — main stays up for intake.
4. Dedupe state (alert keys) on the same Redis — set persistence to match
   dedupe TTL expectations.
5. Postgres backups + escrowed `N8N_ENCRYPTION_KEY` (see
   [credentials and security](../references/credentials-and-security.md)).

## Upgrade procedure

1. Staging: deploy new pinned version, run synthetic alert suite.
2. Production: upgrade workers rolling (queue drains), then main last.
3. Read release notes for node/behavior changes before bumping majors.
4. Rollback plan: previous image tag, config diffed and stored in Git.
