Nightly Playwright CI expects these environment variables:

- `PLAYWRIGHT_BASE_URL`
- `PLAYWRIGHT_SCENARIO_TOKEN`
- `CANVAS_BASE_URL`
- `CANVAS_API_TOKEN`
- `CANVAS_ACCOUNT_ID`
- `CANVAS_INSTRUCTOR_USER_ID`
- `CANVAS_INSTRUCTOR_EMAIL`
- `CANVAS_INSTRUCTOR_PASSWORD`

It can also use this optional environment variable:

- `CANVAS_LTI_TOOL_NAME` (defaults to `OLI Torus (tokamak)`)

For GitHub Actions, store them as environment secrets on the `nightly-ui` environment, then reference that environment from `.github/workflows/nightly-playwright.yml`.

Keep these credentials scoped to dedicated low-privilege test accounts.
