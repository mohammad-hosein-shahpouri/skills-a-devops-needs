# Restore Runbook

Decision-first runbook. Ask: what does the BUSINESS need — the VM, the file, the
data, or proof?

## Decision table

| Situation | Method | Go to |
|-----------|--------|-------|
| VM deleted/corrupt, minutes acceptable | Whole-VM restore | A |
| Critical VM, need service NOW | Instant VM Recovery | B |
| One file/folder lost | File-level restore | C |
| DB corrupted logically (bad data) | App-item / point-in-time | D |
| Ransomware event | Full incident restore flow | E |

## A) Whole-VM restore

1. Pick restore point **before** the incident window.
2. Target: original location (overwrite) ONLY if the cause is understood and
   contained; otherwise restore as new VM name first.
3. Network: keep disconnected until verified if security-related.
4. Power on, application health check (not just OS up).
5. Swap DNS/comms when verified; retire the broken instance as evidence if
   forensics needs it.

## B) Instant VM recovery

1. Choose point; target host/resource pool with capacity headroom.
2. Networking decision: production network (confirmed contained) or isolated
   test network (investigating).
3. Boot from backup; verify application; announce interim state.
4. Migrate to production storage (storage vMotion) when stable.
5. Watch repository I/O during instant recovery — pause heavy jobs if latency
   climbs.

## C) File-level restore

1. Choose point; mount via FLR (guest credentials) or multi-OS mount.
2. Restore to alternate path; compare; then place into production by the app's
   own mechanism when safe.
3. For many files: mount and copy in the guest instead of per-file GUI.

## D) Application-item restore

1. Verify log backup chain health before promising point-in-time.
2. Restore DB to a scratch instance first when possible; validate data.
3. Swap into production with the app stopped; re-run app smoke checks.

## E) Ransomware incident restore flow

1. **Contain first**: isolate affected VMs; stop backup jobs that would snapshot
   infected machines further.
2. Identify clean point-in-time from monitoring/incident timeline.
3. Preserve evidence: keep infected copies; do not delete.
4. Restore order: identity (DC) → core infra → tier-1 apps → the rest.
5. Use the immutable copy — assume the primary repo/credentials may be
   compromised.
6. After each service: app health check + security validation before it serves.
7. Record timings for the post-incident report: time to decision, time to
   service, per tier.

## Verification (every restore)

- Application-level checks pass (not just power state)
- Data spot checks (recent records present)
- Integration points healthy (DNS, auth, queues)
- Note in the restore log: VM, point, duration, verifier, result

## After the incident

- Post-incident review: was the RPO/RTO honored? what broke the plan?
- If the backup system itself was attacked: rotate all credentials, re-verify
  immutability settings, review [immutability and ransomware defense](../references/immutability-and-ransomware-defense.md).
