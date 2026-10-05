# Simple Author automated tests (MER-5988)

Phase 1 Playwright coverage for the adaptive Simple Author (flowchart-mode) editor and the
delivery of a lesson built with it.

## Files

| File                                               | Purpose                                                                  |
| -------------------------------------------------- | ------------------------------------------------------------------------ |
| `simple-author.spec.ts`                            | The suite.                                                               |
| `playwright_simple_author.yaml`                    | Scenario seed: disposable author/educator/learner, project, and section. |
| `src/systems/torus/pom/page/SimpleAuthorPO.ts`     | Editor page object: screens, parts, property panel, paste, flowchart.    |
| `src/systems/torus/tasks/SimpleAuthorTask.ts`      | Workflows: create/open lesson, add screen, reload, publish.              |
| `src/systems/torus/pom/delivery/AdaptiveDeckPO.ts` | Reused for the delivery deck (check button, feedback).                   |

## Coverage

| Test                                          | Asserts                                                                                                                                                                                                                       |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<component> keeps its configuration ...`     | One parameterized row per component (static text, image, video, MCQ, multi-select, hub and spoke): author it on its own screen, reload, check the configuration.                                                              |
| `copy/paste and undo/redo ...`                | Paste adds a part with a new id; undo/redo; the result survives a reload. Regressions MER-3420, MER-4109, MER-4572.                                                                                                           |
| `author validates, scores, and publishes ...` | Screen settings (check label, max attempts, max score) and slider advanced feedback (MER-3919) persist; Scoring Overview; flowchart validation errors clear once paths are wired.                                             |
| `student navigates, gets check-button ...`    | Responsive layout side by side at 1280px and stacked at 500px; the authored video loads; custom check label; incorrect feedback keeps the student on the screen; correct path navigation; decimal slider feedback (MER-3919). |

Deferred to later phases: popup, iframe, audio, flashcards, and less common component
permutations. Broad exploratory and subjective visual review stays manual.

## Setup and teardown

- `beforeAll` seeds `playwright_simple_author.yaml` with a per-run `RUN_ID`. Lessons, screens,
  and components are created through the UI, because that is what the suite covers.
- Media is set through the picker's "External URL" tab, so no S3 upload is needed. The image is
  Torus's own `/images/oli_torus_logo.png`. The video is the shared fixture
  `tests/resources/media_files/video-test-01.mp4`, served by `GET /test/support/video-test-01.mp4`
  (`PlaywrightSupportAssetController`, only routed when Playwright scenarios are enabled).
- `afterAll` calls the guarded automation teardown with `strictTeardown` when
  `PLAYWRIGHT_AUTOMATION_API_KEY` is set. The seeded names ("Test Author/Educator/Learner",
  "Automation test section") meet its contract. Without a key, for example in the PR job, which
  runs against an ephemeral database, teardown is skipped.

## Running

```bash
cd assets/automation
PLAYWRIGHT_BASE_URL=http://localhost:4000 PLAYWRIGHT_SCENARIO_TOKEN=my-token npm run test-simple-author
```

## CI placement

Every describe is tagged `@pr`, so the suite runs in the PR Playwright Suite
(`.github/workflows/pr-playwright.yml`, `npx playwright test --grep @pr`). It only depends on
data it seeds and needs no third-party credentials. It is not tagged `@nightly`, because the
nightly job targets a persistent deployment where `/test/scenario-yaml` is not available.

## Editor behaviors the page object handles

- Simple Author has no "All changes saved" indicator. `waitForSaves()` tracks the
  `/api/v1/storage/...` and `/api/v1/project/.../resource|activity` writes and waits for a quiet
  window, measured from the call, longer than the editor's 500ms save debounce. Every editing
  action waits for its write. Without this, quick successive edits, such as editing right
  after a screen is created, can persist an older state over a newer one.
- A reopened lesson can load in read-only mode. `BasicPracticePagePO.ensureSimpleAuthorReady`
  switches it off.
- Right after a screen is created, the toolbar can drop the first component click.
  `addComponent` retries only while no new part appeared, so a slow add is never doubled.
- Adding a screen from the Screen Panel adds "Unknown Rule" paths. The editor also re-sorts
  paths and never leaves a screen without one. `setPaths` therefore converges each screen to
  the exact rule set and asserts it.
