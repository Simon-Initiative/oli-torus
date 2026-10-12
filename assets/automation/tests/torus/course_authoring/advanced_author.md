# Advanced Author automated tests (MER-5986)

Phase 1 Playwright coverage for the adaptive Advanced Author (canvas-mode) editor and the
delivery of a lesson built with it, including real Adaptivity trap-state rules.

## Files

| File                                               | Purpose                                                                      |
| -------------------------------------------------- | ---------------------------------------------------------------------------- |
| `advanced-author.spec.ts`                          | The suite.                                                                   |
| `playwright_advanced_author.yaml`                  | Scenario seed: disposable author/educator/two learners, project, section.    |
| `src/systems/torus/pom/page/AdvancedAuthorPO.ts`   | Editor page object: screens, parts, property panel, paste, Adaptivity rules. |
| `src/systems/torus/tasks/AdvancedAuthorTask.ts`    | Workflows: create/open lesson, add screen, reload, publish.                  |
| `src/systems/torus/pom/delivery/AdaptiveDeckPO.ts` | Reused for the delivery deck (`advance()`, `waitForDeckReady()`).            |

## Coverage

| Test                                                 | Asserts                                                                                                                                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<component> keeps its configuration ...`            | One parameterized row per Phase 1 component (static text, image, video, MCQ, number input, multiline text): author it on its own screen, reload, check the configuration.                   |
| `copy/paste and undo/redo update the screen`         | Paste adds a part with a new id; the clipboard is single-use (a second paste, via keyboard, adds nothing); undo/redo; the result survives a reload.                                         |
| `responsive layout arranges components side by side` | Enabling the lesson's "Enable Responsive Layout" setting lets two parts take `50% left`/`50% right` widths, reflected in `.responsive-item`'s classes, and the widths persist after reload. |
| `author builds a branching lesson ...`               | A real Adaptivity rule pair (MCQ `correct` condition + `defaultWrong` fallback), each with a "Navigate To" action to a distinct terminal screen, persists after reload, then publishes.     |
| `student answering correctly ...`                    | Selecting the correct MCQ option and checking navigates straight to the authored "Correct Terminal" screen's text.                                                                          |
| `student answering incorrectly ...`                  | Selecting a wrong option shows the built-in "Incorrect, please try again." feedback, then (once dismissed) navigates to the authored "Incorrect Terminal" screen's text.                    |
| `item bank renders its default items and layout ...` | Item Bank (`janus_item_bank`) renders its default columns (Item Bank + 2 categories) and items, in its default responsive layout, and that persists after reload.                           |

Deferred to later phases: component library, list sort, flashcards, z-order, advanced bank
permutations, and two of the regression checks named in the ticket (slider feedback, blocked on a
real bug — see "Open questions"; responsive subscreens, ambiguous — see "Open questions"). CAPI
sizing and item-bank layout are resolved, see below. Broad exploratory and subjective visual review
stays manual.

## Setup and teardown

- `beforeAll` seeds `playwright_advanced_author.yaml` with a per-run `RUN_ID`. Lessons, screens,
  and components are created through the UI, because that is what the suite covers.
- The component/editing-command/responsive-layout cases run serially on one signed-in page with
  the editor already open, created in `beforeAll`. Each case still reloads the editor to verify
  persistence.
- The lesson-delivery describe block logs in fresh per test (author, then two different seeded
  students — one answers correctly, one incorrectly) since each needs its own session.
- Media is set through the picker's "External URL" tab, so no S3 upload is needed. The image is
  Torus's own `/images/oli_torus_logo.png`. The video is the shared fixture
  `tests/resources/media_files/video-test-01.mp4`, served by `GET /test/support/video-test-01.mp4`
  (`PlaywrightSupportAssetController`, added for Simple Author's suite and reused here, only
  routed when Playwright scenarios are enabled).
- `afterAll` calls the guarded automation teardown with `strictTeardown` when
  `PLAYWRIGHT_AUTOMATION_API_KEY` is set. The seeded names ("Test Author/Educator/Learner",
  "Automation test section") meet its contract. The second seeded student
  (`advanced_author_student_2`, used only for the incorrect-answer path) is not covered by the
  teardown call — it's cleaned up along with the rest of the run's database state in local/CI
  runs that reset the DB between runs, but a persistent deployment would need the teardown
  contract extended to a second learner to clean it up explicitly. Without an API key, for
  example in the PR job, which runs against an ephemeral database, teardown is skipped entirely.

## Running

```bash
cd assets/automation
PLAYWRIGHT_BASE_URL=http://localhost:4000 PLAYWRIGHT_SCENARIO_TOKEN=my-token npm run test-advanced-author
```

## CI placement

Every describe is tagged `@pr`, so the suite runs in the PR Playwright Suite
(`.github/workflows/pr-playwright.yml`, `npx playwright test --grep @pr`). It only depends on
data it seeds and needs no third-party credentials. It is not tagged `@nightly`, because the
nightly job targets a persistent deployment where `/test/scenario-yaml` is not available. No
workflow changes were needed: MER-5988 (Simple Author) already added the Tailwind CSS build and
the server-side rule-bundle build (`priv/node/rules.js`/`eval.js`) the PR job needs for any
adaptive "Check" to work.

## Editor behaviors the page object handles

- **Advanced Author's toolbar carries no accessible names.** The "frequently used" row
  (`ExpertHeaderNav`/`AddComponentToolbar`) renders each button as a bare
  `<button><img src="icon-part-<x>.svg"></button>` with no `alt`/`title`/`aria-label`, so
  `addComponent` matches those by icon `src`. Components outside that row go through the "More
  Components" popover instead, whose entries do carry a visible label — but that label's icon has
  a `title` attribute that leaks into the _accessible name_ (not the DOM text), so those are
  matched by `hasText` rather than `getByRole(..., { name })`. The same leak happens with the "+"
  menu's Font Awesome icons (Screen/Layer/Question Bank, New Correct/Incorrect Rule): `hasText`
  sidesteps it there too.
- **The left Sequence Editor panel and the floating per-part toolbar fight over the same screen
  space.** A newly added part always starts at (or near) `x:0, y:0` — the canvas's
  `newPartAddOffset` resets on every screen change — which sits directly under the left panel.
  `selectPart` collapses the left panel before any toolbar interaction (edit/copy); `addScreen`,
  `selectScreen`, and `selectRule` reopen it first, since sequence/rule navigation needs it.
- **Property fields can share a duplicate id with their wrapper `<div>`** (an app bug, logged to
  the console as "Multiple IDs detected" — seen on fields with a help tooltip, like "Enable
  Responsive Layout"). `field()` only matches real `input`/`select`/`textarea` tags, never a
  wrapper div that happens to share the id.
- **A screen's own creation write can race a same-breath edit.** `addScreen` waits for saves to
  settle between creating the screen and renaming it, or the two concurrent writes can persist
  the "New Screen" template title over the rename (the same class of race Simple Author's
  `addScreen` guards against).
- **The real text editor vs. "Edit JSON".** A selected part's `.active-selection-toolbar
button[title="Edit"]` (shared with Simple Author, rendered by `LayoutEditor`) opens the real
  rich-text `ConfigurationModal`/`.ql-editor`. The Component tab's own toolbar
  (`PartPropertyEditor`) has a visually similar but unlabeled edit icon that opens a raw "Edit
  JSON" textarea instead — not what `setTextFlowText` uses.
- **"defaultWrong" carries two actions, run in order.** Every part's Adaptivity list starts with
  "Initial State", "correct", and "defaultWrong" (the first two names are fixed; "defaultWrong"
  can be renamed but not deleted, and "+ New Incorrect/Correct Rule" is a no-op while one already
  exists). `defaultWrong` ships with a built-in "Show Feedback" action ("Incorrect, please try
  again.") _and_ whatever "Navigate To" action is authored on it — the feedback must be dismissed
  before the navigation continues. `AdaptiveDeckPO.advance()` (already built for other delivery
  specs) handles that click-dismiss-click cycle generically, which is why the delivery test uses
  it instead of a single `submitCheck()`.
- **Condition/action editing needs no Variable Picker dialog.** The Rule Editor's "Target" and
  "Value" fields (`ConditionItemEditor`) are plain text inputs — `setRuleCondition` just types
  `stage.<partId>.<property>` directly, unlike the manual flow the regression spreadsheet
  describes (click a target icon, navigate a picker dialog).
- **The "Navigate To" destination control regenerates its id on every change** (`ScreenDropdownTemplate`
  assigns a fresh `guid()` per render), so `setRuleDestination` locates it by its "Navigate To"
  label rather than a stable id.
- **Every new Advanced Author screen starts in Flow (responsive) layout.** `LayoutEditor.tsx`'s
  `renderPart` always passes `width: '100%'` to parts on such a screen, regardless of the lesson's
  "Enable Responsive Layout" setting. Most parts don't care, but Item Bank (`janus-item-bank`) reads
  its own `width` prop to decide its internal `grouping--fixed`/`grouping--responsive` layout class
  (`grouping-util.ts`), so it renders responsive from the moment it's added — there's no author-
  facing way found yet to get a non-Flow screen to see the fixed variant.

## Open questions

Carried over from `advanced_author_plan.md` (this doc's working predecessor) — see that file's §7
and §7a for the full reasoning.

### Resolved

- **CAPI/iframe sizing** — `tests/torus/capi/capi.spec.ts` already covers the only CAPI sizing
  mechanism that exists (the `RESIZE_PARENT_CONTAINER_REQUEST`/`RESPONSE` postMessage protocol);
  there is no distinct authoring-side sizing control to add here.
- **Item-bank layout** — refers to the `janus_item_bank` stage component (via "More Components"),
  not the Sequence Editor's "Question Bank" node (which has no rendering surface of its own and so
  can't have a layout regression). Covered by `item bank renders its default items and layout ...`
  above.

### Resolved, not yet implemented

- **Responsive subscreens** — asked Raphael directly (Slack, 2026-10-12); confirmed there's no
  separate breakpoint behavior for subscreens — it's the same per-part `responsiveLayoutWidth`
  workflow already covered, just verified on a part placed inside a nested subscreen (under a Layer
  or Question Bank), including persistence and the resulting preview/delivery geometry. Tracked as
  plan file §8 step 13: the existing responsive-width coverage needs to run against a subscreen
  fixture, plus a new check of actual rendered width post-publish (the current responsive-layout
  test only asserts the authoring-side CSS class).

### Confirmed bug, not testable yet

- **Slider regression** — Raphael's Jira comment clarified the intended test (change the Slider's
  option-label count, save, confirm the new max persists and is enforced in delivery). Running that
  flow locally shows it's genuinely broken: `SliderTextAuthor.tsx` recomputes `maximum` but saves it
  through `onSaveConfigure`, which `EditingCanvas.tsx`'s `handlePartSaveConfigure` ignores entirely
  (it only sets a UI focus flag) — the recompute never reaches Redux or the backend. See plan file
  §7a for the full trace. No test was added: asserting the current (broken) behavior would mislead
  whoever fixes it, and asserting the correct behavior would fail on every PR until that happens.
  Recommend filing this as its own bug ticket; the test is fully specified in §7a for whenever it's
  fixed.
