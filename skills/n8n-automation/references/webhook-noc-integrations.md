# Webhook NOC Integrations

## The Canonical Alert Pipeline

```text
Zabbix action / Grafana notification
        │ webhook (retrying sender)
        ▼
n8n intake (auth check, fast 2xx)
        ▼
Normalize → single internal payload shape
        ▼
Deduplicate (source + alert_id, state store)
        ▼
Route by severity/labels
        ▼
Actions: SMS, Telegram, ticket, email — each idempotent
```

## Intake Contract

- **Respond fast**: webhook node → normalize → enqueue/branch → `Respond to
  Webhook` returns 2xx immediately; heavy sends continue asynchronously.
- Why: senders (Zabbix `curl` media type, Grafana) have retry timeouts measured
  in seconds — slow intake triggers duplicate deliveries.
- Non-2xx only on genuine reject (bad auth, malformed payload) so the sender's
  retry semantics stay meaningful.

## Sender-side (Zabbix webhook media type notes)

- Message templates shape the JSON n8n receives — define a stable schema and
  treat it as a contract (documented next to the workflow).
- Attempts ≥ 2 with interval — transient n8n restarts must not lose pages.
- Secrets (webhook URL/token) via `${__env{...}}` macros on the Zabbix side,
  matched by n8n's credential store on receipt.

## Deduplication

| Mechanism | Pattern |
|-----------|---------|
| Redis SET + TTL | `SETEX dedup:{source}:{alert_id} 3600 1` — NX returns false if duplicate |
| State table | INSERT with unique key; catch conflict as duplicate |
| External system | Ticket systems dedupe by title/id — unreliable alone |

Key on `(source, alert_id)` plus the **action** (`page`, `ticket`, `resolve`) —
the resolve notification after a page must not be deduped away by the page key.

## Fan-out Actions (each idempotent)

| Action | Idempotency key | Notes |
|--------|-----------------|-------|
| SMS gateway | `page:{alert_id}:{recipient}` | Gateways vary; wrap with dedupe |
| Telegram bot | dedupe upstream | Keep messages single-purpose |
| Ticket create | external id field = `alert_id` | Update instead of create on resolve |
| Email | dedupe upstream | Lowest urgency channel |

## Routing Rules

```text
critical → SMS + Telegram + ticket (create or update)
warning  → Telegram + ticket
info     → log only
resolved → update ticket, Telegram follow-up if paged
```

- Route on **normalized labels** (`team`, `service`), never on raw message text.
- Unknown team/label → default route + a "routing miss" counter — silent drops
  become visible.

## Testing the Pipeline

1. Synthetic sender (curl with the documented schema) — dev webhook path.
2. Failure test: take SMS gateway down; verify dead-letter + single ops
   notification, no user-facing double pages.
3. Duplicate test: same alert twice; verify one page.
4. Resolve test: page then resolve; verify ticket updates and follow-up.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Slow intake (work before response) | Sender retries → duplicate alerts |
| Routing on message text | Breaks on every wording change |
| No dedupe | Retry storms triple-page on-call |
| Resolve handled as new alert | Ticket spam, on-call confusion |
| Hardcoded vendor payload parsing everywhere | One schema change breaks many workflows |
| Silent dead-letter drops | Alerts lost without anyone noticing |
