# Best Practices

## Naming and Structure

1. Test names describe behavior, not mechanics:
   `rejects expired session token` (good) vs `test_login_3` (no).
2. One behavior per test; if the name needs "and", it is two tests.
3. Test files mirror the code or the API surface they cover — discovery first,
   cleverness never.
4. Test code is production code: reviewed, formatted, refactored, no dead
   branches or commented-out bodies.

## Review Habits

- A PR that changes behavior adds or updates a test asserting the new behavior.
  "Tested manually" is not a review outcome for any path that recurs.
- Bug-fix PRs include a **regression test that fails before the fix** — the diff
  proves the test is real.
- Reviewers read tests first: they document the intended contract more precisely
  than the description.
- Reject tests that assert implementation internals (private calls, log strings,
  class names) unless that is the actual contract.

## Assertion Discipline

- Assert what matters to the user or the caller; internal state is not a
  contract.
- Negative assertions ("field absent", "not called") are as valuable as positive
  ones for security and privacy paths.
- Prefer exact assertions over loose ones (`status == 422` not `status >= 400`),
  but avoid over-fitting to incidental text.
- Every assertion message names the expectation: the failure should read as a
  sentence.

## Deletion Policy (the underrated one)

- Delete tests that no longer map to a behavior anyone relies on.
- Delete tests that have been quarantined past their deadline and cannot be
  fixed — a permanently skipped test is a lie in the report.
- Delete duplicate coverage aggressively: five tests asserting the same validator
  make the suite slower and hide the real one.
- Keep the suite small enough that the whole merge gate is under ten minutes; size
  is a feature.

## Ownership

- Every suite has a owning team; failures route to that team's channel, not to
  "whoever is on call".
- Quarantine entries carry an owner and a deadline in the file/annotation itself
  (`test.skip('owner: platform, expires: 2026-12-15')` style).
- Nightly failures get a ticket, not a chat message that scrolls away.

## Anti-Patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Sleeping to wait | Slow and still flaky |
| Retries as a strategy | Hides races; suite loses meaning |
| Shared admin credentials | Accidental destructive operations |
| Testing framework internals | Breaks on every refactor |
| Asserting log lines | Brittle and meaningless |
| One enormous E2E scenario | Fails for unrelated reasons, unreadable reports |
| Coverage as a target number | Fake tests to feed the metric |
| Tests against shared mutable staging | Cross-team interference |
| Quarantine without expiry | Silent coverage decay |
| Green-because-optional gates | Gates that do not gate |

## Metrics That Mean Something

- Merge-gating suite duration p95 and flake rate — both visible on a dashboard,
  both with an owner.
- Escaped defects per release: which bug would a test have caught? Feed back into
  the strategy list.
- Rerun rate per merge request: above a threshold, the pipeline is not trusted —
  fix flake before adding tests.
