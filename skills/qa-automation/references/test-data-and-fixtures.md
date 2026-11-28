# Test Data & Fixtures

## The Core Principle

A test must create the exact state it needs and must not depend on leftovers from
another test. Everything else is variation on this theme.

## Isolation Levels

| Level | Isolation | Cost | Use when |
|-------|-----------|------|----------|
| Fresh container + database per job | Total | Seconds of startup | CI pipelines (default choice) |
| Transaction rollback per test | Total for DB | Fast | Integration tests with direct DB control |
| Run-scoped namespace (`run_id` prefix) | High | Low | Shared environment, no cleanup race |
| Seeded snapshot database | Medium | Low | Complex fixtures shared by many tests |
| Shared fixed test accounts | None | Zero | Avoid — parallel tests interfere |

## Factories, Not Fixtures Files

Create entities through functions with sane defaults and explicit overrides:

```python
def make_order(*, status="pending", total_cents=1000, customer=None):
    customer = customer or make_customer()
    return api.post("/orders", json={
        "customer_id": customer["id"], "status": status, "total_cents": total_cents,
    }).json()
```

Why factories beat static fixtures:

- Each test overrides only the field it cares about — intent is visible.
- No hidden coupling between tests via a shared JSON blob.
- Defaults encode valid states; invalid states are explicit (and that is a
  feature).

## Seeding Determinism

- **Fixed seeds for random generators**, frozen timestamps (`2026-01-01T00:00:00Z`),
  and stable ids (`order-001`, not UUIDs) whenever the test logic depends on them.
- IDs that the test does not assert can be random — uniqueness prevents collisions
  but harms debuggability when logged. Prefer readable prefixes:
  `qa-<run_id>-order-<n>`.
- Characterize time zones and locale: seed times in UTC, test display formatting
  separately.

## Database-Level Isolation

Transaction rollback pattern (works for most ORM integration tests):

```python
@pytest.fixture
def db_session(engine):
    conn = engine.connect()
    tx = conn.begin()
    session = Session(bind=conn)
    yield session
    session.close()
    tx.rollback()      # nothing persists
    conn.close()
```

Idempotent seed SQL for shared databases (see
[test-data-fixtures.sql](../examples/test-data-fixtures.sql)):

```sql
INSERT INTO customers (id, name)
VALUES ('qa-seed-customer', 'QA Seed')
ON CONFLICT (id) DO NOTHING;
```

Rules:

- Seed scripts are **versioned and idempotent**; rerun must not duplicate rows.
- Destructive tests require a dedicated database whose name is checked
  (`IF current_database() NOT LIKE '%test%' THEN RAISE`).
- Truncation order respects foreign keys; prefer `TRUNCATE ... CASCADE` inside
  test databases only.

## Files, Queues, and External Services

- Uploads: generate files in the test (small, deterministic content), never commit
  binary fixtures unless the format is the thing under test (then label them
  clearly and keep them tiny).
- Queues: use a per-run topic/queue name; drain at the end; or run a disposable
  broker in the CI job.
- Third-party APIs: contract-stub them (recorded responses or explicit fakes) —
  real calls make the suite depend on someone else's uptime and quota.

## Cleanup Discipline

- Cleanup belongs in teardown with `try/finally` semantics — a failed assertion
  must still clean up.
- Prefer deleting by created ids, not by blanket patterns; a cleanup job that runs
  `DELETE FROM orders` in a shared environment is a future incident.
- Sweeper jobs for orphaned `qa-*` data are a safety net, not a primary cleanup
  strategy.

## Privacy and Safety

- **Never** copy production data into test environments without scrubbing
  (names, emails, phones, tokens, addresses); prefer generated data.
- Test suites must not log secrets: redact auth headers in request logging.
- Test credentials live in CI secret stores and are scoped/expiring.

## Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Shared fixture database edited by hand | Versioned, idempotent seeds |
| Tests depending on row ids seen once | Create inside the test |
| Random data without namespace | `run_id` prefix |
| Deleting all rows in teardown | Delete only created ids |
| Real production data in staging | Generated data or scrubbed snapshot |
| Config toggles left changed by a test | Restore in teardown, verify in a smoke check |
