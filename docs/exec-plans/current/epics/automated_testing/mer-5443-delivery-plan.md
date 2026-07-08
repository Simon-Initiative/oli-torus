# MER-5443 Delivery Automation Plan

Scope and reference artifacts:
- Jira story: `MER-5443`
- Epic plan source: `docs/exec-plans/current/epics/automated_testing/plan.md`
- Related delivery precedents:
  - `MER-5438` CATA delivery coverage (merged)
  - `MER-5440` ordering delivery coverage (merged)
  - `MER-5446` embedded/image-hotspot/image-coding/logic-lab/vlab delivery coverage (PR 6712, draft — establishes the `support/` folder convention and `test.step` grouping this plan follows)

## Scope
Deliver Playwright-based learner delivery coverage for the activity types grouped under `MER-5443`:

- `oli_file_upload`
- `oli_likert`
- `oli_directed_discussion`

The target layer is learner-facing delivery only. Tests prove that an explicitly authored activity configuration behaves correctly for a student after publish/section/enrollment setup. Authoring UI creation flows are out of scope.

These three activities differ from the CATA/ordering/hotspot precedents in one important way: **none of them has a simple correct/incorrect scored interaction.**
- `oli_file_upload` is manually graded (`gradingApproach: "manual"`); the learner-visible outcome is a submission-received state, not correct/incorrect feedback.
- `oli_likert` sets `allowClientEvaluation: false`; it collects a scale selection (survey-style) rather than showing right/wrong.
- `oli_directed_discussion` is participation-based; there is no Submit/evaluate button — the interaction is posting, and the outcome is the post appearing plus participation progress.

Because there is no wrong-answer path, the "negative" coverage for this ticket is **validation-edge and gating behavior** (submit/post disabled states, size/word limits), not incorrect-answer feedback.

## Working Agreement For This Ticket
- Prefer reusable helpers and shared setup over long one-off specs.
- Reuse existing student-delivery automation patterns before introducing new local logic.
- Extend shared helpers when a step or assertion pattern appears in more than one activity flow.
- Keep activity-specific logic in the individual spec only when it is truly unique to that activity type.

## Coordination With MER-5446 (PR 6712)
PR 6712 is a sibling Lane 4 story, currently a **draft** (not merged to master). It refactors the shared `support.ts` into a `support/` folder and adds `test.step` grouping. There is **no feature overlap** — the two tickets cover disjoint activity sets. The only shared surface is two scaffolding files:

- `support/common.ts` — PR 6712 renames `support.ts` → `support/common.ts`.
- `support/index.ts` — PR 6712 creates this barrel.

This plan reproduces that same small scaffolding on the MER-5443 branch (the shared helpers already live in `support.ts` on master; we reuse them regardless). New per-activity helper files (`support/fileUpload.ts`, `support/likert.ts`, `support/directedDiscussion.ts`), specs, and scenario YAMLs are unique paths with zero conflict. Whichever PR merges second resolves a trivial two-file conflict: take the other side's `common.ts` and union the `index.ts` export lines. Do **not** cherry-pick 6712 commits — the scaffolding changes are bundled inside its per-activity feature commits and would drag in unrelated test files.

## Reuse-First Starting Points
- Shared delivery helpers:
  - `assets/automation/tests/torus/student_delivery/support/` (recreated per the 6712 convention)
  - generic helpers in `support/common.ts` (login/runtime-config/seed/open-practice)
  - activity-specific helpers alongside it, for example `support/fileUpload.ts`
- Reference specs:
  - `assets/automation/tests/torus/student_delivery/cata-delivery.spec.ts`
  - `assets/automation/tests/torus/student_delivery/ordering-delivery.spec.ts`
- Reference content JSON (all three types authored end-to-end here):
  - `test/scenarios/activities/remaining_activity_type_submissions.scenario.yaml` (file_upload, likert, directed_discussion)
- Shared automation infrastructure:
  - `assets/automation/src/systems/torus/` POMs and tasks

Rule for this work item:
- if a login, navigation, seeding, course-entry, or common assertion step appears in two or more `MER-5443` specs, move it into a shared helper unless a stronger existing abstraction already exists elsewhere in `assets/automation/src/systems/torus/`

## Delivery Strategy
Scenario-driven setup plus Playwright delivery interaction:

1. Seed a minimal project, page, activity, publication, section, and student enrollment with scenario YAML.
2. Log in as the learner in Playwright.
3. Open the seeded practice page from the learner delivery flow.
4. Interact with the activity as a student.
5. Assert that visible delivery behavior matches the authored configuration seeded in the scenario.

