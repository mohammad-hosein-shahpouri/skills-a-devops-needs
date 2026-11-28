# CI Wiring & Quality Gates

## Pipeline Shape

```text
lint (seconds) → unit (1-2 min) → build image (2-5 min) → api tests (2-4 min)
                                              └→ e2e smoke (3-6 min) → deploy staging
nightly: e2e full, load smoke, deeper integration
```

Principles:

1. **Fastest failure first** — lint and unit before image build; nothing expensive
   runs before cheap checks pass.
2. **Parallel where independent** — api and e2e can run concurrently after the
   image exists.
3. **Same artifact everywhere** — build the image once, run tests against that
   exact digest in every stage.
4. **Ephemeral environments** — compose/testcontainers per job, not a shared
   staging for merge requests.

## Caching What Is Safe

| Cache | Key | Risk |
|-------|-----|------|
| Dependency install (`node_modules`, pip wheels, Go modules) | lockfile hash | Poisoned cache if keyed loosely |
| Playwright browsers | playwright version | Large but stable |
| Image layers | Dockerfile + lockfiles | Depends on registry cache |

Never cache: test results, databases, secrets, anything mutable across code
versions without the lockfile in the key.

## Artifacts on Failure (mandatory)

- Test reports: JUnit XML (machine gate), HTML report (human triage)
- Playwright traces/videos/screenshots on failure (retention 7-14 days)
- Service logs from the ephemeral environment for the failed run
- The exact image digest and commit SHA in the report header

Artifacts are the difference between a five-minute diagnosis and a rerun-roulette.

## Quality Gates That Actually Block

Gates should be few, fast, and unambiguous:

| Gate | Blocks merge when |
|------|-------------------|
| Lint + type check | Any error |
| Unit suite | Any failure |
| API smoke | Any failure |
| E2E smoke (critical journeys only) | Any failure |
| Coverage ratchet | Coverage drops below previous ref |
| Security scan (deps) | New high/critical advisory with fix available |

Do **not** gate on: full nightly E2E (too slow), performance tests (environment
noise), flaky suites in quarantine (they run nightly and report instead).

Mark required checks explicitly in the forge (GitLab `allow_failure: false`,
GitHub branch protection) — an "optional green" check trains people to ignore red.

## Sharding and Duration Control

- Playwright: `--shard=1/4` per CI job; balance shards by historical duration
  (split spec files, not test lines).
- API suites: shard by endpoint family; keep the whole merge-gating path under
  ten minutes.
- Measure p95 durations per stage; a stage that doubles in a month is a
  maintenance signal, not a badge.

## Environment Contracts

- Pin base images by digest, not floating tags.
- Assert the environment is the expected one before running destructive tests
  (`HOST`/`ENV_NAME` checks; see
  [test-data-fixtures.sql](../examples/test-data-fixtures.sql) for a database
  guard example).
- Secrets come from the CI secret store; test jobs run with least privilege
  tokens limited to the ephemeral environment scope.

## Reporting Into the Team's Tools

- JUnit → CI test tab (per-test history and flake counts).
- HTML report artifact attached to the pipeline/PR for human review.
- Slack/chat notification **only for main-branch failures** — per-MR failure
  notifications belong to the MR page, not the channel.
- Post the failed test name and artifact link in the MR comment; the failing
  developer should not have to hunt.

Full example pipeline:
[gitlab-ci-test-stage.yml](../examples/gitlab-ci-test-stage.yml).

## Common Wiring Mistakes

| Mistake | Consequence |
|---------|-------------|
| Tests run after deploy to shared staging | Contaminated, slow, flaky |
| Cache key without lockfile | Stale deps, mystery failures |
| Required check that is flaky | Team bypasses gates permanently |
| Nightly-only critical tests | Breakage discovered a day late |
| No JUnit output | No history, no flake tracking |
| Credentials with admin scope in tests | Accidental destructive runs |
| Parallel stages sharing a database | Cross-stage interference |
