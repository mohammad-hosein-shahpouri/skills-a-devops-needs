# Flaky Test Triage Worksheet

Fill this in when a test fails without a code change. Goal: classify in under
two minutes, then act per the decision tree.

## Worksheet

| Field | Value |
|-------|-------|
| Test name | |
| Run URL / job id | |
| Commit SHA (same as last green?) | |
| Failed once or repeated? | |
| Passed on rerun? | |
| Trace / video artifact link | |
| Environment (CI job, local, runner type) | |
| Suspected category (see taxonomy) | |
| Owner | |
| Quarantine entry (y/n) + expiry | |

## Decision Tree

```text
Failed without code change?
├─ No  → not flake. Review the change; the test did its job.
└─ Yes
   ├─ Rerun passed, no artifact signal
   │   ├─ Runner/infra noise (OOM, DNS, image pull) → retries:1 absorbs it;
   │   │   if it recurs weekly, fix the environment contract
   │   └─ Unclear → collect the trace; do NOT quarantine yet (need evidence)
   ├─ Rerun failed the same way
   │   ├─ Product race (real async bug) → bug ticket, severity per path
   │   ├─ Test bug (bad wait/selector/ordering) → fix test in the same PR
   │   └─ Shared state contamination → isolate data; then rerun suite twice
   └─ Intermittent timing signature (screenshots mid-animation, timeout at Ns)
       ├─ Replace sleeps with state-based waits
       ├─ Disable animations in test mode
       └─ Still failing? Quarantine with owner + 2-week expiry, nightly report
```

## Category Cheat Sheet

| Symptom in trace | Likely category | First fix |
|------------------|-----------------|-----------|
| Element found but assertion read stale value | Assertion timing | Use web-first assertion |
| 401 around midnight/expiry | Time | Freeze clock, seed tokens with explicit expiry |
| Works alone, fails in parallel | Shared state | Namespace data per worker/run |
| HTTP 502/503 from backend | Network/env | Stub third party; assert readiness before start |
| Runner killed, no test output | Resource | Bound workers; memory limits; artifact cleanup |
| Passes locally, fails in CI only | Environment drift | Pin images, TZ/locale, tool versions |

## Quarantine Rules (restated in operational terms)

1. Annotation must include owner and expiry date in the code:
   `test.skip('owner: platform; expires: 2026-12-15; issue: QA-1234')`.
2. Quarantined test still runs in the nightly full suite and reports status.
3. Expired entry: fix or delete in the next review — no third option.
4. Critical paths (auth, payments, data integrity) cannot be quarantined;
   escalate as a product bug instead.

## Post-Incident Bookkeeping

- Add the failing scenario to the strategy's "automate first" list if it was
  missed by coverage.
- Update the flake log; if the same test appears twice in a month, it gets a
  named owner and a root-cause ticket.
- If the cause was an environment contract gap, fix the pipeline definition —
  not just the test.
