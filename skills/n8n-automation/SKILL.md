---
name: n8n-automation
description: >
  n8n workflow automation operations — architecture and execution model
  (regular vs queue mode with workers), trigger design (webhook, schedule,
  queue), node and expression patterns, credentials and environment security,
  error handling with error workflows and retries, sub-workflow composition,
  webhook integrations for NOC pipelines (Zabbix, Grafana, alert fan-out),
  version control and deployment practices, and operational best practices.
---

# n8n Workflow Automation

Building and operating n8n as the automation backbone for NOC and ops pipelines:
execution model, workflow design, credential hygiene, error handling, and
webhook integrations that stay reliable under load.

## When to Use This Skill

Activate when the task involves:

- Designing **workflows** — trigger selection, branch logic, sub-workflows,
  idempotent steps
- Understanding the **execution model** — regular vs queue mode (Redis + workers),
  execution data retention, timeouts
- Writing **expressions** — `{{ $json... }}`, `$node`, `$items`, date and JSON
  helpers, error suppression
- **Credentials and security** — credential types, environment variables,
  webhook authentication, basic auth vs header auth, IP allow-listing
- **Error handling** — error triggers, retry-on-fail, continue-on-fail, dead-letter
  patterns
- **Webhook integrations** — receiving Zabbix/Grafana alerts, fan-out to
  SMS/Telegram/ticket systems, deduplication, idempotency
- **Operations** — version control of workflow JSON, export/import, upgrades,
  backups, monitoring executions

## Reference Docs

| Document | Covers |
|----------|--------|
| [Architecture & Execution](references/architecture-and-execution.md) | Editor vs runtime, regular vs queue mode, workers, execution retention, scaling |
| [Workflow Design Patterns](references/workflow-design-patterns.md) | Trigger choice, branching, fan-out/fan-in, sub-workflows, idempotency, batching |
| [Nodes & Expressions](references/nodes-and-expressions.md) | Core nodes, expression syntax, `$json`/`$node`/`$items`, date/JSON helpers |
| [Credentials & Security](references/credentials-and-security.md) | Credential store, env vars, webhook auth, network exposure, RBAC basics |
| [Error Handling & Retries](references/error-handling-and-retries.md) | Error trigger workflow, retry-on-fail, continue-on-fail, dead-letter design |
| [Webhook NOC Integrations](references/webhook-noc-integrations.md) | Receiving alerts, fan-out patterns, deduplication, response contracts |
| [Best Practices](references/best-practices.md) | Version control, deployment, testing, monitoring, anti-patterns |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [alert-fanout-workflow.json](examples/alert-fanout-workflow.json) | Webhook alert intake → deduplicate → route by severity → SMS/Telegram/email |
| [error-handler-workflow.json](examples/error-handler-workflow.json) | Error trigger sub-workflow: log, notify ops, record dead-letter |
| [webhook-security-notes.md](examples/webhook-security-notes.md) | Webhook authentication and exposure hardening notes |
| [queue-mode-baseline.md](examples/queue-mode-baseline.md) | Queue mode deployment baseline: workers, Redis, retention, health endpoints |
| [execution-triage.md](examples/execution-triage.md) | How to diagnose a failed execution from the UI/API |
