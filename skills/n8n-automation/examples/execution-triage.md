# Execution Triage

When a workflow fails or an alert does not arrive: walk this order.

## 0) Inputs

- Workflow name and execution id (from the error notification, if configured —
  see [error handler](error-handler-workflow.json))
- Time window of the incident
- Upstream sender (Zabbix action, Grafana notification) status

## 1) Did the execution happen at all?

UI: Executions → filter by workflow + time.
API: `GET /api/v1/executions?workflowId=..&status=error`.

- **No execution** → trigger layer problem:
  - Webhook: sender receiving 4xx/5xx? Check sender's attempt log.
    Auth failing (401)? credential/config drift.
  - Schedule: workflow inactive? overlapping-run lock held?
- **Execution exists, status error** → continue to 2.

## 2) Which node failed, and why?

Open the execution: the failed node shows input items and the error message.

| Error signature | Meaning | Fix |
|-----------------|---------|-----|
| `ECONNREFUSED` / timeout on HTTP node | Downstream down or slow | Check target; verify node timeout set |
| 401/403 | Credential expired/rotated | Rotate credential in store |
| 422/400 with schema message | Sender payload changed | Update normalization; notify sender |
| Expression evaluation error | Field missing after upstream change | Fix normalize node; add defaults |
| Out of memory / worker restart | Payload too large or loop | Batch; check SplitInBatches sizing |
| Nothing after dedupe mark | Deduplicate layer flagged | Verify key format change didn't shadow alerts |

## 3) Data vs code

- Compare the failing item against a recent successful execution — the diff
  usually names the missing/changed field.
- If the sender changed its payload format: fix the Normalize node, add a
  regression test payload to the synthetic suite.

## 4) Replay safely

- Use the execution's **retry from failing node** (or copy payload to a test
  workflow) — idempotency keys make replay safe by design.
- If replay would double-page (no idempotency key yet), do NOT replay; run the
  action manually once, then add the key.

## 5) Bookkeeping

- Root cause line in the incident note: node + cause + fix.
- If the sender schema changed: notify the sender's owner; add the new payload
  shape to the contract doc.
- If this is the second failure of the same node this month: treat as flaky
  design — add retry-on-fail (if idempotent) or restructure.

## Quick API reference

```bash
# Recent error executions for one workflow
curl -sS -H "X-N8N-API-KEY: ${KEY}" \
  "https://n8n.example.internal/api/v1/executions?status=error&limit=20" \
  | jq '.data[] | {id, workflowId, startedAt, stoppedAt}'

# Fetch one execution's data (node-by-node run data)
curl -sS -H "X-N8N-API-KEY: ${KEY}" \
  "https://n8n.example.internal/api/v1/executions/<execution-id>" \
  | jq '.data.result.runData | keys'
```
