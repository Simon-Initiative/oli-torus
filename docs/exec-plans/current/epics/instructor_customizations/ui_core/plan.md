# Activity Bank Selection Preview Customization - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/ui_core/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/ui_core/fdd.md`
- Requirements: `docs/exec-plans/current/epics/instructor_customizations/ui_core/requirements.yml`

## Scope

Implement the MER-5620 Activity Bank Selection preview experience for instructors in Course Sections. The work includes the new Activity Bank Selection preview UI from Figma, whole-selection remove/restore through the existing LiveView/React preview customization contract, future-attempt warning behavior, and regression protection for already-merged embedded activity remove/restore.

The plan does not include reimplementing embedded activity remove/restore, individual bank candidate management, bulk candidate operations, authored content mutation, or retrospective attempt rewrites.

## Current Execution Reset

The first implementation pass intentionally produced a working vertical slice before all planned phases were executed one at a time. As a result, Phase 2 absorbed parts of Phase 3 and Phase 4: the inline React Activity Bank Selection preview now exists, a sample activity preview renders through the normal activity preview element path, the generic instructor preview bundle is wired, and basic `bank_selection` remove/restore works through `PreviewLessonLive` and `Oli.Delivery.InstructorCustomizations`.

From this point forward, remaining work should proceed in order:

1. Reconcile this plan with the current vertical slice.
2. Close Phase 4 hardening and coverage gaps for whole-selection remove/restore.
3. Implement Phase 5 warning banner and confirmation modal behavior for pages with existing student attempts or visits.
4. Verify Phase 6 template and scope behavior.
5. Complete Phase 7 final verification, cleanup decisions, and PR notes.

UI polish against Figma has already gone through manual iteration for the main Activity Bank Selection component. Future visual tweaks should be treated as refinement within the active phase, not as a reason to expand this ticket beyond the documented acceptance criteria.

## Clarifications & Default Assumptions

- Course Sections are the primary implementation target.
- Template-level UI is reached through the existing Product/Template Customize Content flow, which opens the same instructor-style page preview route for the blueprint section. No separate template UI is planned unless that route behavior changes.
- The Activity Bank Selection preview needs a real new UI component/layout; it is not only a remove/restore button added to the old `activity_bank/preview.html.heex` page.
- The existing separate candidate-listing URL `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id` is out of scope for this ticket and remains controller-owned until the separate listing ticket changes it.
- The implementation target is the inline Activity Bank Selection preview rendered inside `PreviewLessonLive`.
- `Oli.Delivery.InstructorCustomizations` remains the authority for validation, persistence, and page-scoped exclusion state.
- Warning eligibility must be based on server-side section/page data and must not expose learner-specific details.
- No feature flag is planned by default. Telemetry is limited to existing logging/AppSignal paths unless a reusable instructor customization event already exists.

## Phase 1: Surface And Data Discovery

- Goal: Confirm exact implementation boundaries before moving UI and route ownership.
- Tasks:
  - [x] Trace the current Activity Bank Selection preview entry points from page preview links to `ActivityBankController.preview/2` and `activity_bank/preview.html.heex`.
  - [x] Map the legacy selection renderer in `lib/oli/rendering/content/selection.ex`, including how it builds the jumbotron display and preview link.
  - [x] Confirm the relevant template/product entry point: Product/Template Customize Content page Edit links reach the same instructor-style section preview route through the blueprint section slug.
  - [x] Identify where Activity Bank Selection points-per-question and authored criteria should be read for display.
  - [x] Identify the cheapest reliable scored-attempt and practice-visit signals for warning eligibility.
  - [x] Confirm which activity preview rendering path can be reused for the sample question.
  - [x] Record any route or data differences that would force template support into a later phase.
- Testing Tasks:
  - [x] Add or update focused tests only if discovery requires a small helper for warning eligibility or selection metadata extraction.
  - Command(s): no targeted test command required; Phase 1 introduced no runtime helper or behavior change.
- Definition of Done:
  - The implementation target route, metadata sources, warning signals, and template routing assumption are confirmed.
  - Any newly introduced helper has targeted test coverage.
- Gate:
  - Do not start route migration until the current selection preview inputs and required display metadata are mapped.
- Dependencies:
  - Existing PRD/FDD and local route/controller/template context.
- Parallelizable Work:
  - Figma/UI mapping can proceed in parallel with warning-signal discovery.

