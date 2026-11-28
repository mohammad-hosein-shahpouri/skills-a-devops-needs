# Nodes & Expressions

## Core Node Vocabulary

| Node | Use |
|------|-----|
| Webhook | HTTP intake (test URL vs production URL distinction matters) |
| HTTP Request | Any outbound REST call |
| Set | Build/normalize the output payload |
| IF / Switch | Branching (binary / multi-way) |
| SplitInBatches | Loop over items in chunks |
| Merge | Combine branches (append/combine by key) |
| Code (JS) | Complex transforms — keep small; logic belongs in code repo if large |
| Postgres/MySQL/Redis | Data access |
| Execute Workflow | Sub-workflow calls |
| Respond to Webhook | Custom HTTP response to the caller |
| No Op, Stop And Error | Flow control; explicit failure signals |

## Expression Syntax

Expressions run per-item in `{{ }}`:

```text
{{ $json.alert_id }}
{{ $json.severity.toLowerCase() }}
{{ $json.timestamp.toFormat('yyyy-MM-dd HH:mm') }}       (Luxon-style via n8n date helper)
{{ $node["Normalize"].json["host"] }}                    (another node's output)
{{ $items("Deduplicate").length }}                       (items from a named node)
{{ JSON.stringify($json) }}
```

Everyday patterns:

| Need | Expression |
|------|------------|
| Default for missing field | `{{ $json.owner || 'noc-default' }}` |
| Safe nested access | `{{ $json.alert?.labels?.team ?? 'unknown' }}` |
| Severity mapping | `{{ {critical:'P1', warning:'P2'}[$json.severity] || 'P3' }}` |
| Slug for idempotency key | `{{ $json.source + ':' + $json.alert_id }}` |
| Human timestamp | `{{ $json.clock.toISO() }}` |

## Error Suppression vs Handling

- Node setting **Continue On Fail**: the flow continues with `{error: ...}` item —
  use for optional enrichments.
- **Retry On Fail**: fixed count/interval — use for idempotent outbound calls
  only (never for SMS/ticket side effects).
- **Stop and Error**: escalate to the error workflow deliberately — better than
  letting a broken branch silently pass.

## Data Shape Discipline

- Normalize once (a `Set` node at intake); downstream nodes then see one shape
  regardless of sender.
- Keep items small: strip payloads you do not need before storing execution data
  (execution records keep full item JSON).
- For multi-item flows, remember n8n executes per-item by default; nodes that
  aggregate (Code, Merge) need awareness of item arrays.

## HTTP Request Node Essentials

- Set explicit **timeouts**; never leave defaults on external calls.
- Batching: use query continuation or pagination nodes rather than unbounded
  pulls.
- Authentication via credentials only; never raw headers with secrets in the
  workflow JSON (exports would leak them).
- On non-2xx: either configure "Never Error" + inspect status, or let it error
  into the error workflow — pick per call semantics and be consistent.

## Code Node Conventions

```javascript
// Input: items array. Keep it pure: no external fetches; transform only.
return items.map(item => {
  const a = item.json;
  return { json: {
    key: `${a.source}:${a.alert_id}`,
    severity: a.severity.toLowerCase(),
    team: a.labels?.team ?? 'unknown',
  }};
});
```

- Pure transforms only; side effects go through dedicated nodes (testable,
  retryable).
- Large/complex logic: move to a real library/sub-workflow; a 200-line Code node
  is unreviewable.
