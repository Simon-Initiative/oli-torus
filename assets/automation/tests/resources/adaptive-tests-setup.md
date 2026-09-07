# Playwright Adaptive Tests — Assets & Setup Guide

## Background

The adaptive lesson Playwright tests automate real student flows through private course content.
Because course archives and answer keys are instructional property that must never be committed to
this repository, tests load them at runtime from a private S3-compatible object-storage bucket.

## Architecture

### Why S3 and a server-side proxy?

Adaptive lesson tests run against real course content — the course archive and the answer key are
instructional property that must not be committed to the repository. To keep them private while
still making them available to the test suite, they are stored in a private S3 bucket and fetched
at runtime.

Tests do not access the bucket directly. Instead, they request assets through the Torus server's
`/test/assets/:key` endpoint, which proxies the request to S3 using server-side credentials. This
keeps bucket credentials off the test runner entirely — no engineer or CI agent ever needs S3
access, and Playwright traces (which capture all network traffic by default) cannot leak credentials.
A local MinIO instance is API-compatible with S3, so the same code path works in development.

### Server-side gating

The `/test/assets/*`, `/api/v1/automation_setup`, `/api/v1/automation_teardown`, and
scenario-seeding routes are **compiled out of the production router** unless
`enable_playwright_scenarios: true` is set at **compile time** (this is a value in the Mix config
file used to build the app, not a runtime environment variable). The default in `config/prod.exs`
is `false`. `config/ci_e2e.exs` already sets it to `true`.

Any environment intended to run nightly tests must be built with `enable_playwright_scenarios: true`
— either by using `MIX_ENV=ci_e2e` or by configuring a dedicated Mix environment. This is a
deployment decision to coordinate with DevOps.

## S3 key naming convention

All assets live inside a folder named `{section}-{page}`, where section and page names use
underscores in place of spaces. Files within the folder are always named `course.zip` and
`answers.json`.

```
{section_name_with_underscores}-{page_name_with_underscores}/
  course.zip
  answers.json   (only for tests that validate specific answers)
```

Example: `bio_beyond-designer_planet/course.zip`

---

## Setup

### Step 1 — Seed the S3 bucket

For each adaptive test below, the corresponding files must be uploaded to the Playwright assets
bucket under the exact S3 key path shown. The person responsible for managing the bucket (typically
DevOps) should upload the files using whatever access method they have available.

| Test file | S3 archive key | S3 answers key |
|-----------|---------------|----------------|
| `designer-planet-adaptive.spec.ts` | `bio_beyond-designer_planet/course.zip` | `bio_beyond-designer_planet/answers.json` |
| `our-blue-planet-adaptive.spec.ts` | `bio_beyond-our_blue_planet/course.zip` | `bio_beyond-our_blue_planet/answers.json` |
| `phases-of-the-moon.spec.ts` | `phases_of_the_moon-phases_of_the_moon/course.zip` | `phases_of_the_moon-phases_of_the_moon/answers.json` |
| `stellar-life-cycles-training.spec.ts` | `habitable_worlds-stellar_life_cycles_training/course.zip` | `habitable_worlds-stellar_life_cycles_training/answers.json` |
| `real-chem-greenhouse-molecules.spec.ts` | `real_chem-greenhouse_molecules/course.zip` | `real_chem-greenhouse_molecules/answers.json` |
| `real-chem-dazzling-d-orbitals.spec.ts` | `real_chem_ii-dazzling_d_orbitals/course.zip` | `real_chem_ii-dazzling_d_orbitals/answers.json` |
| `hw-brightness-assessment.spec.ts` | `habitable_worlds-brightness_assessment/course.zip` | _(none — no secret answers required)_ |

### Step 2 — Configure the Torus server

The following environment variables must be set on the Torus server for the target environment.

| Variable | Required | Notes |
|----------|----------|-------|
| `PLAYWRIGHT_ASSETS_BUCKET` | Yes | Name of the S3/MinIO bucket containing test assets |
| `PLAYWRIGHT_SCENARIO_TOKEN` | Yes | Shared secret you choose — must match the value set on the CI runner. No admin UI needed; set it as an env var on both sides. |
| `AWS_ACCESS_KEY_ID` | Yes (prod S3) | S3 access key. Use `AWS_S3_ACCESS_KEY_ID` to override with a dedicated key for the PW bucket, separate from other AWS credentials the server may already have. |
| `AWS_SECRET_ACCESS_KEY` | Yes (prod S3) | S3 secret key. Same override pattern via `AWS_S3_SECRET_ACCESS_KEY`. |
| `AWS_S3_SCHEME` | Dev/MinIO only | URL scheme for MinIO (default: `http`). Not needed for real S3. |
| `AWS_S3_HOST` | Dev/MinIO only | MinIO host (default: `localhost`). Not needed for real S3. |
| `AWS_S3_PORT` | Dev/MinIO only | MinIO port (default: `9000`). Not needed for real S3. |

### Step 3 — Create the automation API key

The adaptive tests authenticate course import requests using a dedicated API key with
`automation_setup_enabled: true`. To create one on the target Torus instance:

1. Log in as an admin and go to `/admin/api_keys`.
2. Enter a hint and click **Create** — Torus generates the key value.
3. Toggle `automation_setup_enabled` on for the newly created key.
4. Store the generated value as the `PLAYWRIGHT_AUTOMATION_API_KEY` CI secret (see Step 4).

Never reuse a key value that appears in the repository. `/api/v1/automation_setup` is reachable
in any environment where the flag is compiled in, and is gated solely by this key.

### Step 4 — Configure the CI environment

The nightly workflow reads its secrets and variables from the `nightly-ui` GitHub Actions
environment (repo Settings → Environments → nightly-ui). These must be populated by someone with
admin access to the repository — they are not set in the codebase.

| Variable | Type | Description |
|----------|------|-------------|
| `PLAYWRIGHT_BASE_URL` | Variable | URL of the target Torus server |
| `PLAYWRIGHT_SCENARIO_TOKEN` | Secret | Same value as the server-side token (Step 2) |
| `PLAYWRIGHT_AUTOMATION_API_KEY` | Secret | Key created in Step 3 |
| `PLAYWRIGHT_PARAMETER_CONFIG_URL` | Secret | URL to the Dot chatbot YAML config (see `nightly-ci.md`) |
| `CANVAS_UI_EMAIL` | Secret | Canvas test-account email (for LTI tests) |
| `CANVAS_UI_PASSWORD` | Secret | Canvas test-account password (for LTI tests) |

### Step 5 — Run the nightly suite

The nightly Playwright tests run automatically every day at 05:17 UTC via
`.github/workflows/nightly-playwright.yml`. The workflow can also be triggered manually from the
GitHub Actions UI at any time.

All tests tagged `@nightly` are included in the run. To run the nightly suite locally against a
configured environment:

```sh
npx playwright test --grep @nightly
```

---

## Known issues

1. **`enable_playwright_scenarios` is a compile-time flag, not a runtime env var** — any nightly
   environment must be built with it set to `true` in the Mix config. Coordinate with DevOps to
   confirm which `MIX_ENV` the nightly environment uses.

2. **Tags are plain text, not Playwright tag filters** — `@nightly` currently appears inside the
   test description string. This works with `--grep` today. Migrating to
   `test('...', { tag: '@nightly' }, ...)` is a future clean-up item that enables native UI
   filtering in Playwright, but it is not a blocker.
