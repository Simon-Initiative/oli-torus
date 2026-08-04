# MER-5416 Basic Page Publication Validation Approach

Scope and reference artifacts:
- Jira story: `MER-5416`
- Epic plan source: `docs/exec-plans/current/epics/automated_testing/plan.md`
- Existing authoring Playwright coverage:
  - `assets/automation/tests/torus/course_authoring/course-authoring.spec.ts`
  - `assets/automation/tests/torus/course_authoring/playwright_course_authoring.yaml`
- Relevant scenario and preview precedents:
  - `test/scenarios/features/instructor_preview_mixed_page_hardening.scenario.yaml`
  - `test/scenarios/features/instructor_preview_hooks.ex`

## Problem Statement
`MER-5416` asks for expanded Playwright coverage of basic page authoring so it covers the items listed in the `MIXED` tab of the regression spreadsheet.

The Jira description frames this as:

1. `Oli.Scenario` bootstraps users, project, and page state.
2. Playwright authors or edits the basic page content.
3. The resulting content is validated as publication-ready.

The latest Darren comment adds a stronger possible interpretation:

1. `Oli.Scenario` bootstraps the world.
2. Playwright performs the authoring step.
3. A follow-up `Oli.Scenario` performs assertions against:
   - authoring preview rendered content
   - student delivery rendered content

That interpretation is not yet reflected in the current automation infrastructure.

## Working Interpretation
For this ticket, the agreed meaning of the two assertion surfaces is:

- `authoring preview assertions`
  - validate the rendered output of the authored basic page through the authoring preview surface
  - this is not instructor preview
- `student delivery assertions`
  - validate the rendered output of the same content after publish, section creation, and learner delivery

This interpretation matters because the repository currently has stronger precedent for instructor preview assertions than for authoring preview assertions.

## Current State In The Repo
### What already exists
- Playwright can seed scenario YAML worlds before a browser test via:
  - `assets/automation/src/core/fixture/my-fixture.ts`
  - `assets/automation/src/core/seedScenario.ts`
  - `lib/oli_web/controllers/playwright_scenario_controller.ex`
- Basic page authoring coverage already exists, but as broad authoring flows rather than a `MIXED`-tab-aligned validation matrix.
- Scenario hooks can execute custom Elixir assertions during scenario execution.
- Scenario directives already support learner-side attempt setup and answering flows such as:
  - `view_practice_page`
  - `visit_page`
  - `answer_question`
  - `hook`

### What does not exist yet
- No current mechanism runs a second scenario after Playwright modifies authored state.
- No current Playwright fixture coordinates:
  - scenario setup
  - browser authoring mutation
  - scenario-based post-authoring assertions
- No current documented boundary was found for authoring-preview-specific assertions comparable to the existing instructor preview hook precedent.

## Main Scope Question
`MER-5416` appears to have two possible sizes.

### Option A: Coverage-only ticket
Deliver additional Playwright specs that:
- seed the initial world with scenario YAML
- author content in the browser
- use browser-visible checks to validate the result

This option stays within the current test infrastructure.

### Option B: Coverage plus infrastructure ticket
Deliver additional Playwright specs and also add infrastructure to support:
- post-Playwright scenario execution
- authoring preview assertions below the browser UI layer
- student delivery assertions below the browser UI layer

This option is materially larger because it introduces orchestration capability, not just more coverage.

## Recommendation
Treat `MER-5416` first as a dimensioning and slicing exercise, not immediately as a pure implementation ticket.

Recommended next decision:

1. Map the `MIXED` regression rows into concrete coverage groups.
2. Split them into:
   - rows that can be covered with the current Playwright stack
   - rows that require post-authoring scenario assertions
3. If most required rows fall into the first group, keep `MER-5416` as Option A.
4. If key acceptance value depends on the second group, escalate to a formal plan and treat the infrastructure work explicitly.

## Proposed Implementation Cut If We Keep The Ticket Small
If the ticket remains Option A, implement it as:

