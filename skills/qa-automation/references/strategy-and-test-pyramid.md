# Strategy & Test Pyramid

## The Trade-off Table (memorize this)

| Layer | Speed | Cost to maintain | Confidence it gives | Fails for |
|-------|-------|------------------|---------------------|-----------|
| Static analysis / lint | seconds | near zero | syntax, style, obvious bugs | runtime behavior |
| Unit | ms | low | logic correctness in isolation | integration wiring |
| Component / contract | 100ms–1s | medium | module boundaries, API shapes | full flows, real infra |
| API / integration | seconds | medium-high | real HTTP + DB + config | UI behavior |
| Browser end-to-end | 10–60s | high | user-visible flows, wiring | rare branches, edge states |
| Manual exploratory | minutes | human | unknown-unknowns, UX | regression coverage |

Automate bottom-up, but **write the E2E tests for the flows whose failure costs
money** — checkout, login, publishing, alert acknowledgement. Everything else
earns its place by bug history.

## What to Automate First (priority order)

1. Flows that broke in production in the last quarter.
2. Money/auth/security paths (payments, permissions, tokens).
3. High-change areas — recent hot files in Git; they will break again.
4. Contract boundaries between services (schema drift is silent and expensive).
5. Data migrations and idempotency checks.

Do not automate: visual aesthetics, one-off campaign pages, third-party vendor
UIs you do not control, anything a human must judge ("does this look right").

## Coverage: Use It as a Map, Not a Target

- Line coverage tells you what code ran, not what was verified. A 95% coverage
  suite with no assertions on the results verifies nothing.
- Prefer **risk coverage**: for each critical capability, name the test that
  would fail if it broke. Missing names are the real gaps.
- Coverage thresholds in CI are useful as **ratchets** (never let it drop), not
  as goals to maximize.
- Track **mutation-style questions**: if I broke this line intentionally, would a
  test fail? Three or four of those per sprint catch fake coverage.

## Layer Boundaries in Practice

```text
        ┌─────────────────────────┐
        │  E2E browser (few)      │  critical user journeys
        ├─────────────────────────┤
        │  API / integration      │  every endpoint, happy + error
        ├─────────────────────────┤
        │  Contract / component   │  service boundaries, schemas
        ├─────────────────────────┤
        │  Unit (many)            │  domain logic, parsers, validators
        └─────────────────────────┘
```

- A bug that only a browser test catches indicates a **missing API-level
  assertion** — fix the gap, not by adding more browser tests.
- A browser test that covers ten checks should be split: API checks at API layer,
  one visual flow for the wiring.
- Unit tests belong next to the code and run on every save; integration tests run
  per push; E2E runs per merge request and nightly.

## Test Case Design

- One behavior per test; the name states the behavior (`rejects expired token`,
  not `test login 2`).
- Arrange / Act / Assert visibly separated.
- Test the **contract and observable behavior**, not implementation details —
  implementation-coupled tests break on refactors for no signal.
- Every test is independent: no ordering, no shared mutable state, no reliance on
  "the previous test created the user".
- Error paths get equal treatment: 4xx bodies, timeouts, partial failures,
  idempotency of retries.

## Definition of Done for a Feature

- Happy path covered at the right layer.
- At least one negative path for each input boundary.
- Authorization verified for the roles that matter (missing authz checks are the
  most common production security bug).
- Data cleanup verified — the test leaves no residue that breaks the next run.
- CI runs it on every merge request, not just nightly.

## Metrics That Matter

| Metric | Why |
|--------|-----|
| Test suite duration p50/p95 | Developer feedback loop survival |
| Flake rate (failures without code change) | Trust in red builds |
| Escaped defects per release | Whether the suite catches what matters |
| Time to diagnose a red build | Cost per failure |
| PRs merged with failing optional checks | Whether gates are real |

A suite that is slow and flaky is worse than no suite: it trains people to ignore
red builds. Prune aggressively — deleted tests are a maintenance win when they no
longer earn their cost.
