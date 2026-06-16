# Activity Bank Selection Preview Customization - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/ui_core/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/ui_core/fdd.md`
- Requirements: `docs/exec-plans/current/epics/instructor_customizations/ui_core/requirements.yml`

## Scope

Implement the MER-5620 Activity Bank Selection preview experience for instructors in Course Sections. The work includes the new Activity Bank Selection preview UI from Figma, whole-selection remove/restore through the existing LiveView/React preview customization contract, future-attempt warning behavior, and regression protection for already-merged embedded activity remove/restore.

The plan does not include reimplementing embedded activity remove/restore, individual bank candidate management, bulk candidate operations, authored content mutation, or retrospective attempt rewrites.

## Clarifications & Default Assumptions

- Course Sections are the primary implementation target.
- Template preview likely reuses the Course Section path through blueprint sections. The plan verifies that before adding template-specific work.
- The Activity Bank Selection preview needs a real new UI component/layout; it is not only a remove/restore button added to the old `activity_bank/preview.html.heex` page.
- The existing user-facing preview URL should be preserved where practical: `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id`.
- `Oli.Delivery.InstructorCustomizations` remains the authority for validation, persistence, and page-scoped exclusion state.
- Warning eligibility must be based on server-side section/page data and must not expose learner-specific details.
- No feature flag is planned by default. Telemetry is limited to existing logging/AppSignal paths unless a reusable instructor customization event already exists.

## Phase 1: Surface And Data Discovery

- Goal: Confirm exact implementation boundaries before moving UI and route ownership.
- Tasks:
  - [ ] Trace the current Activity Bank Selection preview entry points from page preview links to `ActivityBankController.preview/2` and `activity_bank/preview.html.heex`.
  - [ ] Map the legacy selection renderer in `lib/oli/rendering/content/selection.ex`, including how it builds the jumbotron display and preview link.
  - [ ] Confirm whether template preview reaches the same section preview route through `Oli.Delivery.TemplatePreview` and blueprint section launch.
  - [ ] Identify where Activity Bank Selection points-per-question and authored criteria should be read for display.
  - [ ] Identify the cheapest reliable scored-attempt and practice-visit signals for warning eligibility.
  - [ ] Confirm which activity preview rendering path can be reused for the sample question.
  - [ ] Record any route or data differences that would force template support into a later phase.
- Testing Tasks:
  - [ ] Add or update focused tests only if discovery requires a small helper for warning eligibility or selection metadata extraction.
  - Command(s): `mix test <targeted_test_file>`
- Definition of Done:
  - The implementation target route, metadata sources, warning signals, and template routing assumption are confirmed.
  - Any newly introduced helper has targeted test coverage.
- Gate:
  - Do not start route migration until the current selection preview inputs and required display metadata are mapped.
- Dependencies:
  - Existing PRD/FDD and local route/controller/template context.
- Parallelizable Work:
  - Figma/UI mapping can proceed in parallel with warning-signal discovery.

## Phase 2: LiveView-Owned Selection Preview Shell

- Goal: Move the Activity Bank Selection preview surface under LiveView ownership while preserving existing navigation behavior.
- Tasks:
  - [ ] Add or adapt a LiveView for Activity Bank Selection preview under `lib/oli_web/live/delivery/instructor/`.
  - [ ] Preserve the existing user-facing section preview URL where practical.
  - [ ] Port current controller responsibilities into the LiveView: authorization, page revision resolution, selection lookup, Activity Bank query, paging, activity scripts, previous/next context, bibliography params, and scheduled-resource state.
  - [ ] Mount the `InstructorPreviewCustomization` hook on the LiveView root.
  - [ ] Keep malformed/not-found/not-authorized behavior aligned with the current preview route.
  - [ ] Keep the old controller/template only where still needed by a different non-section surface.
  - [ ] If the old controller/template path is no longer referenced after route migration, remove it instead of keeping an unused fallback.
