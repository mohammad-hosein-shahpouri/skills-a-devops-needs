# Architecture & Execution

## Topology

```text
Browser/UI ──▶ n8n editor ──┐
                            ├──▶ workflow runtime ──▶ nodes (HTTP, DB, queue...)
Webhooks ───────────────────┘
                            │
              (queue mode) Redis ──▶ workers × N
                            │
                     database (executions, credentials store)
```

- **Editor** designs and triggers manually; the **runtime** executes.
- Execution data, credentials, and workflow definitions persist in the
  configured database (SQLite for toys; PostgreSQL for anything real).
- **Credentials** live encrypted in the database; encryption key comes from
  `N8N_ENCRYPTION_KEY` — back this key up or lose every credential on a
  migration.

## Regular vs Queue Mode

| Mode | Behavior | Use |
|------|----------|-----|
| Regular | One process executes everything | Small teams, light load |
| **Queue mode** | Main process enqueues; workers execute | NOC pipelines, many webhooks, heavy nodes |

Queue mode baseline:

```text
N8N_EXECUTION_MODE = queue
QUEUE_BULL_REDIS_HOST / PASSWORD
N8N_CONCURRENCY_PRODUCTION_LIMIT (per worker)
```

- Size workers by node wait time vs CPU time: I/O-heavy fan-out scales well;
  one worker per 2-4 vCPU is a sane start.
- Webhook intake stays on the main process (fast enqueue), execution moves to
  workers — latency becomes queue-depth dependent; monitor it.

## Execution Retention

| Setting | Effect |
|---------|--------|
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` / `..._ERROR` | Keep/drop execution records |
| `EXECUTIONS_DATA_MAX_AGE` (hours) | Prune age |
| `EXECUTIONS_DATA_PRUNE` | Enable pruning |

NOC-scale deployments generate thousands of executions — keep error executions
longer than successes (`save_on_success: false` for high-frequency flows, or
aggressive pruning), or the database becomes the outage.

## Timeouts and Limits

- Per-workflow execution timeout prevents runaway loops from eating workers.
- Node-level timeouts on HTTP nodes stop wedged external calls.
- `N8N_PAYLOAD_SIZE_MAX` guards oversized webhook payloads; reject early.

## Backups

- Workflow definitions: export JSON (CLI/UI/API) on a schedule into Git.
- Database: standard PostgreSQL backup — contains credentials (encrypted) and
  execution history.
- **`N8N_ENCRYPTION_KEY` is the crown jewel**: store it in the secret manager;
  without it the restored database's credentials are unreadable.

## Health and Monitoring

| Endpoint/Signal | Use |
|-----------------|-----|
| `/healthz` | Liveness for the LB |
| `/metrics` (Prometheus, enterprise or sidecar) | Queue depth, execution counts |
| Redis queue depth | Worker saturation |
| Database size / prune lag | Retention working |

## Scaling Checklist

1. Queue mode on before the first real webhook pipeline.
2. Prune execution data; cap success retention.
3. Postgres for the DB; back it up and back up the encryption key.
4. Workers behind the queue; set concurrency per worker; monitor queue depth.
5. Version-controlled workflow JSON with a deploy path (see best practices).