1. Add a dedicated `MER-5416` support scenario YAML for world bootstrap only.
2. Add one or more Playwright specs aligned to `MIXED` row groupings.
3. Reuse or extend basic page authoring POM helpers.
4. Validate publication readiness through browser-level preview and delivery checks only where already practical.
5. Document any missing authoring-preview or post-Playwright-scenario gaps as follow-up work.

## Signals That The Ticket Should Escalate To A Formal Plan
Escalate from `harness-work` to a fuller planning lane if any of these become required:

- new scenario controller behavior to support multiple scenario phases
- persistent state handoff from Playwright browser actions into scenario execution
- new scenario directives or hooks specifically for authoring preview assertions
- reusable infrastructure for asserting published delivery content outside Playwright after authoring mutations

## Risks
- The phrase `authoring preview assertions` can be misread as instructor preview if not fixed explicitly.
- A coverage-only implementation may look complete while still missing the deeper post-authoring validation Darren described.
- A single ticket that mixes matrix expansion with new automation orchestration may be too large for a lightweight work lane.

## Immediate Next Step
Use this document as the working support artifact for `MER-5416` while reviewing the `MIXED` tab row-by-row.

The next concrete output should be a row-grouped coverage inventory that labels each regression item as:
- `covered already`
- `playwright only`
- `needs post-playwright scenario support`

That inventory now has a workflow-specific companion artifact in:
- `docs/exec-plans/current/epics/automated_testing/mer-5416/mixed_coverage_matrix.md`

The matrix is the source of truth for row-complete workflow planning against the external spreadsheet.

## Initial Coverage Inventory From The Current Repo
The external `MIXED` tab rows were not present in the Jira issue payload, so the first inventory pass is limited to the checked-in automation coverage.

### Covered already
The current `course_authoring` Playwright coverage already validates authoring preview for several authored content types on dedicated basic pages. The strongest precedent is the `Add one of each type of content to dedicated pages` group in `assets/automation/tests/torus/course_authoring/course-authoring.spec.ts`.

Current preview-covered content types include:
- cite
- foreign text
- image
- formula
- callout
- popup
- dialog
- table
- theorem
- conjugation
- description list
- audio
- video
- YouTube
- webpage embed
- code block
- figure
- page link
- definition

There is also narrower existing coverage for:
- modifying text content
- changing text formatting
- inserting an image into a basic page
- publishing updates and confirming learner-visible page availability at a coarse level

### Playwright only
These are behaviors that the current suite appears structurally able to cover without new infrastructure, assuming they are part of the `MIXED` matrix:
- additional basic page authored content insertions that can be validated through the existing author preview window
- richer permutations of already-covered content types
- save, reopen, and preview validation for authored content where browser-visible assertions are sufficient
- grouped publication-ready checks that can be observed directly from authoring preview or learner delivery UI

### Needs post-playwright scenario support
These are the likely cases that cannot be considered solved by the current stack alone:
- any requirement that explicitly needs scenario-driven assertions after Playwright has mutated the authored page
- assertions against authoring preview through a non-browser raw-render boundary
- assertions against student delivery through a non-browser raw-render boundary after the same Playwright authoring mutation
- reusable orchestration of:
  - scenario bootstrap
  - Playwright authoring
  - scenario assertion execution

## Known Gap In This Inventory
This initial inventory is coverage-oriented, not regression-row-complete.

Until the `MIXED` spreadsheet tab is available as concrete row data, this document can only answer:
- what the repo already covers
- what the current infrastructure can probably absorb
- what likely forces ticket escalation

It cannot yet answer:
- which exact regression rows are already satisfied
- which exact regression rows are missing
- which row groupings make the most sense for `MER-5416` spec slicing

## `MIXED` Tab Inventory Snapshot
The provided `MIXED` tab CSV currently contains 80 rows across these groups:

