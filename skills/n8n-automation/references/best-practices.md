# Best Practices

## Version Control and Deployment

1. **Workflow JSON in Git** — export on save (UI/API/CLI) into a repo; review
   changes like code.
2. Deploy path: import reviewed JSON into staging instance → test with synthetic
   events → import to production. Editor live-editing production workflows
   without review is how 3am outages are manufactured.
3. One workflow = one concern; sub-workflows compose.
4. Workflow description field names: owner, purpose, upstream sender, runbook
   link.

## Testing

1. Synthetic events for every intake (documented payload schema, curl examples).
2. Failure-path tests: error workflow fires, dead-letter records, notifications
   arrive exactly once.
3. Duplicate/replay tests: idempotency proven, not assumed.
4. Load sanity: burst of N alerts in staging; watch intake latency and queue
   depth.

## Naming and Documentation

| Object | Convention |
|--------|------------|
| Workflow | `team-purpose` (`noc-alert-fanout`) |
| Credential | `svc-scope` (`svc-noc-webhook-out`) |
| Webhook path | `/webhook/<team>/<purpose>` |
| Sub-workflow | `lib-<function>` (`lib-pager`) |

Sticky notes explain branches; the reader is the on-call engineer at 3am.

## Operational Hygiene

1. Prune execution data; keep error executions longer than successes.
2. Queue mode before real load; monitor queue depth and worker saturation.
3. Postgres for the DB with backups + escrowed `N8N_ENCRYPTION_KEY`.
4. Upgrade cadence: pin the n8n image version; read release notes; test in
   staging — node behavior changes between versions.
5. Retire dead webhooks and workflows quarterly — each is an exposed surface.

## Metrics for the NOC

| Metric | Signal |
|--------|--------|
| Intake latency p95 | Webhook responsiveness (sender retries at stake) |
| Queue depth | Worker saturation |
| Executions failed/hour per workflow | Automation health |
| Dead-letter count | Downstream delivery broken |
| Dedupe hit rate | Sender retry behavior (spike = upstream trouble) |

## Security Posture (summarized)

- Webhook auth on every production intake; signatures verified where supported.
- Credentials only in the store; exports treated as topology leaks.
- Editor access controlled like production access; audit admin actions.
- Separate trust domains: public intake instance ≠ internal ops instance.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Live-editing production from the editor | Unreviewed, unrepeatable changes |
| Side effects without idempotency | Double pages, duplicate tickets |
| Secrets in Set nodes/headers | Leak via export or execution log |
| SQLite in production | Lock contention, no HA |
| No pruning | DB grows until the instance dies |
| Monolith workflow | One bad node breaks everything |
| Ignoring dead-letters | Alerts lost silently |
| Test URLs wired to production senders | Editor restarts break alerting |