- Testing Tasks:
  - [ ] Add LiveView mount/render tests for authorized instructor/admin access.
  - [ ] Add LiveView tests for not-found and unauthorized paths.
  - [ ] Add a route/navigation regression test if route ownership changes from controller to LiveView.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/<selection_preview_live_test>.exs`
- Definition of Done:
  - The selection preview page renders through LiveView with the same required data available as the old controller page.
  - The hook is present and ready for preview customization events.
- Gate:
  - Do not implement remove/restore mutation before LiveView owns the preview surface.
- Dependencies:
  - Phase 1 route and data discovery.
- Parallelizable Work:
  - Frontend component scaffolding can proceed in parallel if props are stable enough.

## Phase 3: Activity Bank Selection Preview UI

- Goal: Implement the Figma-backed Activity Bank Selection preview UI as a first-class selection-level preview, not as a button-only patch.
- Tasks:
  - [ ] Create a dedicated Activity Bank Selection preview component or LiveView-rendered partial.
  - [ ] Replace or bypass the legacy `Oli.Rendering.Content.Selection` jumbotron output for Instructor Preview with the new Figma-backed selection UI.
  - [ ] Render heading/title, available-question count, select count, points per question, authored criteria, and one sample question.
  - [ ] Reuse existing preview primitives where they fit: action button styling, status pill, removed treatment, rich text rendering, and sample activity rendering.
  - [ ] Keep the sample question visible and keyboard-operable in both active and removed states.
  - [ ] Add success-message placement above the affected selection.
  - [ ] Apply approved hover, focus, disabled, and responsive states.
  - [ ] Avoid per-candidate render loops; use existing queried rows or a limit-1 sample query.
- Testing Tasks:
  - [ ] Add render tests for required metadata and sample question visibility.
  - [ ] Add frontend Jest tests if a new React component is introduced.
  - [ ] Add accessibility-oriented assertions for labels/focusable controls where practical.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/<selection_preview_live_test>.exs`
  - Command(s): `cd assets && yarn test <targeted_preview_component_test>`
- Definition of Done:
  - AC-001 and AC-011 are covered by automated tests where practical and by a manual Figma comparison note.
  - The UI can represent active and removed states without relying on domain mutation yet.
- Gate:
  - Do not wire mutation replies until the component/partial can render state from server-owned preview context.
- Dependencies:
  - Phase 2 LiveView shell and stable preview context shape.
- Parallelizable Work:
  - Backend remove/restore event handler shape can be drafted in parallel after the target payload is fixed.

## Phase 4: Whole-Selection Remove/Restore Wiring

- Goal: Route Activity Bank Selection remove/restore through the shared preview customization contract into the core instructor customization implementation.
- Tasks:
  - [ ] Emit `bank_selection` customization intents with `pageResourceId` and `selectionId` from the selection preview UI.
  - [ ] Handle `toggle_preview_activity_customization` for `bank_selection` in the owning LiveView.
  - [ ] Validate current page resource id and selection id before writes.
  - [ ] Dispatch remove to `InstructorCustomizations.exclude_bank_selection/4`.
  - [ ] Dispatch restore to `InstructorCustomizations.restore_bank_selection/4`.
  - [ ] Rebuild server-owned selection preview context after writes.
  - [ ] Return targeted success replies with `actions`, `visualState`, `statusPill`, and updated available count.
  - [ ] Return `ok: false` replies for stale, malformed, unauthorized, or domain-error cases.
  - [ ] Keep embedded activity remove/restore behavior untouched.
