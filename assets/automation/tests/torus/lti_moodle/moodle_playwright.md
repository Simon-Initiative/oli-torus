# Moodle Playwright LTI Notes

This note tracks what the Torus Moodle LTI Playwright tests cover, what
environment variables they need, and what external presets must already
exist in Torus and Moodle for them to run. It is intentionally free of real
credentials. For implementation details (selectors, timing workarounds, API
choices), read the code — it's commented there, not duplicated here.

## What These Tests Cover

- `moodle-launch.spec.ts` — LTI launch and instructor section creation.
  Each run creates a disposable Moodle course, imports a pre-configured LTI
  activity into it, enrols the instructor, launches into Torus, and
  verifies the "New course set up" wizard creates a section correctly —
  then deletes the section and the course. The disposable course is
  self-healing (looked up and deleted by shortname before each run in case
  a previous run crashed), unlike the persistent fixtures below.
- `moodle-grade-passback.spec.ts` — grade passback. A student completes a
  graded page inside Torus (reached via an LTI launch from a fixed,
  pre-existing Moodle course/section), and the test verifies the score is
  passed back to the Moodle gradebook correctly.

Both reuse Torus-side wizard helpers from
`assets/automation/tests/torus/lti/support/torusLtiFixture.ts`, the same
module `launch.spec.ts` (the Canvas equivalent) uses.

## Required Environment Variables

- `MOODLE_INSTRUCTOR_EMAIL` / `MOODLE_INSTRUCTOR_PASSWORD`
- `MOODLE_STUDENT_EMAIL` / `MOODLE_STUDENT_PASSWORD`
- `MOODLE_API_TOKEN` — scoped to the external service in fixture #5 below.

Optional overrides:

- `MOODLE_BASE_URL`, default `https://oli.moodlecloud.com`
- `MOODLE_LTI_TOOL_NAME`, default `Tokamak` — the pre-registered course
  tool's exact display name (see fixture #4).

## Required External Presets (Torus & Moodle)

Neither spec creates these — they must already exist. If one is ever
deleted, renamed, or reconfigured by hand, the specs will fail in ways that
look like code bugs.

### 1. Torus project — `PLAYWRIGHT_MOODLE_LTI_TEST`

- Where: `tokamak.oli.cmu.edu`, under the `playwright.test.admin@asu.edu`
  author account.
- Contains one **Graded** page, titled `Graded page for graded passback`:
  - A multiple-choice question with options named exactly `Choice A` and
    `Choice B` (`Choice A` correct).
  - A short-answer/text question whose correct answer is exactly `answer`.
- Published, Publishing Visibility set to `Open`.
- Used as `moodle-launch.spec.ts`'s wizard source project, and as the
  source of fixture #3's graded page.

### 2. Moodle course — shortname `playwright_moodle_lti_template`

- Where: `oli.moodlecloud.com`.
- Contains exactly one activity: an External tool backed by the `Tokamak`
  tool (fixture #4), named `Tokamak`.
- Read-only from this automation's perspective — imported from, never
  written to, by `moodle-launch.spec.ts` on every run.

### 3. Moodle course — shortname `playwright_moodle_grade_passback`

Required by `moodle-grade-passback.spec.ts`. Must contain:

- `MOODLE_STUDENT_EMAIL` enrolled as Student, `MOODLE_INSTRUCTOR_EMAIL` as
  Teacher.
- An activity backed by `Tokamak`, already linked (via a completed first
  launch) to a Torus section built from fixture #1's graded page.

### 4. Moodle pre-registered LTI course tool — `Tokamak`

- Where: `oli.moodlecloud.com`, visible in every course's activity chooser.
  Not owned/editable by this automation or any course we have access to.
- Points at `https://tokamak.oli.cmu.edu`.
- Not created, registered, or managed by this automation at all — it's a
  one-time, out-of-band LTI 1.3 mutual-trust registration between Moodle
  and Torus, the same category of setup as Canvas's LTI Developer Key.

### 5. Moodle external service — `Torus Playwright Automation`

- Where: `oli.moodlecloud.com`, *Site administration → Server → Web
  services → External services*.
- Grants: `core_course_create_courses`, `core_course_delete_courses`,
  `core_course_delete_modules`, `core_course_get_courses_by_field`,
  `core_course_get_categories`, `core_user_get_users_by_field`,
  `enrol_manual_enrol_users`, `core_course_import_course`.
- Authorised for the Manager-level Moodle account that generated
  `MOODLE_API_TOKEN`.

## Run Command

From `assets/automation`:

```bash
npm run pw -- tests/torus/lti_moodle/moodle-launch.spec.ts --project "Google Chrome"
npm run pw -- tests/torus/lti_moodle/moodle-grade-passback.spec.ts --project "Google Chrome"
```

Do not paste command output that includes credentials into tickets, docs, or
PR comments.
