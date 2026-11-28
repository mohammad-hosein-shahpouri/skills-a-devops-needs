# Browser Testing with Playwright

## Configuration That Survives CI

Key decisions (full example in
[playwright.config.ts](../examples/playwright.config.ts)):

| Setting | Recommendation | Why |
|---------|----------------|-----|
| `workers` | `CI ? 50% : undefined` | CPU-bound driver; oversubscription causes flake |
| `retries` | `CI ? 1 : 0` | One retry catches infra noise; more hides real races |
| `trace` | `retain-on-failure` | Evidence without storage bloat |
| `video` | `retain-on-failure` | Same |
| `screenshot` | `only-on-failure` | Cheap and decisive for layout bugs |
| `fullyParallel` | `true` | Independent tests by design |
| `use.baseURL` | from env | Same suite for any environment |
| `reporter` | `html` + `junit` in CI | Human artifact + machine gate |

## Selectors: The Hierarchy

1. `getByRole('button', { name: 'Save' })` — accessibility-anchored, survives
   markup refactors.
2. `getByLabel` / `getByPlaceholder` / `getByText` for form controls and content.
3. `getByTestId('order-summary')` — explicit contract between app and tests; add
   `data-testid` deliberately.
4. CSS/XPath — last resort; brittle and slow.

Never select by generated class names, DOM position, or auto-generated ids.

## Waiting: Auto-waiting Is the Rule

```ts
await page.getByRole('button', { name: 'Submit' }).click();
await expect(page.getByText('Saved')).toBeVisible();
```

- Web-first assertions (`expect(locator)...`) retry automatically; they are the
  correct waiting primitive.
- `page.waitForTimeout(2000)` is a defect: it either sleeps too long (slow suite)
  or too short (flake). Use state-based waits only.
- For network-coupled UI: `await page.waitForResponse(r => r.url().includes('/api/orders') && r.ok())`
  before asserting the rendered result.

## Network Control

```ts
// deterministic backend responses for UI-only tests
await page.route('**/api/pricing', route =>
  route.fulfill({ status: 200, contentType: 'application/json',
                  body: JSON.stringify({ total: 42 }) }));
```

- Mock the third parties you do not own; never mock the system under test in
  E2E — that is what component tests are for.
- Fail fast on unexpected API errors: `page.on('console')` and `page.on('response')`
  hooks that fail on 5xx keep tests from silently passing with broken backends.

## Fixtures: Setup Once, Share Safely

```ts
export const test = base.extend<{ authedPage: Page }>({
  authedPage: async ({ page, request }, use) => {
    const res = await request.post('/api/session', { data: credentials });
    const { token } = await res.json();
    await page.addInitScript(t => localStorage.setItem('token', t), token);
    await use(page);
  },
});
```

- Fixtures create state per test; `test.beforeAll` sharing is only safe for
  read-only data.
- Prefer API-level setup (fast, stable) over driving the UI to reach the start
  state.
- Clean up created entities in fixtures' teardown for shared environments; on
  disposable containers cleanup is unnecessary.

## Parallelism and Sharding

- Tests must be order-independent and data-namespaced per worker:
  `RUN_ID = process.env.CI_JOB_ID ?? Date.now()`.
- For large suites, shard by `--shard=i/n` across CI jobs; measure shard balance
  (slowest shard defines pipeline duration).
- Keep a small `smoke` project (critical journeys) for merge requests and the full
  suite nightly.

## Debugging Failures

```bash
npx playwright test --ui            # interactive
npx playwright show-trace trace.zip  # post-mortem, CI artifact
npx playwright test --debug         # step through
```

Trace viewer gives DOM snapshots, network log, console — the single most
effective flake diagnostic; downloading the trace artifact and sharing the file
is a complete bug report.

## Anti-Patterns

| Anti-pattern | Consequence |
|--------------|-------------|
| `waitForTimeout` everywhere | Slow, still flaky |
| CSS selectors on generated classes | Break on every build |
| UI-driven setup for start state | Minutes per test, cascading failures |
| Shared mutable test account | Parallel tests interfere |
| `test.only` left in code | Silent coverage collapse |
| Testing third-party UI | Your suite breaks on their releases |
| Assertions without waiting (`expect(await textContent())`) | Race flake |
| Screenshots as pass criteria on pixel diff only | Constant noise for real apps |