Validated approach carried over from the sibling precedents:
- one seeded practice page per activity type, with multiple authored variants when they share the same learner navigation flow
- separate sections for tests that must isolate learner attempt state, reset state, or restore-on-revisit behavior
- group closely related assertions into a small number of tests per activity type using `test.step`, so the suite pays the login/navigation cost fewer times

## Activity Order And Scope
Recommended implementation order (cleanest first, highest backend risk last):

1. `oli_likert` — pure client interaction (radio table), no external backend; defines the reusable `MER-5443` template.
2. `oli_file_upload` — depends on object storage (minio) for a real upload; oversize/gating negatives are client-side and backend-free.
3. `oli_directed_discussion` — depends on the discussion REST API; posting round-trips through a normal controller, but the surface is the largest.

## Per-Activity Test Intent
Each activity gets at least one positive learner path and, when practical, the validation-edge negatives described in Scope.

Baseline assertions:
- the activity renders in learner delivery
- the student can perform the intended interaction
- submit/post completes through delivery
- the visible post-interaction state matches the authored configuration

Representative expectations:
- `oli_likert`
  - selecting a scale point enables Submit; submitting shows the saved/received state
  - Submit is disabled until a scale point is selected
  - the submitted selection is restored after reload
- `oli_file_upload`
  - uploading an accepted file lists it and enables Submit; submitting shows the received state
  - a file over the authored `maxSizeInBytes` shows the size error and is not added
  - Submit is disabled with zero uploaded files
- `oli_directed_discussion`
  - posting text of sufficient length adds the post to the thread with the author name and content
  - the participation widget reflects the post once a minimum is authored
  - the Post control is disabled below the minimum character length / over the authored word limit

## Test Coverage Matrix
Path types: **H** = happy, **N** = negative/validation, **P** = persistence. Each row cites the delivery behavior it relies on. **Status** reflects the Codex design-review pass (`reviews/codex-design-review-MER-5443-response.md`): *confirmed* as originally written, or *corrected* (assertion/seed updated per code evidence).

### `oli_likert` — `oli-likert-delivery` (inner class `.multiple-choice-activity`), radios `input.oli-radio`, generic `SubmitButton` (text "Submit", `aria-label="submit"`)

Likert is seeded with **scoreable responses** (matching the reference JSON): submit triggers server evaluation, so the learner-visible outcome is an evaluated result (`aria-label="result"`), NOT a "response received" notice. `allowClientEvaluation:false` gates client self-eval only; the server still evaluates, and the notice renders only when `dateEvaluated === null`.

| # | Path | Section seed | Interaction | Expected assertion | Behavior basis | Status |
|---|---|---|---|---|---|---|
| L1 | H | `likert_section` (scoreable) | click a scale radio, click Submit | radio becomes disabled; evaluated feedback `aria-label="result"` present (NOT the "received" notice) | radios `LikertTable.tsx:78-90`; submit returns server evaluations `attempt_controller.ex:737-763`; result renders when score/outOf exist `Evaluation.tsx:100-104`; notice suppressed when `dateEvaluated!=null` `Submission.tsx:8-15` | **corrected** |
| L2 | N | `likert_section` | do not select; inspect Submit | Submit disabled before selection, enabled after a radio selection | `SubmitResetConnected`→`SubmitButtonConnected` `SubmitReset.tsx:11-20`; disabled while all part inputs empty `SubmitButtonConnected.tsx:18-23`; selection writes `[selection]` `DeliveryState.ts:539-571` | confirmed |
| L3 | P | `likert_section_restore` (scoreable) | select, Submit, `page.reload()` | checked radio restored AND disabled (evaluated state persists) | restore via `initialPartInputs` `utils.ts:66-91`; likert inits from state `LikertDelivery.tsx:52-59`; disabled when `isEvaluated` (`dateEvaluated!==null`) `LikertDelivery.tsx:93-98`, `DeliveryState.ts:310-311` | **corrected** |

### `oli_file_upload` — `oli-file-upload-delivery` (inner class `.cata-activity`, copy-paste artifact), hidden `input[type=file]#upload-{attemptGuid}`, generic `SubmitButton`

File upload is manually graded → `dateEvaluated` stays null → the "response received" notice IS the correct post-submit assertion (opposite of likert).

**Storage is a server-side concern, not a test-side one.** Playwright drives the browser against a running Torus server; that server's `AWS_*` runtime config decides where the blob lands — real AWS S3 in the nightly testing env (`config/runtime.exs:310-317`, present), minio locally (`config/dev.exs:247-259`, dev default). The test bytes are identical either way. Therefore **F1/F4 carry a test-side skip guard** (e.g. `test.skip(!storageAvailable, ...)`) so they exercise a real upload where storage exists (nightly) and auto-skip where it does not (a local run without minio), keeping the suite green everywhere. The storage-free negatives **F2/F3 always run**.