## Phase 2: Inline Selection Preview Bridge

- Goal: Keep `PreviewLessonLive` as the owning surface and produce a first working inline Activity Bank Selection preview through a React custom element bridge.
- Tasks:
  - [x] Keep the separate Activity Bank candidate-listing route/controller/template unchanged for this ticket.
  - [x] Extend the instructor preview render context with a generic `instructor_preview_context` payload map.
  - [x] Resolve available count and a sample candidate server-side from the existing bank selection logic.
  - [x] Include the generic `instructor_preview_components.js` bundle and sample activity preview bundle in the page scripts.
  - [x] Bypass `Oli.Rendering.Content.Selection` only for `context.mode == :instructor_preview`.
  - [x] Preserve the legacy selection renderer for non-instructor-preview contexts and the separate candidate-listing route.
  - [x] Register a baseline Activity Bank Selection custom element outside the activity manifest system.
  - [x] Render a first functional version of the selection preview with required metadata and one sample activity.
  - [x] Wire the basic `bank_selection` remove/restore intent so the vertical slice can be exercised end to end.
- Testing Tasks:
  - [x] Add LiveView render coverage proving the inline selection emits the React custom element payload.
  - [x] Add read-model coverage for exposed active candidate count.
  - [x] Add basic remove-event coverage proving the new target persists through `InstructorCustomizations`.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
- Definition of Done:
  - Inline Activity Bank Selection preview renders through the existing instructor preview LiveView.
  - No new route or LiveView is introduced for MER-5620.
  - The first working Course Section vertical slice is available for local review before Figma refinement and warning hardening.
- Gate:
  - Do not move candidate-listing route ownership in this ticket.
- Dependencies:
  - Phase 1 route and data discovery.
- Parallelizable Work:
  - Warning confirmation design can proceed after the bank selection target payload is stable.

## Phase 3: Activity Bank Selection Preview UI Refinement

- Goal: Refine the first functional Activity Bank Selection preview until it matches the Figma-backed selection-level design.
- Status: Mostly complete. The main Active/Removed Activity Bank Selection layout has been iterated against Figma and accepted for the current review pass; keep only regression checks and any small discovered visual fixes open.
- Tasks:
  - [x] Start from the Phase 2 baseline custom element and server-owned preview payload.
  - [x] Render heading/title, available-question count, select count, points per question, authored criteria, and one sample question payload.
  - [x] Keep the sample question visible in both active and removed states.
  - [x] Audit the current baseline against the Figma node and user-provided deltas for hierarchy, metadata placement, criteria treatment, divider, sample heading, and action placement.
  - [x] Reuse or align with existing preview primitives where they fit: action button styling, status pill, removed treatment, and sample activity preview element rendering.
  - [x] Refine the default active-state layout, criteria fields, Manage questions placeholder action, divider, sample heading, and narrow-width wrapping behavior.
  - [x] Verify exact spacing, typography, and visual parity against Figma through manual review for the current Activity Bank Selection component pass.
  - [ ] Confirm the preview does not visually regress existing embedded activity preview components.
  - [x] Avoid adding Activity Bank Selection as a fake activity manifest; keep it registered through the generic instructor preview component bundle.
- Testing Tasks:
  - [x] Add render tests for required bridge metadata and sample question payload.
  - [ ] Add frontend Jest tests only if interaction behavior grows beyond the current custom-element bridge.
  - [ ] Add browser-based accessibility/layout verification if Browser MCP or another repeatable browser QA route becomes available.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - Command(s): `cd assets && ./node_modules/.bin/eslint src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx src/components/instructor_preview/activity_bank_selection_preview/preview-entry.tsx src/apps/InstructorPreviewComponents.tsx webpack.config.js`
- Definition of Done:
  - AC-001 and AC-011 are covered by automated tests where practical and by a manual Figma comparison note.
  - The UI matches the approved Figma reference closely enough for PR review.
- Gate:
  - Do not treat MER-5620 UI as complete until Figma/manual browser review is recorded.
- Dependencies:
  - Phase 2 inline preview bridge and stable preview context shape.
- Parallelizable Work:
  - Backend remove/restore event handler shape can be drafted in parallel after the target payload is fixed.

## Phase 4: Whole-Selection Remove/Restore Wiring

