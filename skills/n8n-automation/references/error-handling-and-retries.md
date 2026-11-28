# Error Handling & Retries

## The Three Mechanisms

| Mechanism | What it does | Use for |
|-----------|--------------|---------|
| **Retry On Fail** (node setting) | Re-executes the node N times, fixed interval | Idempotent outbound calls (DB read, GET, dedupe check) |
| **Continue On Fail** | Node failure produces an error item, flow continues | Optional enrichment steps |
| **Error Workflow** (workflow-level error trigger) | Any unhandled failure routes to a dedicated workflow | The catch-all: notify, log, dead-letter |

## The Error Workflow (build it first)

A minimal error handler:

```text
Error Trigger → Enrich (add workflow name, execution id, error message, URL)
  → Log to DB/file → Notify ops (Telegram/Slack) → Record dead-letter row
```

- Set it as the error workflow on **every** production workflow — no exceptions.
- Payload available: the failed workflow's id/name, the failing node, error
  message, execution URL — include them in the notification so triage is one
  click.
- Keep the handler itself trivial (it fails last; do not build Rube Goldberg).

## Retry Discipline

| Call type | Retry? | Why |
|-----------|--------|-----|
| Read-only (GET, SELECT) | Yes, 2-3 attempts | Harmless to repeat |
| Create ticket / send SMS | **No automatic retry** | Duplicates page people twice |
| Ticket create with idempotency key | Yes | External dedupe makes it safe |
| Webhook intake | N/A (sender retries) | Make the handler idempotent |

The rule: retries are safe exactly when the action is idempotent. Design the
action to be idempotent (idempotency keys), then retry freely.

## Dead-Letter Design

When an alert cannot be delivered (SMS gateway down, ticket API failing):

1. Record: original payload + attempt history into a dead-letter table.
2. Notify ops once per affected workflow (not per item).
3. Provide a replay path (re-run from the dead-letter table with the same
   idempotency keys).
4. Alert on dead-letter **count** growing — it means a downstream dependency is
   broken, and alerts are being lost silently.

## Failure Semantics per Workflow Type

| Workflow | Failure behavior |
|----------|------------------|
| Alert intake | Must respond 2xx fast to sender (their retry handles transient); failures after response go to dead-letter |
| Scheduled sweeps | Let it fail into error workflow; fix before next run; overlaps prevented |
| Sub-workflows | Errors propagate to caller — caller decides notify-or-dead-letter |
| Fan-out branches | One failed branch must not kill siblings — Continue On Fail per branch |

## Timeouts

- HTTP nodes: explicit timeouts (external calls hang; hung nodes block workers).
- Workflow-level execution timeout as the last-resort circuit breaker.
- Respond-to-webhook early: intake responds before heavy processing.

## Testing Failure Paths (do this deliberately)

1. Point a test workflow at a nonexistent endpoint → verify error workflow fires
   and notification arrives.
2. Kill the Redis/DB during a sweep in staging → verify dedupe/locks behave.
3. Replay a dead-letter row → verify idempotency prevents double-paging.
