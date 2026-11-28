# Flakiness & Reliability

## Why Flaky Tests Are Worse Than Missing Tests

A suite that fails randomly teaches the team to re-run until green. That habit
erases the value of every real failure — the one that would have caught a release
bug. Treat flake as a defect with the same priority as a product bug.

## Taxonomy: Name the Cause Before Fixing

| Category | Signature | Fix |
|----------|-----------|-----|
| **Race condition** | Fails under parallel load, passes alone | State-based waits; per-worker data; remove timing assumptions |
| **Shared state** | Order-dependent failures, contamination | Isolate data, unique namespaces, cleanup |
| **Environment drift** | Fails only in CI or only on a specific runner | Pin versions/images, resource limits, timezone/locale, clock |
| **Time** | Fails near midnight, month boundaries, DST, token expiry | Frozen clocks, injectable time, UTC everywhere |
| **Network** | Timeout signatures, 5xx from dependencies | Retries only at HTTP client for idempotent calls, stub third parties |
| **Resource** | Runner OOM, disk full, port conflicts | Bounded workers, ephemeral ports, artifact cleanup |
| **Assertion timing** | Screenshot/element captured mid-animation | Wait for stable state, disable animations in test mode |
| **External dependency** | Third-party sandbox outage | Recorded contracts, local stubs |
| **Test bug** | Wrong expectation, wrong selector | Fix the test; do not "retry it away" |

## Detection

- Track **per-test failure counts with no code change** in the window — CI
  dashboards or JUnit ingestion give this; eyeballing is not a policy.
- Mark suspicious tests at the moment of the second unexplained failure, not after
  ten.
- Keep a **flake log** (one row per failure: test, run URL, trace, suspected
  category, owner). The log is what turns anecdote into a burn-down.

## Quarantine Policy (the part teams get wrong)

1. **Quarantine is a timer, not a destination.** A quarantined test has an owner
   and a deadline (two weeks is a reasonable default).
2. Quarantined tests do **not** block merges, but they must still run nightly and
   report their status — silent quarantine is deletion with extra steps.
3. Expired quarantine = delete the test or fix it. The decision is made in the
   review, not postponed.
4. Never quarantine auth/payment/security-path tests — a flaky critical test means
   the underlying behavior has a real race, and shipping is the accident.

## Retries: One, and Only One

- `retries: 1` in CI absorbs infra noise (runner hiccup, transient DNS).
- `retries: 3` masks races: the suite becomes a slot machine and the green light
  loses meaning.
- Retries must be **visible**: report `expectedStatus`/`flaky` counts and alert
  when a test flips more than twice a week.
- Never retry locally by hand as a workflow — that is the habit this whole
  document exists to prevent.

## Determinism Techniques

| Problem | Technique |
|---------|-----------|
| Async UI | Web-first assertions, wait for network/state, not sleeps |
| Clock | Freeze/inject clock; test expiry with controlled time |
| Randomness | Seed it; assert on ranges/properties, not exact values |
| Locale/timezone | Force UTC + explicit locale in test config |
| Animations | Disable via media query or test-mode flag |
| Port collisions | Port `0` (ephemeral) or per-worker allocation |
| Database | Fresh container or transactional rollback per test |
| Ordering | Assert sets, not list order, unless order is the contract |
| Rate limits | Dedicated test tenant/quota in the environment |

## Metrics to Manage

- **Suite flake rate** = failures without code change / total runs. Target under
  2% for merge-gating suites.
- **Quarantine age** — p50 and oldest entry; anything above the deadline is a
  process failure.
- **Time to green** after a red build — flake diagnosis cost.
- **Rerun count per merge** — if reruns are routine, the suite is not gating
  anything.

See [flaky-test-triage.md](../examples/flaky-test-triage.md) for the worksheet
used to classify a failure in under two minutes.