| # | Path | Section seed | Interaction | Expected assertion | Behavior basis | Status |
|---|---|---|---|---|---|---|
| F1 | H (minio-dependent) | `file_upload_section` (large `maxSizeInBytes`, `accept: ""`) | `setInputFiles` on the hidden input with `tests/resources/media_files/img-mock-05-16-2025.jpg`; wait for list item; click Submit | file appears as `.list-group-item`; Submit enabled; after submit, "Your response has been received" notice visible | list after upload success `FileUploadDelivery.tsx:154-176`,`:117-136`; submit `:302-316`; upload → S3/minio `artifact.ex:5-17`, `config/dev.exs:19-23` | confirmed (storage-gated) |
| F2 | N | `file_upload_section_small` (tiny `maxSizeInBytes`, e.g. 10) | `setInputFiles` with any media file (exceeds 10 bytes) | `role="alert"` "This file exceeds the maximum allowed file size"; no `.list-group-item`; Submit stays disabled; **no storage call** | size guard runs BEFORE upload (else-branch) `FileUploadDelivery.tsx:154-174`; alert copy `:232-235` | confirmed |
| F3 | N | `file_upload_section` | inspect Submit with zero files | visible Submit disabled when `files.length === 0` | plain `SubmitButton` shown when ungraded/non-survey `FileUploadDelivery.tsx:302-314`; disabled at 0 files `:310-314` | confirmed |
| F4 | P (minio-dependent) | `file_upload_section_restore` | upload, Submit, `page.reload()` | uploaded file still listed; "received" notice persists | list restore via `safelySelectFiles` `utils.ts:53-64`, init `FileUploadDelivery.tsx:263-276`; submitted rollup `roll_up.ex:518-525`; notice `Submission.tsx:8-15` | confirmed (storage-gated) |

### `oli_directed_discussion` — `oli-directed-discussion-delivery` (inner class `.mc-activity`), `<textarea>`, "Post" button; posting via `POST /api/v1/discussion/:section_slug/:resource_id`

Single-user posting round-trips through the REST response (`Post.post_response`); the local `posts` state is updated from that response, so **no Phoenix channel is required** for own-post visibility or participation update.

| # | Path | Section seed | Interaction | Expected assertion | Behavior basis | Status |
|---|---|---|---|---|---|---|
| D1 | H | `dd_section` (`participation.minPosts:1`) | type ≥4 chars in textarea; click "Post" | new post appears in thread with the student's name and typed content | POST returns post `directed_discussion_controller.ex:96-99`; hook merges locally `discussion-hook.tsx:58-74`; textarea `CreatePost.tsx:35-44` | confirmed |
| D2 | H | `dd_section` (`minPosts:1`) | post once | participation Post row changes from `0/1` to the check mark | participation from local `posts` via `useMemo` `DirectedDiscussion.tsx:30-38`; widget rows `DiscussionParticipation.tsx:20-37`,`:67-75` | confirmed |
| D3 | N | `dd_section` | inspect Post control at 0 / 1–3 / ≥4 chars | no Post button at 0 chars; visible-but-disabled at 1–3; enabled at ≥4 | button area shown when `content.length>0` `CreatePost.tsx:22-24`,`:45-58`; disabled when `!canPost` `:54-56` | confirmed |
| D4 | N | `dd_section_wordlimit` (`participation.maxWordLength: N`) | type over the word limit | counter text `Over max word limit: X / N` has `text-red-600`; Post disabled | delivery reads `participation.maxWordLength` (NOT top-level `maxWords`) `DirectedDiscussion.tsx:69-79`, `schema.ts:3-9`; red counter + disabled `CreatePost.tsx:32-56` | **corrected** (seed field) |
| D5 | P | `dd_section_restore` (`minPosts:1`) | post, `page.reload()` | posted message still present in thread after reload | posts restored via GET on init `discussion-hook.tsx:32-46`, `discussion-service.ts:64-67` | **added** (Codex-suggested symmetry) |

## Scenario Authoring Guidance
Use the scenario seed as the source of truth for authored configuration. Do not build activities through the authoring UI.

Each scenario:
- creates a dedicated project and practice page
- creates the target activity with `content_format: "json"`, using the reference bodies in `remaining_activity_type_submissions.scenario.yaml` as the starting point, adjusted per the matrix (e.g. scoreable likert responses for L1/L3, tiny `maxSizeInBytes` for F2, `participation.minPosts:1` for D1/D2/D5, `participation.maxWordLength: N` for D4 — NOT top-level `maxWords`, which delivery ignores)
- places the activity on the page via `edit_page` with an `activity_reference` block
- publishes the project
- creates one or more sections (one per attempt-isolated variant)
- creates and enrolls a learner
- returns the section slug(s) needed by Playwright

