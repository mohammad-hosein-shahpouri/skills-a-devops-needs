# Quarterly DR Drill Checklist

Goal: prove that restore paths work end-to-end and measure time-to-service.
Every item needs a pass/fail and an owner. Failures become remediation tickets.

## Pre-drill (week before)

- [ ] Scope agreed: which tiers/VMs are restored (gold tier minimum + one random silver VM)
- [ ] Isolated target capacity reserved (hosts, storage, network)
- [ ] Roles named: coordinator, restore operators, app validators, scribe
- [ ] Monitoring: verify NOC will not page on the isolated test VMs
- [ ] Backup health confirmed: last runs success, integrity checks pass
- [ ] Success criteria written down BEFORE starting (see scoring)

## Drill execution (the day)

- [ ] Declare start; record T0
- [ ] Restore DC/identity first (if in scope) — validate DNS/auth
- [ ] Instant recovery of one gold-tier app VM; measure time-to-service
- [ ] Whole-VM restore of one random silver VM; measure duration
- [ ] File-level restore sampling: 5 files across OS types; verify content
- [ ] Application-item restore (e.g. one DB to scratch instance); validate data
- [ ] Confirm immutable copy is reachable and unchangeable (attempt delete test)
- [ ] Config backup restore test: rebuild job definitions from config backup into scratch
- [ ] Record each step's wall-clock time; no pausing the clock for decisions
      (that lag is the real finding)

## Scoring (pass criteria)

| Item | Pass criterion |
|------|----------------|
| Identity restore | auth functional ≤ RTO target for tier |
| Gold app VM time-to-service | ≤ stated RTO |
| File-level restores | correct content, ≤ 30 min each |
| Immutable delete test | deletion refused |
| Config rebuild | jobs importable, definitions complete |
| Verification | app-level checks pass on every restored VM |

## Post-drill (week after)

- [ ] Report: T0-to-service per item, gaps, decisions slow-points
- [ ] Remediation tickets with owners and deadlines for every failed item
- [ ] Update runbooks with what was learned (restore order, credentials, gotchas)
- [ ] Rotate any credentials exposed during the drill
- [ ] Archive the report with the change-management system

## Common findings (expect these)

| Finding | Typical fix |
|---------|-------------|
| Decision latency dominates RTO | Pre-agreed restore order document, signed by app owners |
| Guest credentials expired | Credential rotation integrated with job tests |
| Instant recovery starved the repo | Throttle other jobs during drills (and incidents) |
| Immutable window shorter than incident response | Raise window |
| DR network config rediscovered from scratch | Document the isolated network in the runbook |
