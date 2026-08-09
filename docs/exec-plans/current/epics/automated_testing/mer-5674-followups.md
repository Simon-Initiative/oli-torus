# MER-5674 — Follow-ups

Vocabulary: [`adaptive-lesson-terminology.md`](./adaptive-lesson-terminology.md)

## FU-2: Rule-evaluation error path 500s with Protocol.UndefinedError

**Status:** open (found 2026-07-30 by the strict driver's acceptance runs).

`Oli.Delivery.Attempts.ActivityLifecycle.Evaluate.evaluate_from_rules/11` interpolates an error
tuple into a log string — `Logger.error("Error in rule evaluation! #{err}")`
(`evaluate.ex:567`, same pattern at `:559`) — so when the NodeJS rules worker returns an error
tuple (`nodejs/worker.ex:102`, transient), the `String.Chars` protocol crash converts a
recoverable worker hiccup into a 500 on `PUT …/activity_attempt/<guid>` instead of an error
response. Fix: `inspect(err)` in both interpolations, plus deciding what the controller should
return on worker failure. Complexity: low for the logging fix; medium if the error response
contract needs design.

## FU-1: Move Living on the Edge course to the Playwright assets bucket

**Status:** satisfied locally (2026-07-30) — `mer-5674/living-on-the-edge-course.zip` and
`mer-5674/answers.json` are seeded in the local dev bucket. CI provisioning (bucket + API key)
remains unconfirmed. Earlier development (until 2026-07-28) ran against the locally ingested
project at `/workspaces/course_author/living_on_the_edge/overview`.

**Why it matters:** MER-5672 (PR #6731) and MER-5673 (PR #6738) both seed their course
from a zip in the Playwright assets bucket, uploaded through
`POST /api/v1/automation_setup`, which also creates the throwaway author/educator/learner
and an open-and-free section. That is what makes those specs runnable in CI from a clean
state. A spec pointed at a manually ingested local project cannot run in CI and breaks
whenever the local DB is reset.

**What the work is:**

1. Export Living on the Edge as a course archive zip.
2. Seed the assets bucket (MinIO in dev, console at `:9001`; bucket name exported
   server-side as `PLAYWRIGHT_ASSETS_BUCKET`):
   ```
   <bucket>/mer-5674/living-on-the-edge-course.zip
   <bucket>/mer-5674/answers.json
   ```
   Folder and filenames are hardcoded in the spec — must match exactly.
3. Switch the spec's `beforeAll` to `fetchTestArchiveToTempFile` +
   `importArchiveAndCreateSection` (same shape as
   `real-chem-dazzling-d-orbitals.spec.ts`), and `afterAll` to
   `teardownAutomationCourse`.
4. Keep the answer key out of the repo — it is course IP plus answer keys.

**Blocking for:** running this spec in CI. Not blocking local development.

**Related:** [TRIAGE-2419](https://eliterate.atlassian.net/browse/TRIAGE-2419) — automation
teardown cannot fully delete imported full-course projects; cleanup is bounded
best-effort until that lands.
