# SureBackup & Verification

## The Idea

A backup you have never restored is a hope. SureBackup **automatically boots VMs
directly from backup points in an isolated virtual lab** and runs scripted
application tests — turning "we have backups" into "backups verified 0 errors".

## Virtual Lab

- Isolated network on a hypervisor host: proxy appliance bridges a private
  masqueraded network; no production traffic can leak.
- Masquerade IP mapping lets the test network reuse production IP plans.
- One virtual lab per hypervisor cluster is usually enough; keep the design in
  the config repo.

## Application Groups & Test Scripts

- **Application group** = set of VMs tested together (e.g. DC + SQL + app server)
  so dependencies boot in order.
- Roles (DNS, Domain Controller, SQL) come with built-in heartbeat/application
  tests; add custom scripts for app-specific health (HTTP 200, port checks).
- Test script exit code decides pass/fail — write real health checks, not
  `exit 0`.

## SureBackup Job

- Runs on schedule (weekly minimum for critical groups).
- Boots VMs from chosen restore points, runs role tests + custom scripts,
  reports Verified/Failed per VM, powers off.
- **Results are alarms**: a SureBackup failure means the restore point is bad —
  fix before you need it, and check whether recent points are also affected.

## Scheduled Restore Testing Beyond SureBackup

| Drill | Frequency | Scope |
|-------|-----------|-------|
| SureBackup for critical app groups | Weekly | Automated |
| Random whole-VM restore to an isolated host | Monthly | Human-run |
| File-level restore sampling | Monthly | Human-run |
| Full DR scenario | Quarterly/Annual | Tabletop + execution |

## Interpreting Failures

| Failure | Likely cause |
|---------|--------------|
| Heartbeat/test timeout | Guest boot too slow — increase max boot time; or guest broken |
| Application test failed | Service config in restored point; check app logs |
| Restore point mount failure | Repository issue or corrupted chain — run integrity check |
| Role test (DC) fails on DNS | Virtual lab masquerade misconfig |

## Zero Errors Culture

- Verification failures enter the same triage pipeline as production alerts:
  owner, diagnosis, fix, verification.
- Monthly report: % restore points verified, exceptions, mean time to verify.
- The last digit of 3-2-1-1-0 ("zero errors") is a process, not a checkbox.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| SureBackup running but failures ignored | Theatre |
| Virtual lab on the biggest host | Surprises the host at boot storms |
| Custom scripts that always exit 0 | No real verification |
| Only testing DC VMs | App-tier restore gaps hidden |
| Skipping drills because "SureBackup passes" | Organization not practiced |
