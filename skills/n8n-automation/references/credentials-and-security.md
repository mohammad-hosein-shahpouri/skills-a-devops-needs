# Credentials & Security

## Credential Store Rules

1. **All** credentials live in n8n's credential store (encrypted with
   `N8N_ENCRYPTION_KEY`) — never in node parameters, never in Code nodes, never
   in workflow JSON exports.
2. Name credentials by scope, not by provider guess: `svc-noc-webhook-out`,
   `db-alerts-readonly`.
3. Back up `N8N_ENCRYPTION_KEY` in the secret manager — losing it loses every
   stored credential.
4. Exported workflow JSON contains no secrets (only credential IDs) — but treat
   exports as internal anyway; they reveal infra topology.

## Environment Variables (the config surface)

| Variable | Purpose |
|----------|---------|
| `N8N_ENCRYPTION_KEY` | Credential encryption |
| `N8N_HOST`, `N8N_PORT`, `WEBHOOK_URL` | Public URL for webhook generation — set correctly or produced webhook URLs will be wrong |
| `EXECUTIONS_DATA_SAVE_*`, `EXECUTIONS_DATA_MAX_AGE` | Retention |
| `N8N_BASIC_AUTH_*` / SSO options | Editor access control |
| `NODE_FUNCTION_ALLOW_BUILTIN`, `NODE_FUNCTION_ALLOW_EXTERNAL` | Code node module access — keep minimal |

Keep env vars in the deployment manifest (compose/K8s) sourced from the secret
store; never commit real values.

## Webhook Security

1. **Authentication on every production webhook**: header auth (shared token),
   basic auth, or signature verification.
2. Verify sender authenticity where the upstream supports it (HMAC signature
   check in a Code node or dedicated node).
3. Restrict exposure: webhook endpoints behind the reverse proxy, IP
   allow-listing at the proxy for known senders where possible.
4. Test URLs (`/webhook-test/...`) are editor-triggered only — production paths
   are `/webhook/...`; do not wire producers to test URLs.
5. Return fast: respond early (Respond to Webhook node) and do heavy work after,
   so senders' retry timers do not fire.

## Network Exposure

- Run n8n behind TLS-terminating reverse proxy; editor requires auth (SSO/OIDC
  where available).
- Database and Redis on private networks only.
- Outbound access from workers limited to required services (DB, APIs, queue).
- Separate instances for separate trust domains: an internal ops n8n should not
  share credentials with a public-facing intake instance.

## RBAC and Projects

- Organize workflows into projects/folders per team; share only what the team
  needs.
- Editor access is powerful (can execute anything, read credentials usage) —
  treat editor access like production access.
- Production vs draft: keep a save-deploy path (see best practices) so editor
  pokes do not silently change running pipelines.

## Audit and Review

- Review active workflows quarterly: credentials still valid, owners still
  right, webhooks still needed (retire dead ones — they are an attack surface).
- Log admin/credential changes; alert on unexpected workflow activation.
- Pentest item: webhook endpoints — try replay, oversized payload, missing auth.
