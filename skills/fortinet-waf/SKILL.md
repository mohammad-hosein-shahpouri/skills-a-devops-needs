---
name: fortinet-waf
description: >
  FortiWeb web application firewall operations (7.x) — deployment modes and
  server policies, web protection profile stack (signature, ML anomaly, bot
  mitigation, DoS), SSL inspection and offloading, server pools and health
  checks, HA pairs, virtual servers and VDOM basics, log forwarding and
  FortiAnalyzer, CLI and REST API automation, incident triage with attack logs,
  false-positive tuning, and hardening best practices.
---

# FortiWeb WAF Operations

Deploying, tuning, and operating FortiWeb as the web application firewall in
front of CDN origins and web services: protection stack, SSL, HA, logging, and
the automation paths an NOC actually uses.

## When to Use This Skill

Activate when the task involves:

- Designing **deployment topology** — reverse proxy, true transparent proxy,
  inline bridge, one-arm modes; virtual servers and server pools
- Building **web protection profiles** — signature policies, ML anomaly
  detection, bot mitigation, DoS prevention, IP reputation, GeoIP
- Tuning **false positives** — reading attack logs, severity, exceptions,
  signature exclusions, learning mode
- **SSL** — inspection (client-side), offloading to server pools, certificate
  management (SNI, Let's Encrypt), HSTS
- **Server pool health** — HTTP/HTTPS/TCP health checks, session persistence,
  load-balancing methods
- **HA** — active-passive and active-active pairs, configuration sync,
  failover testing
- **Logging and analytics** — attack log fields, forwarding to FortiAnalyzer or
  syslog, dashboard metrics, incident triage
- **Automation** — CLI (FortiWeb shell), REST API endpoints, config backup,
  bulk policy changes, webhook/monitoring integration

## Reference Docs

| Document | Covers |
|----------|--------|
| [Architecture & Deployment](references/architecture-and-deployment.md) | Hardware/VM models, deployment modes, virtual servers, server pools, routing, VDOM |
| [Web Protection Profiles](references/web-protection-profiles.md) | Protection profile stack: signature, anomaly (ML), bot mitigation, DoS, access control |
| [Signatures & ML Tuning](references/signatures-and-ml-tuning.md) | Signature categories/severity, attack log fields, false-positive workflow, learning mode |
| [SSL & Certificates](references/ssl-and-certificates.md) | Client-side inspection, SNI, certificate sources, HSTS, TLS policy |
| [HA & Hardening](references/ha-and-hardening.md) | Active-passive/active-active, sync, failover drills, admin hardening, upgrade path |
| [Logs & Incident Triage](references/logs-and-incident-triage.md) | Attack log anatomy, forwarding, triage workflow, blocking decisions, reporting |
| [Automation & Best Practices](references/automation-and-best-practices.md) | CLI patterns, REST API endpoints, config backup, bulk changes, monitoring hooks, checklists |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [cli-server-policy.txt](examples/cli-server-policy.txt) | CLI walkthrough: virtual server, server pool with health check, HTTP→HTTPS redirect policy |
| [protection-profile-design.md](examples/protection-profile-design.md) | Layered protection profile design notes: signature + anomaly + bot mitigation order |
| [incident-triage-runbook.md](examples/incident-triage-runbook.md) | Step-by-step triage of an attack-log spike: classify, block, or tune |
| [false-positive-worksheet.md](examples/false-positive-worksheet.md) | False-positive decision worksheet with exception design |
| [api-automation.sh](examples/api-automation.sh) | curl REST API flows: login, config backup, policy export, health status |
