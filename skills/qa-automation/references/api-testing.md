# API Testing

## What API Tests Must Cover

For every endpoint, the minimum honest set:

1. **Happy path** — valid input, expected status, expected body shape.
2. **Validation errors** — missing required field, wrong type, out-of-range →
   the documented 4xx code and error envelope.
3. **Auth boundary** — no token (401), wrong scope/role (403), expired token (401),
   and a positive control with the minimum sufficient role.
4. **Not found / conflict** — resource absent (404), duplicate create (409),
   state-machine violations (422).
5. **Idempotency** — retried POST/PUT yields the same end state (where promised).
6. **Pagination/filtering contract** — limits, cursors, sort order stability.
7. **Schema conformance** — response matches the published/OpenAPI contract.

Cross-cutting: content type handling, rate-limit responses (429 + headers),
request size limits, and correlation-id echoing if the service promises it.

## Structure: Setup, Act, Assert, Cleanup

```bash
# Each test owns its data and its cleanup — no global fixture soup.
token="$(create_token_for 'qa-reader')"
id="$(create_widget "$token" "widget-$RANDOM")"
# act + assert
curl -fsS -H "Authorization: Bearer $token" "$BASE/widgets/$id" | check_json '.name'
# cleanup (even on failure — trap)
delete_widget "$token" "$id"
```

Rules:

- A test that crashes before cleanup must not poison later tests: use traps/try
  blocks and unique namespacing (`widget-$RUN_ID-$N`).
- Never depend on a pre-existing database row unless the fixture is seeded and
  versioned.
- Auth tokens: create per run with least privilege; do not share a superuser
  token across the whole suite.

## Assertions Worth Writing

| Assertion | Catches |
|-----------|---------|
| Status code | routing/auth regressions |
| Body schema (types, required keys) | silent contract drift |
| Specific field values | logic errors |
| Error code string (not just status) | error-handling regressions |
| Headers (content-type, cache-control, rate-limit) | proxy/gateway misconfig |
| Absence of sensitive fields in responses | accidental data leak (important) |
| Timing sanity (under N seconds) | accidental N+1 or blocking calls |

Schema validation belongs in every suite: catch drift where the producer is
consumed, not in production. Generate schemas from OpenAPI where available and
fail the build when the contract and implementation disagree.

## Test Environment Discipline

- **One API instance per CI job** (container) with a throwaway database — the
  strongest isolation; eliminates cross-job interference.
- If a shared environment is unavoidable: per-run namespaces, unique prefixes,
  and scheduled cleanup; never run destructive tests against shared data.
- Seed data through the same API the tests use when testing behavior; seed
  directly in the database only to set up impossible states.
- Freeze time or use injectable clocks for expiry/token-window tests.

## Performance and Load Sanity

Smoke suite is not a load test. But every API suite should include:

- **Latency guardrails** on critical endpoints (`< 500ms` p95 locally) to catch
  accidental synchronous work.
- **Payload size sanity** — large responses catch missing pagination.
- For real load, separate tooling and environment — see the dedicated load
  testing practice; never run load against shared staging without coordination.

## Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| One giant "test everything" script | One file/test per endpoint family |
| Asserting only status 200 | Assert body, schema, side effects |
| Shared admin token | Per-test least-privilege tokens |
| Tests that depend on order | Independent setup per test |
| No cleanup | Trap-based cleanup + unique namespaces |
| Ignoring 401/403 paths | Explicit auth matrix tests |
| Hardcoded IDs from staging | Create resources within the test |
| Quietly skipping failures (`|| true`) | Fail loudly; quarantine explicitly instead |

## Reporting

- Emit JUnit XML so CI shows per-test results (`curl` scripts can write simple
  XML; frameworks do it natively).
- Include the request id / correlation id in failure messages — it makes
  server-side log lookup a one-step action.
- Keep the smoke suite under two minutes; long suites get skipped by humans.