Keep each scenario narrow and deterministic. Use multiple sections pointing at the same publication when tests need fresh learner attempts without reseeding.

## Risks And Constraints
- `oli_file_upload` happy/persistence paths (F1, F4) require a working object-storage backend. This is provided by real AWS S3 in the nightly testing env (`config/runtime.exs:310-317`) and by minio locally (`config/dev.exs:247-259`). Storage selection is server-side (via `AWS_*` env vars), not chosen by the test. F1/F4 carry a test-side skip guard so they run where storage exists and skip where it does not; the storage-free negatives F2/F3 always run.
- `oli_directed_discussion` depends on the discussion REST API and, for cross-user realtime, a Phoenix channel. Single-user posting is expected to round-trip through the REST response without the channel; the participation-widget-live-update assumption (D2) is the main open question and is flagged for Codex.
- Root CSS classes are misleading due to copy-paste in the components (`file_upload` → `.cata-activity`, `likert` → `.multiple-choice-activity`, `directed_discussion` → `.mc-activity`). Prefer the web-component element tag (`oli-file-upload-delivery`, etc.) as the stable outer locator.
- `MER-5443` should not absorb authoring UI coverage (Lane 2/3) or the broader collaboration/discussion feature coverage that belongs to Lane 9.

## Implementation Phases
### Phase 1: Establish the shared pattern (likert)
- recreate the `support/` scaffolding (`common.ts` rename + `index.ts` barrel) per the 6712 convention
- add the `oli_likert` scenario + spec pair, extracting `support/likert.ts` helpers as needed
- use this slice to validate the seed → login → open → interact → assert template for a non-scored activity

### Phase 2: File upload
- add the `oli_file_upload` scenario + spec pair
- implement F2/F3 (storage-free) first to lock in coverage, then F1/F4 against minio
- consolidate any repeated upload/submit/notice helpers into `support/fileUpload.ts`

### Phase 3: Directed discussion
- add the `oli_directed_discussion` scenario + spec pair
- drive posting through the delivery UI; assert own-post visibility and participation
- extract `support/directedDiscussion.ts` for post/assert helpers

## Test Strategy
- validate scenario structure seeds successfully before writing assertions
- run targeted Playwright coverage for each added spec (`npm run pw <spec>`)
- ensure the `support/` refactor does not break existing `student_delivery` specs (cata, ordering, sayg, student-dashboard)

Verification tooling in `assets/automation`:
- format check `npm run prettier`; autofix `npm run format`
- lint `npm run lint`
- run a spec `npm run pw <spec-file>`; report `npm run show-report`
- optional explicit typecheck `npx tsc --noEmit` (no committed script)

## Done Criteria
- `MER-5443` has delivery coverage for the three intended activity types, or any unimplemented path has a documented concrete blocker
- tests validate authored intent through learner-visible delivery behavior (submission/participation state, not fabricated correct/incorrect)
- shared helper reuse is explicit; the `support/` scaffolding matches the 6712 convention so the eventual merge is a trivial two-file union
- specs follow the precedent set by existing `student_delivery` automation (scenario seed + `test.step` grouping) instead of a parallel ad hoc style

## Codex Design-Review Pass — Resolved
Full response: `reviews/codex-design-review-MER-5443-response.md`. All 8 questions answered against code; the matrix above is updated accordingly. Outcome:

1. **Likert assertion target (L1/L3):** *refuted* — scoreable likert is server-evaluated; assert `aria-label="result"` + disabled radios, not the "received" notice. **Applied.**
2. **Likert Submit gating (L2):** *confirmed* — `SubmitButtonConnected`, disabled until a selection exists.
3. **File upload storage (F1):** *confirmed with risk* — list item appears only after upload succeeds; F1/F4 are minio-dependent. **Flagged in matrix.**
4. **File upload size guard (F2):** *confirmed* — client-side before upload; exact copy verified. Storage-free negative.
5. **DD single-user posting (D1):** *confirmed* — own post from REST response, no channel.
6. **DD participation live-update (D2):** *confirmed* — recomputed from local `posts`; `0/1` → ✅.
7. **DD gating (D3/D4):** *confirmed with seed correction* — delivery honors `participation.maxWordLength`, not top-level `maxWords`. **Applied to D4.**
8. **Overall scope:** *confirmed with adjustments* — happy + validation-negative + persistence is the right set; added **D5** (DD reload persistence) for symmetry.

**Recommendation: adjust before build → adjustments applied.** Matrix is now build-ready pending human approval.