- `CORE`: 1
- `INLINE`: 15
- `LIST`: 2
- `TABLE`: 7
- `IMAGE`: 5
- `YOUTUBE`: 8
- `VIDEO`: 6
- `WEBPAGE`: 4
- `CODEBLOCK`: 4
- `FORMULA`: 1
- `CALLOUT`: 1
- `DEFINITION`: 1
- `FIGURE`: 2
- `DIALOG`: 11
- `CONJUGATION`: 7
- `DESCRIPTIONLIST`: 4
- `THEOREM`: 1

## Initial Group-Level Classification Against Current Coverage
This is the first practical mapping between the checked-in Playwright coverage and the real `MIXED` inventory.

### Likely covered already, fully or almost fully
- `FORMULA`
  - existing preview coverage adds and verifies formula content
- `CALLOUT`
  - existing preview coverage adds and verifies a block callout
- `THEOREM`
  - existing preview coverage adds and verifies theorem content
- `WEBPAGE`
  - current suite covers basic insertion and preview rendering
  - settings/open-in-new-tab/copy-link flows are not yet confirmed, so this group is not truly complete

### Partially covered by current Playwright coverage
- `IMAGE`
  - current suite inserts and previews an image
  - missing: png/jpg replacement flow, caption, alt text, width, and likely delivery verification at row granularity
- `YOUTUBE`
  - current suite inserts and previews a YouTube embed
  - missing: id-only insertion, caption edits, open/copy affordances, settings edits, alt text, delete/undo
- `VIDEO`
  - current suite inserts and previews video
  - missing: extra track, caption track, poster image, size settings, delete/undo
- `CODEBLOCK`
  - current suite inserts a code block and verifies preview text
  - missing: explicit language change, delete, undo, and row-level persisted/delivery checks
- `DEFINITION`
  - current suite covers simple definition creation
  - missing: multiple definitions, translation, pronunciation, richer edit path
- `FIGURE`
  - current suite covers figure title
  - missing: figure-internal content composition such as image and audio
- `DIALOG`
  - current suite covers only a very simple dialog happy path
  - missing most of the 11-row dialog matrix: speakers, labels, lines, embedded content, toggle speaker, delete flows
- `CONJUGATION`
  - current suite covers initial insertion only
  - missing the richer edit matrix
- `DESCRIPTIONLIST`
  - current suite covers initial insertion only
  - missing richer editing flows
- `TABLE`
  - current suite covers simple table insertion with caption and cells
  - missing structural table operations and style variants

### Not meaningfully covered by current Playwright coverage
- `CORE`
  - editing lag check does not currently exist
- `INLINE`
  - current suite does not cover the inline-formatting matrix at all
- `LIST`
  - current suite only incidentally creates a list during a broad smoke flow; it does not cover bullet style or indent behavior

## Practical Conclusion From The `MIXED` CSV
`MER-5416` is not a small “fill a couple of holes” ticket if interpreted as full `MIXED`-tab coverage.

The current suite already provides useful building blocks and a few direct matches, but most of the spreadsheet rows are still uncovered or only superficially represented.

The highest-value insight from the CSV is:

- the current repo has decent precedent for block-content insertion plus preview verification
- the current repo has weak coverage for inline editing semantics, rich edit flows, and component settings matrices
- the current repo has no built-in solution yet for Darren's proposed post-Playwright scenario assertion phase

## Suggested Row Grouping For Implementation Slicing
If `MER-5416` remains a single ticket, the rows should be grouped into a small number of implementation slices:

1. `INLINE` + `LIST` + `CORE`
2. `TABLE`
3. `IMAGE` + `FIGURE`
4. `YOUTUBE` + `VIDEO` + `WEBPAGE`
5. `DIALOG` + `CONJUGATION` + `DESCRIPTIONLIST` + `DEFINITION`
6. remaining singletons:
   - `FORMULA`
   - `CALLOUT`
   - `THEOREM`
   - `CODEBLOCK`

This grouping aligns better with shared authoring widgets and helper opportunities than the raw spreadsheet order.
