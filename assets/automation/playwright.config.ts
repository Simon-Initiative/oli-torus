import { defineConfig } from '@playwright/test';

// Runtime credentials and account links must never enter traces or screenshots.
const protectSecrets = Boolean(
  process.env.CI || process.env.PLAYWRIGHT_SCENARIO_TOKEN || process.env.PLAYWRIGHT_CAPTCHA_TOKEN,
);

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  timeout: 60_000,
  expect: { timeout: 10_000 },
  testDir: './tests',
  /* Run tests in files in parallel */
  fullyParallel: false,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: true,
  /* Retry on CI only */
  retries: 1,
  /* Opt out of parallel tests on CI. */
  workers: 1,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [['html', { open: 'always' }]],
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* An unbounded locator action can silently eat the whole test timeout
       (a flaky CAPI iframe held getAttribute for 732s, MER-5674); every
       longer wait in the POs passes its own explicit timeout. */
    actionTimeout: 15_000,
    ignoreHTTPSErrors: true,
    /* Headless Chrome on macOS can keep a small real window under --start-maximized
       and send clicks on cross-site iframes outside it to the parent page. */
    launchOptions: {
      args: ['--start-maximized', '--ignore-certificate-errors', '--window-size=1920,1080'],
    },
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL,

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: protectSecrets ? 'off' : 'on',
    screenshot: protectSecrets ? 'off' : 'on',
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'Google Chrome',
      use: { channel: 'chrome', viewport: { width: 1920, height: 1080 } },
    },

    // {
    //   name: "firefox",
    //   use: {...devices["Desktop Firefox"] },
    // },

    // {
    //   name: "webkit",
    //   use: {...devices["Desktop Safari"] },
    // },

    /* Test against mobile viewports. */
    // {
    //   name: 'Mobile Chrome',
    //   use: {...devices['Pixel 5'] },
    // },
    // {
    //   name: 'Mobile Safari',
    //   use: {...devices['iPhone 12'] },
    // },

    /* Test against branded browsers. */
    // {
    //   name: 'Microsoft Edge',
    //   use: {...devices['Desktop Edge'], channel: 'msedge' },
    // },
    // {
    //   name: 'Google Chrome',
    //   use: {...devices['Desktop Chrome'], channel: 'chrome' },
    // },
  ],

  /* Run your local dev server before starting the tests */
  // webServer: {
  //   command: 'npm run start',
  //   url: 'http://127.0.0.1:3000',
  //   reuseExistingServer: true,
  // },
});
