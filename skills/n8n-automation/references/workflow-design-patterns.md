# Workflow Design Patterns

## Trigger Choice

| Trigger | Use | Caveat |
|---------|-----|--------|
| **Webhook** | Alert intake, external callbacks | Auth + idempotency required |
| Schedule (Cron) | Periodic sweeps, reports | Missed-run semantics; avoid overlaps |
| Queue | Work items pushed by other systems | Requires queue infra |
| Manual/test | Debugging, one-offs | Never in production paths |

For alert pipelines, webhook is the trigger; the sender (Zabbix action, Grafana
notification) must implement retries — n8n returning non-2xx signals failure
back to the sender.

## Pattern 1: Intake → Enrich → Fan-out (the NOC classic)

```text
Webhook (alert) → Normalize (Set node) → Deduplicate → Switch (severity)
   ├─ critical → SMS + Telegram + ticket
   ├─ warning  → Telegram + ticket
   └─ info     → log only
```

- **Normalize first**: map every sender's payload to one internal shape so
  routing logic never depends on the upstream vendor format.
- **Deduplicate**: key on `(source, alert_id)` with a small state table or a
  Redis set with TTL — alert systems re-send on retry storms.

## Pattern 2: Sweep → Batch → Process (periodic maintenance)

```text
Schedule → Query (DB/API listing items) → SplitInBatches (size 50)
   → process batch → loop until done → summary notification
```

- Always batch external calls; one node per 500 items is a lock-up generator.
- Record progress (last processed id/timestamp) so a crash resumes rather than
  restarts.

## Pattern 3: Sub-workflows (composition)

- Reusable units (e.g. "send page", "create ticket") as sub-workflows called via
  Execute Workflow — one place to change paging providers.
- Sub-workflow contract: defined input fields, defined output; document it.
- Error workflow differs from sub-workflows: an error trigger catches failures
  of any workflow that selects it (see [error handling](error-handling-and-retries.md)).

## Idempotency (the design rule that prevents 3am pages)

- Every externally-visible action (send SMS, create ticket, call API) keyed by a
  stable idempotency key (`source:alert_id:action`).
- Before sending, check "already done?" — either via the external system's
  dedupe or a small state store.
- Webhook handlers must return success to retried duplicates instead of
  re-executing side effects.

## State and Concurrency

- Prefer stateless workflows + external state (DB/Redis) over in-workflow
  state; workers make in-memory state unreliable in queue mode.
- Prevent overlapping runs of the same scheduled workflow (mutex via Redis
  lock, or n8n's per-workflow execution serialization settings).

## Naming and Structure

- Workflows: `team-purpose` (`noc-alert-fanout`, `ops-db-sweep`).
- Sticky notes on branches explaining intent; future-you is the audience.
- One concern per workflow: intake vs enrichment vs paging are different
  workflows connected by Execute Workflow when large.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Vendor payload parsing scattered across nodes | Upstream format change breaks many branches |
| Side effects without idempotency | Retry storms double-page |
| No batching on big sweeps | Worker lock-ups, timeouts |
| Credentials inline in nodes (hardcoded headers) | Leak in export; use credential store |
| Giant monolith workflow | Unmaintainable; one error kills all |
| Overlapping schedule runs | Duplicate side effects, DB conflicts |
