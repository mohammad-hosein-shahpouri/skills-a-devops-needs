---
name: qa-automation
description: >
  Automated quality assurance for delivery pipelines — test strategy and the
  practical test pyramid, API contract and integration testing, browser
  automation with Playwright, deterministic test data and fixtures, database
  state isolation, flaky-test diagnosis and quarantine, CI wiring with quality
  gates, artifact collection, and reporting for GitLab CI/GitHub Actions
  pipelines.
---

# QA Automation

Design and run automated tests that gate delivery without becoming a second
production incident: strategy, API and browser layers, deterministic data,
flakiness control, and CI wiring.

## When to Use This Skill

Activate when the task involves:

- Designing a **test strategy** — what to automate, what to keep manual, layer
  boundaries
- Writing **API tests** — contract checks, auth flows, error-path coverage,
  schema validation
- Automating **browser flows** with Playwright — selectors, fixtures, tracing,
  parallelism
- **Test data** — fixtures, factories, seeding, database isolation per test run
- **Flaky tests** — detection, quarantine, root-cause taxonomy, retry policy
- **CI integration** — pipeline stages, caching, sharding, artifacts, quality
  gates that actually block
- **Quality reporting** — JUnit XML, coverage thresholds, failure triage
  ownership

## Reference Docs

| Document | Covers |
|----------|--------|
| [Strategy & Test Pyramid](references/strategy-and-test-pyramid.md) | Layer boundaries, cost/confidence trade-offs, what to automate first, coverage traps |
| [API Testing](references/api-testing.md) | Contract and behavior tests, auth, schema assertions, negative paths, setup/teardown |
| [Browser Testing with Playwright](references/browser-testing-playwright.md) | Config, selectors, fixtures, parallelism, tracing, network control |
| [Test Data & Fixtures](references/test-data-and-fixtures.md) | Factories, seeding, per-run isolation, cleanup, idempotency |
| [Flakiness & Reliability](references/flakiness-and-reliability.md) | Taxonomy, detection, quarantine policy, retries done right, timing discipline |
| [CI Wiring & Quality Gates](references/ci-wiring-and-quality-gates.md) | Stages, sharding, caching, artifacts, gates, reporting |
| [Best Practices](references/best-practices.md) | Naming, review habits, deletion policy, anti-patterns, metrics that matter |

## Example Configurations

| Example | Purpose |
|---------|---------|
| [playwright.config.ts](examples/playwright.config.ts) | Production Playwright config: projects, retries policy, tracing on failure, HTML+JUnit reporters |
| [api-smoke-tests.sh](examples/api-smoke-tests.sh) | curl-based API smoke suite with status/schema assertions and cleanup |
| [test-data-fixtures.sql](examples/test-data-fixtures.sql) | Deterministic seed data and per-run namespace isolation for PostgreSQL |
| [gitlab-ci-test-stage.yml](examples/gitlab-ci-test-stage.yml) | GitLab CI stages for lint, unit, API, browser with caching, artifacts and gates |
| [flaky-test-triage.md](examples/flaky-test-triage.md) | Triage worksheet and quarantine decision tree |
