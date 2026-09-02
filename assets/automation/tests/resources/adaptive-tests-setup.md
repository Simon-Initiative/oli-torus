# Playwright Adaptive Tests — Assets & Setup Guide

## Background

The adaptive lesson Playwright tests automate real student flows through private course content.
Because course archives and answer keys are instructional property that must never be committed to
this repository, tests load them at runtime from a private S3-compatible object-storage bucket.

## Architecture

### Why S3 and a server-side proxy?

Tests never access the bucket directly. Instead:

1. The test runner requests an asset through the Torus server's `/test/assets/:key` endpoint.
   For example: `GET https://torus-server/test/assets/phases_of_the_moon-phases_of_the_moon/course.zip`
2. The server validates the `x-playwright-scenario-token` header, then fetches the object from S3
   using server-side credentials and streams it back to the test runner.
3. The test runner stores the zip in a temp directory and posts it to `/api/v1/automation_setup`
   for Torus to ingest.

Bucket credentials never leave the server and never appear in Playwright traces. Adding new tests
does not require distributing S3 credentials to engineers — only the server needs them.
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

## Required assets per adaptive test

All adaptive tests that load from the bucket and the S3 keys they expect:

| Test file | S3 archive key | S3 answers key | `@nightly` |
|-----------|---------------|----------------|-----------|
| `designer-planet-adaptive.spec.ts` | `bio_beyond-designer_planet/course.zip` | `bio_beyond-designer_planet/answers.json` | ✅ |
| `our-blue-planet-adaptive.spec.ts` | `bio_beyond-our_blue_planet/course.zip` | `bio_beyond-our_blue_planet/answers.json` | ✅ |
| `phases-of-the-moon.spec.ts` | `phases_of_the_moon-phases_of_the_moon/course.zip` | `phases_of_the_moon-phases_of_the_moon/answers.json` | ✅ |
| `stellar-life-cycles-training.spec.ts` | `habitable_worlds-stellar_life_cycles_training/course.zip` | `habitable_worlds-stellar_life_cycles_training/answers.json` | ✅ |
| `real-chem-greenhouse-molecules.spec.ts` | `real_chem-greenhouse_molecules/course.zip` | `real_chem-greenhouse_molecules/answers.json` | ✅ |
| `real-chem-dazzling-d-orbitals.spec.ts` | `real_chem_ii-dazzling_d_orbitals/course.zip` | `real_chem_ii-dazzling_d_orbitals/answers.json` | ✅ |
| `hw-brightness-assessment.spec.ts` | `habitable_worlds-brightness_assessment/course.zip` | _(none — no secret answers required)_ | ✅ |

## Environment variables

### Torus server (target environment)

These are set in the deployment configuration of the Torus server being tested.

| Variable | Required | Notes |
|----------|----------|-------|
| `PLAYWRIGHT_ASSETS_BUCKET` | Yes | Name of the S3/MinIO bucket containing test assets |
| `PLAYWRIGHT_SCENARIO_TOKEN` | Yes | Shared secret you choose — must match the value set on the test runner. No admin UI needed; set it as an env var on both sides. |
| `AWS_ACCESS_KEY_ID` | Yes (prod S3) | S3 access key. Use `AWS_S3_ACCESS_KEY_ID` to override with a dedicated key for the PW bucket, separate from other AWS credentials the server may already have. |
| `AWS_SECRET_ACCESS_KEY` | Yes (prod S3) | S3 secret key. Same override pattern via `AWS_S3_SECRET_ACCESS_KEY`. |
| `AWS_S3_SCHEME` | Dev/MinIO only | URL scheme for MinIO (default: `http`). Not needed for real S3. |
| `AWS_S3_HOST` | Dev/MinIO only | MinIO host (default: `localhost`). Not needed for real S3. |
| `AWS_S3_PORT` | Dev/MinIO only | MinIO port (default: `9000`). Not needed for real S3. |

### Playwright test runner

These are set on the CI agent (e.g. as GitHub Actions secrets on the `nightly-ui` environment).
The Torus server and the test runner are separate processes — the runner only needs to know how to
reach the server and authenticate its requests.

| Variable | Required for | Description |
|----------|-------------|-------------|
| `PLAYWRIGHT_BASE_URL` | All tests | Torus server URL (e.g. `https://nightly.oli.cmu.edu`) |
| `PLAYWRIGHT_SCENARIO_TOKEN` | All tests | Same value as the server-side token |
| `PLAYWRIGHT_AUTOMATION_API_KEY` | Adaptive tests | See [Automation API key](#automation-api-key) |
| `CANVAS_UI_EMAIL` | LTI tests | Canvas test-account email |
| `CANVAS_UI_PASSWORD` | LTI tests | Canvas test-account password |
| `PLAYWRIGHT_PARAMETER_CONFIG_URL` | Dot chatbot smoke | URL to the YAML config file (see `nightly-ci.md`) |

## Automation API key

`PLAYWRIGHT_AUTOMATION_API_KEY` must correspond to an API key in the target Torus environment that
has `automation_setup_enabled: true`. To create one:

1. Log in as an admin on the target Torus instance.
2. Go to `/admin/api_keys`, enter a hint, and click **Create** — Torus generates the key value.
3. Toggle `automation_setup_enabled` on for the newly created key.
4. Export the generated value as `PLAYWRIGHT_AUTOMATION_API_KEY` in the CI environment.

Never reuse a key value that appears in the repository. `/api/v1/automation_setup` is reachable
in any environment where the flag is compiled in, and is gated solely by this key.

## Seeding the bucket

For each adaptive test in the table above, the corresponding `course.zip` (and `answers.json` where
applicable) must be uploaded to the Playwright assets bucket under the exact S3 key path shown.

The person responsible for managing the bucket (typically DevOps) should upload the files using
whatever access method they have available. The folder structure and file names must match the paths
in the table exactly.

## Running the nightly suite

The nightly subset is identified by the `@nightly` tag embedded in test descriptions. Run it with:

```sh
npx playwright test --grep @nightly
```

## Known issues

1. **`enable_playwright_scenarios` is a compile-time flag, not a runtime env var** — any nightly
   environment must be built with it set to `true` in the Mix config. Coordinate with DevOps to
   confirm which `MIX_ENV` the nightly environment uses.

2. **Tags are plain text, not Playwright tag filters** — `@nightly` currently appears inside the
   test description string. This works with `--grep` today. Migrating to
   `test('...', { tag: '@nightly' }, ...)` is a future clean-up item that enables native UI
   filtering in Playwright, but it is not a blocker.
