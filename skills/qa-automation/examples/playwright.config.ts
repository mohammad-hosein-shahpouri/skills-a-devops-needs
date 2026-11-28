import { defineConfig, devices } from '@playwright/test';

// Production-oriented Playwright configuration.
// Environment variables: BASE_URL, CI, PW_WORKERS, PW_RETRIES.

export default defineConfig({
  testDir: './tests/e2e',
  outputDir: 'test-results',
  timeout: 60_000,
  expect: { timeout: 10_000 },

  fullyParallel: true,

  // Races and shared state are the top flake sources; forbid accidental
  // test.only from skipping the rest of the suite in CI.
  forbidOnly: !!process.env.CI,

  // One retry absorbs runner noise. More hides real races: fix, don't retry.
  retries: process.env.CI ? 1 : 0,

  // The driver is CPU-bound; over-parallelising causes flake on small runners.
  workers: process.env.CI ? '50%' : undefined,

  reporter: process.env.CI
    ? [
        ['junit', { outputFile: 'test-results/junit.xml' }],
        ['html', { open: 'never' }],
        ['list'],
      ]
    : [['html', { open: 'on-failure' }], ['list']],

  use: {
    baseURL: process.env.BASE_URL ?? 'http://127.0.0.1:8080',
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    locale: 'en-US',
    timezoneId: 'UTC',
    testIdAttribute: 'data-testid',
  },

  projects: [
    // Fast critical journeys for merge requests.
    { name: 'smoke', testMatch: /.*\.smoke\.spec\.ts/ },
    // Full browser matrix for nightly runs.
    { name: 'chromium', testIgnore: /.*\.smoke\.spec\.ts/, use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', testIgnore: /.*\.smoke\.spec\.ts/, use: { ...devices['Desktop Firefox'] } },
  ],

  // Reuse a running dev server locally, start a fresh one in CI.
  webServer: process.env.BASE_URL
    ? undefined
    : {
        command: 'npm run serve:test',
        url: 'http://127.0.0.1:8080',
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
});

// Notes:
// - Fail the run on unexpected API 5xx by adding listeners in a shared fixture
//   (page.on('response')) rather than asserting around them.
// - For sharding across CI jobs: npx playwright test --shard=<i>/<n>.
// - Trace artifacts are the primary flake diagnostic: keep them 7-14 days.