- Testing Tasks:
  - [ ] Add LiveView tests for remove, restore, stale page id, missing selection id, and domain error behavior.
  - [ ] Assert available count updates to 0 on remove and returns on restore.
  - [ ] Assert local reply shape satisfies the shared contract.
  - [ ] Add regression coverage that embedded activity remove/restore still works in its existing LiveView.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/<selection_preview_live_test>.exs`
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
- Tasks:
  - [ ] Implement or reuse a server-side helper that detects existing scored assessment attempts for the current section/page.
  - [ ] Implement or reuse a server-side helper that detects existing practice page visits for the current section/page.
  - [ ] Render the exact scored warning copy when applicable.
  - [ ] Render the exact practice warning copy when applicable.
  - [ ] Add warning modal state to the owning LiveView.
  - [ ] Store pending remove/restore action when confirmation is required.
  - [ ] Apply the pending action only after instructor confirmation.
  - [ ] Clear pending action on cancel or failed validation.
  - [ ] Ensure warning checks do not expose learner identity or attempt details to the browser.
- Testing Tasks:
  - [ ] Add tests for scored warning copy.
  - [ ] Add tests for practice warning copy.
  - [ ] Add tests that remove/restore does not persist until warning confirmation.
  - [ ] Add tests that canceling warning confirmation leaves state unchanged.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/<selection_preview_live_test>.exs`
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

- Goal: Verify template behavior and lock down page/section scoping guarantees.
- Tasks:
  - [ ] Exercise the template preview launch path and confirm whether it reaches the Course Section LiveView through a blueprint section slug.
  - [ ] If template preview uses the same route, document that no extra implementation is required.
  - [ ] If template preview uses a separate surface, wire that surface in a small follow-up phase using the same event contract and domain APIs.
  - [ ] Verify removing a selection in one section/template scope does not affect other sections.
  - [ ] Verify removing a selection on one page does not affect another page.
  - [ ] Verify authored revisions and existing learner progress are not modified.
- Testing Tasks:
  - [ ] Add a template-preview smoke test if the route can be exercised cheaply.
  - [ ] Add scope tests for page isolation and section/template isolation.
  - [ ] Add scenario coverage if the workflow proof needs authoring, publishing, section delivery, and future attempt creation.
  - Command(s): `mix test <targeted_template_or_scope_test>`
  - Command(s): `mix test test/scenarios/<targeted_scenario_runner>.exs`
- Definition of Done:
  - AC-010 is verified for Course Sections and, where route-compatible, template preview.
  - Any template-only work is either implemented through the same contract or explicitly deferred with evidence.
- Gate:
  - Do not close MER-5620 until template scope has been verified or a separate template surface has been identified and planned.
- Dependencies:
  - Phase 4 persisted remove/restore behavior.
- Parallelizable Work:
  - Scenario coverage can be prepared while manual template route verification is underway.

## Phase 7: Final Verification, Review Prep, And Cleanup

- Goal: Finish with targeted automated coverage, formatting, manual QA notes, and review-ready scope.
- Tasks:
  - [ ] Remove obsolete controller/template code only if Phase 2 confirms it is no longer used.
  - [ ] Remove obsolete selection-rendering branches only if active references prove they are no longer needed by authoring, delivery, template, or preview surfaces.
  - [ ] Confirm no new feature flag or migration is required.
  - [ ] Confirm no learner-specific data is logged or rendered.
  - [ ] Confirm UI text, warning copy, and action labels match requirements.
  - [ ] Confirm embedded activity remove/restore regression coverage still passes.
  - [ ] Prepare PR notes with Course Section behavior, template verification result, warning behavior, and test evidence.
- Testing Tasks:
  - [ ] Run all targeted LiveView/context tests touched by the implementation.
  - [ ] Run targeted frontend tests if React code changed.
  - [ ] Run formatters for touched Elixir and TypeScript files.
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
- Template route verification can run in parallel with scope tests after persisted whole-selection customization works.
- Final PR notes can be drafted while targeted automated tests run.

## Phase Gate Summary

- Gate A: Route, metadata, warning-signal, and template-entry assumptions are confirmed before route migration.
- Gate B: Activity Bank Selection preview is LiveView-owned before remove/restore wiring begins.
- Gate C: New selection UI renders required metadata and states before mutation replies are connected.
- Gate D: Basic whole-selection remove/restore works before warning confirmation is layered in.
- Gate E: Warning behavior is covered for scored attempts and practice visits before final UI verification.
- Gate F: Template scope is verified or isolated as a separate follow-up before MER-5620 is considered complete.
- Gate G: Targeted tests, formatting, and regression checks pass before PR submission.