- Goal: Route Activity Bank Selection remove/restore through the shared preview customization contract into the core instructor customization implementation.
- Status: Complete for non-warning remove/restore behavior. Phase 5 warning-gated behavior remains separate and not implemented here.
- Tasks:
  - [x] Emit `bank_selection` customization intents with `pageResourceId` and `selectionId` from the selection preview UI.
  - [x] Handle `toggle_preview_activity_customization` for `bank_selection` in the owning LiveView.
  - [x] Validate current page resource id and selection id before writes.
  - [x] Dispatch remove to `InstructorCustomizations.exclude_bank_selection/4`.
  - [x] Dispatch restore to `InstructorCustomizations.restore_bank_selection/4`.
  - [x] Return targeted success replies with `actions`, `visualState`, `statusPill`, and updated available count.
  - [x] Use the short success flash copy: `Activity bank selection removed` and `Activity bank selection restored`.
  - [x] Return and test `ok: false` replies for stale, malformed, unauthorized, or domain-error cases.
  - [x] Keep embedded activity remove/restore behavior untouched.
- Testing Tasks:
  - [x] Add LiveView tests for remove behavior.
  - [x] Add LiveView tests for restore, stale page id, missing selection id, and domain error behavior.
  - [x] Assert local reply shape satisfies the shared contract beyond visible flash/persistence.
  - [x] Keep existing embedded activity remove/restore regression coverage passing.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- Definition of Done:
  - AC-002, AC-003, AC-004, AC-005, AC-006, AC-010, and AC-012 have targeted automated coverage.
  - Whole-selection state is persisted only through `Oli.Delivery.InstructorCustomizations`.
- Gate:
  - Do not add warning confirmation until basic remove/restore succeeds without warning state.
- Dependencies:
  - Phase 2 LiveView ownership.
  - Phase 3 preview UI state rendering.
- Parallelizable Work:
  - Warning eligibility helper tests can be implemented in parallel once Phase 1 identifies the data source.

## Phase 5: Existing Attempts And Visits Warning Flow

- Goal: Warn instructors that changes apply only to future attempts and require confirmation when needed.
- Status: Complete for Course Section instructor preview. Warning banner and modal behavior are implemented for scored attempts and practice page visits; Phase 6 still needs template verification.
- Tasks:
  - [x] Implement or reuse a server-side helper that detects existing scored assessment attempts for the current section/page.
  - [x] Implement or reuse a server-side helper that detects existing practice page visits for the current section/page.
  - [x] Render the exact scored warning copy when applicable.
  - [x] Render the exact practice warning copy when applicable.
  - [x] Add warning modal state to the owning LiveView.
  - [x] Store pending remove/restore action when confirmation is required.
  - [x] Apply the pending action only after instructor confirmation.
  - [x] Clear pending action on cancel or failed validation.
  - [x] Ensure warning checks do not expose learner identity or attempt details to the browser.
- Testing Tasks:
  - [x] Add tests for scored warning copy.
  - [x] Add tests for practice warning copy.
  - [x] Add tests that remove/restore does not persist until warning confirmation.
  - [x] Add tests that canceling warning confirmation leaves state unchanged.
  - [x] Add regression coverage that embedded activity remove also uses the warning confirmation path.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
  - Command(s): `cd assets && ./node_modules/.bin/eslint src/hooks/instructor_preview_customization.ts`
  - Command(s): `cd assets && ./node_modules/.bin/prettier src/hooks/instructor_preview_customization.ts --check`
- Definition of Done:
  - AC-007, AC-008, and AC-009 are covered.
  - Warning logic is server-owned and privacy-preserving.
- Gate:
  - Do not finalize manual QA until both scored and practice warning paths are covered.
- Dependencies:
  - Phase 1 warning-signal discovery.
  - Phase 4 mutation dispatcher.
- Parallelizable Work:
  - Manual Figma comparison can proceed in parallel after modal UI is visually complete.

## Phase 6: Template Verification And Scope Hardening

