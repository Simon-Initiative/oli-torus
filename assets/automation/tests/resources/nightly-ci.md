Nightly Playwright CI expects these environment variables:

- `CANVAS_UI_EMAIL`
- `CANVAS_UI_PASSWORD`

For GitHub Actions, store them as environment secrets on the `nightly-ui` environment, then reference that environment from `.github/workflows/nightly-playwright.yml`.

Keep these credentials scoped to dedicated low-privilege test accounts.
