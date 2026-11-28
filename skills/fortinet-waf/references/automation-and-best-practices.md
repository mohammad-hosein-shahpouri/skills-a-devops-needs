# Automation & Best Practices

## Access Paths

| Path | Use |
|------|-----|
| CLI (SSH) | Interactive ops, diagnostics, quick changes |
| **REST API** (token or admin session) | Config backup, bulk policy changes, monitoring queries |
| Web UI | Design work, review; not for repeated manual edits |

Enable the REST API daemon on a management interface; use a dedicated API admin
account (least privilege) with a token stored in the secret manager. Log the API
admin separately — its actions are your change audit trail.

## CLI Patterns an Operator Uses Daily

```text
get system performance top          # CPU/mem of management + dataplane
diagnose system connection          # session table
get router info routing-table all   # return-path sanity
execute ha force sync               # after config changes on HA
diagnose debug application waf -1   # live WAF decisions (time-boxed!)
execute backup config tftp <name> <server>
```

Live debug is powerful and expensive — enable with a filter, capture seconds, then
`diagnose debug disable`.

## REST API Patterns

- `GET /api/v2.0/system/status` — health snapshot for monitoring.
- `GET /api/v2.0/cmdb/...` — policy/profile exports (config-as-data).
- `POST`/`PUT`/`DELETE` on `cmdb` collections — automation of policy CRUD; always
  read-back after write.
- Session vs token auth: token for machines, session for interactive tooling.
- Full working curl flows: [api-automation.sh](../examples/api-automation.sh).

## Config as Code

1. Nightly REST export of the full config (or scheduled `backup config`) to Git
   via your collector.
2. Diff reviews for unexpected drift (hand edits in UI).
3. Reference exports per environment: prod vs staging policy parity check —
   the staging WAF that does not mirror prod is theatre.

## Change Management for WAF Rules

- Every signature-action or exception change: ticket, expected effect, revert
  plan, and the metric that proves it (attack log rule-ID counters).
- Rollouts to production go through the staging WAF with replayed benign traffic
  where possible.
- Schedule signature DB updates in windows; note rule-ID changes that can alter
  false-positive behavior.

## Monitoring Integration

- SNMP or REST → your monitor: CPU, sessions, pool member state, HA state,
  cert expiry, signature age.
- Webhook/syslog of attack logs → SIEM/Loki → NOC dashboards; alert on the
  thresholds from [logs-and-incident-triage](logs-and-incident-triage.md).
- Synthetic request every minute through the full path (DNS → edge → WAF → app)
  — the WAF being "up" is not the same as the path working.

## Best-Practice Checklist

| Area | Check |
|------|-------|
| Deployment | Mode documented; return path correct; monitored synthetic path |
| Profiles | Per-service profiles; observation before enforcement documented |
| Signatures | Severity-based actions; FP exceptions logged with owners |
| ML | Training window per release; thresholds reviewed |
| SSL | Cert expiry monitored; TLS policy graded; HSTS deliberate |
| HA | Failover tested quarterly; sync verified after every change |
| Logs | Forwarded off-box; retention defined; triage workflow exists |
| Automation | Nightly config backup to Git; API admin separate; drift diffed |
| Hardening | Trusted admin hosts; unused services off; admin actions logged |

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| Enforce-on-day-one signatures | False-positive outage on launch |
| Global rule disables for one URL | Whole-app exposure to that class |
| Blocks on CDN edge IP (no XFF trust config) | One attacker = everyone blocked |
| HA never failover-tested | Real failover = surprise outage |
| No config backup restore test | Config loss = rebuild from memory |
| Manual UI edits as routine change | Undocumented drift, unrepeatable fixes |