- Goal: Verify template-level behavior and lock down page/section scoping guarantees.
- Status: Complete. Product/Template Customize Content page Edit links use the same instructor-style preview route through the template's blueprint section, so no additional template UI work was needed. Activity exclusions saved on a blueprint section are now copied to future course sections created from that template, while already-created sections remain unchanged.
- Tasks:
  - [x] Exercise the Product/Template Customize Content flow and confirm the page Edit action reaches `PreviewLessonLive` through the template's blueprint section slug.
  - [x] Verify the Activity Bank Selection and embedded activity remove/restore UI works from that template Customize Content preview without adding a separate template-specific UI surface.
  - [x] Trace the course section creation path from a customized template/product and determine whether `section_page_activity_exclusions` rows are copied from the blueprint section to the new course section.
  - [x] Verify the existing core duplication path copies blueprint activity exclusions to future sections, matching Customize Content semantics without adding duplicate MER-5620 propagation logic.
  - [x] Verify removing a selection or embedded activity in one section/template scope does not affect unrelated sections.
  - [x] Verify removing a selection on one page does not affect another page.
  - [x] Verify authored revisions and existing learner progress are not modified.
- Testing Tasks:
  - [x] Add a template Customize Content preview smoke test if the route can be exercised cheaply.
  - [x] Add scope tests for page isolation and section/template isolation.
  - [x] Confirm existing propagation coverage proves a new course section created from a customized template inherits blueprint activity exclusions.
  - [x] Confirm this feature does not add retroactive propagation to already-created course sections.
  - [x] Determine scenario coverage is not required for Phase 6 because targeted blueprint duplication and LiveView route tests cover the implementation boundary.
  - Command(s): `mix test test/oli/delivery/sections/blueprint_test.exs`
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - Command(s): `mix test test/oli/delivery/sections/blueprint_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- Definition of Done:
  - AC-010 is verified for Course Sections and template Customize Content preview.
  - Template-level customization is confirmed to use the existing instructor preview UI route.
  - Future course sections created from a customized template inherit template-level activity exclusions.
  - Already-created course sections are confirmed not to receive later template-level activity customization updates.
- Gate:
  - Do not close MER-5620 until template Customize Content preview and future-section propagation behavior have been verified or explicitly scoped as a follow-up with evidence.
- Dependencies:
  - Phase 4 persisted remove/restore behavior.
- Parallelizable Work:
  - Scenario coverage can be prepared while the template-to-section creation path is being traced.

## Phase 7: Final Verification, Review Prep, And Cleanup

- Goal: Finish with targeted automated coverage, formatting, manual QA notes, and review-ready scope.
- Status: Complete. Legacy Activity Bank preview code was reviewed and retained because the separate candidate-listing route and non-instructor-preview selection rendering remain outside this ticket's replacement scope.
- Tasks:
  - [x] Remove obsolete controller/template code only if Phase 2 confirms it is no longer used.
    - Retained `ActivityBankController` and `activity_bank/preview.html.heex`; they still own the separate candidate-listing route that is out of scope for MER-5620.
  - [x] Remove obsolete selection-rendering branches only if active references prove they are no longer needed by authoring, delivery, template, or preview surfaces.
    - Retained `Oli.Rendering.Content.Selection`; instructor preview bypasses it for inline selections, while legacy/non-instructor-preview rendering remains supported.
  - [x] Confirm no new feature flag or migration is required.
  - [x] Confirm no learner-specific data is logged or rendered.
  - [x] Confirm UI text, warning copy, and action labels match requirements.
  - [x] Confirm embedded activity remove/restore regression coverage still passes.
  - [x] Prepare PR notes with Course Section behavior, template verification result, warning behavior, and test evidence.
- Testing Tasks:
  - [x] Run all targeted LiveView/context tests touched by the implementation.
  - [x] Run targeted frontend tests if React code changed.
  - [x] Run formatters for touched Elixir and TypeScript files.
  - Command(s): `mix test <targeted_test_files>`
  - Command(s): `mix format <touched_elixir_files>`
  - Command(s): `cd assets && yarn test <targeted_tests>`
  - Command(s): `cd assets && yarn format`
- Definition of Done:
  - Requirements AC-001 through AC-012 are covered by automated tests, manual verification, or documented scope evidence.
  - Security and performance review notes are ready for PR review.
  - No unrelated embedded activity implementation is duplicated.
- Gate:
  - Ready for PR only after targeted tests and formatting pass.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - PR notes and manual QA checklist can be prepared while final tests run.

## Parallelization Notes

- Figma/UI mapping and warning-signal discovery can run in parallel during Phase 1.
- React component scaffolding can run alongside the LiveView shell once the preview context shape is stable.
- Warning eligibility helper tests can be prepared while basic remove/restore wiring is being implemented.
- Template propagation verification can run in parallel with scope tests after persisted whole-selection customization works.
- Final PR notes can be drafted while targeted automated tests run.

## Phase Gate Summary

- Gate A: Route, metadata, warning-signal, and template-entry assumptions are confirmed before route migration.
- Gate B: Activity Bank Selection preview is LiveView-owned before remove/restore wiring begins.
- Gate C: New selection UI renders required metadata and states before mutation replies are connected.
- Gate D: Basic whole-selection remove/restore works before warning confirmation is layered in.
- Gate E: Warning behavior is covered for scored attempts and practice visits before final UI verification.
- Gate F: Template Customize Content preview and future-section propagation are verified or isolated as a separate follow-up before MER-5620 is considered complete.
- Gate G: Targeted tests, formatting, and regression checks pass before PR submission.

## Decision Log

### 2026-06-18 - Reset Remaining Phase Order After Vertical Slice
- Change: Documented that the initial working vertical slice completed Phase 2 plus parts of Phase 3 and Phase 4, marked completed UI/bundle checkpoints, and clarified the remaining ordered work.
- Reason: Implementation and manual Figma review moved ahead of the original phase boundaries; the plan needed to reflect reality before continuing phase-by-phase.
- Evidence: `assets/src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx`, `assets/src/apps/InstructorPreviewComponents.tsx`, `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`, `lib/oli_web/delivery/instructor/activity_bank_selection_preview.ex`, and `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: Next implementation should close Phase 4 hardening, then implement Phase 5 warning banner/modal behavior, then verify templates and final QA without expanding MER-5620 scope.

### 2026-06-18 - Close Phase 4 Remove/Restore Contract
- Change: Marked Phase 4 hardening and coverage complete for non-warning Activity Bank Selection remove/restore.
- Reason: LiveView now returns reasoned `ok: false` replies for invalid bank-selection events, tests assert the LiveView reply contract for remove/restore/error cases, and restore replies use the original available count instead of the removed-state effective count.
- Evidence: `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`, `lib/oli_web/delivery/instructor/activity_bank_selection_preview.ex`, `lib/oli_web/delivery/instructor/preview_page_context.ex`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: Phase 5 can now layer warning banner and confirmation modal behavior on top of a hardened mutation dispatcher without changing the basic remove/restore contract.

### 2026-06-18 - Close Phase 5 Warning Flow
- Change: Marked Phase 5 complete for Course Section instructor preview.
- Reason: The LiveView now renders scored/practice future-attempt warning banners, stores pending preview customization actions when warning confirmation is required, applies the pending action only after confirmation, clears pending state on cancel, and pushes the confirmed reply back through the existing preview customization browser event path.
- Evidence: `lib/oli/delivery/attempts/core.ex`, `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`, `assets/src/hooks/instructor_preview_customization.ts`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: Phase 6 can focus on template/scope verification without changing the Course Section warning interaction contract.

### 2026-06-22 - Clarify Template-Level Phase 6 Scope
- Change: Reframed Phase 6 around the Product/Template Customize Content flow and future-section propagation.
- Reason: Template-level UI reaches the existing instructor-style preview through blueprint section page Edit links, so the remaining risk is whether activity exclusion state saved on the blueprint section is inherited by newly created course sections without affecting already-created sections.
- Evidence: Product/Template Customize Content page Edit URLs target `/sections/:blueprint_slug/preview/lesson/:revision_slug` with a product remix `return_to`, including `/workspaces/course_author/:project_slug/products/:product_slug/remix`.
- Impact: Phase 6 should verify or implement propagation of `section_page_activity_exclusions` from template blueprint sections to future course sections, rather than adding a separate template UI surface.

### 2026-06-23 - Use Existing Template Exclusion Duplication
- Change: Reconciled Phase 6 after rebasing over the core template-exclusion duplication work.
- Reason: The section duplication path already calls `InstructorCustomizations.duplicate_section_exclusions/2`, so MER-5620 should rely on that implementation instead of carrying duplicate blueprint-copying logic.
- Evidence: `lib/oli/delivery/sections/blueprint.ex` and `test/oli/delivery/sections/blueprint_test.exs`.
- Impact: MER-5620 keeps the template preview UI verification and product remix `return_to` fix, while template-to-section exclusion copying remains owned by the core duplication implementation.
