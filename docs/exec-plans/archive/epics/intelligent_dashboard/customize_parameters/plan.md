# Customize Student Support Parameters - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/fdd.md`
- Requirements: `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/requirements.yml`
- Jira: `MER-5256`

## Scope
Deliver section-scoped Student Support parameter customization for instructors. The implementation includes backend persistence and validation, projector parameterization, LiveView modal/save orchestration, a narrow `phx-hook` for the SVG threshold matrix, immediate Student Support reprojection after successful save, and targeted tests for `AC-001` through `AC-007`.

Out of scope:
- Per-instructor parameter preferences.
- Editable comparator logic.
- Reworking Student Support bucket taxonomy beyond configurable threshold values.
- New feature flag rollout unless product explicitly requests staged exposure.
- Caching projection payloads outside current LiveView assigns.

## Clarifications & Default Assumptions
- Default storage choice is a new section-scoped `student_support_parameter_settings` table, not `instructor_dashboard_states`, because the latter is enrollment-scoped.
- Current dashboard caches store oracle payloads only; threshold changes require LiveView projection rederive, not oracle cache eviction.
- Baseline UI architecture is LiveView modal state plus `StudentSupportParametersMatrix` `phx-hook`; React is a fallback only if UI workflow proves the hook boundary too small.
- Last successful save wins for concurrent instructors.
- The Figma/UI workflow runs before UI coding and may refine visual structure, copy, tokens, focus behavior, and whether the hook boundary is sufficient.
- Scenario tests are not the default for this slice; use ExUnit, LiveView tests, and Jest unless implementation uncovers a broader authoring/delivery workflow dependency.

## Phase 1: Persistence & Parameter Service
- Goal: Establish the authoritative section-scoped settings model and backend validation contract for `AC-002`, `AC-003`, `AC-004`, and `AC-007`.
- Tasks:
  - [ ] Add migration for `student_support_parameter_settings` with `section_id`, inactivity days, threshold fields, timestamps, unique section index, and check constraints.
  - [ ] Add `Oli.InstructorDashboard.StudentSupportParameterSettings` schema with changeset validations for allowed inactivity values, 0-100 thresholds, and non-overlap rules.
  - [ ] Add `Oli.InstructorDashboard.StudentSupportParameters` service with defaults, `get_active_settings/1`, `save_for_section/3`, and `to_projector_opts/1`.
  - [ ] Add AppSignal/telemetry counters or bounded logging for save failure at the service boundary.
  - [ ] Keep queries scoped by trusted section id; do not accept client-supplied section ids.
- Testing Tasks:
  - [ ] Add context/schema tests for defaults, insert, update/upsert, unique section behavior, validation failures, and persistence shared across two instructors.
  - [ ] Add tests that failed saves preserve existing persisted settings.
  - Command(s): `mix test test/oli/instructor_dashboard_test.exs`
- Definition of Done:
  - Section settings can be saved and reloaded independently of instructor enrollment.
  - Defaults are returned without creating a row when no section settings exist.
  - Invalid ranges/non-overlap combinations return changeset errors.
- Gate:
  - Backend tests for the settings service pass.
  - No UI or projection code depends on unvalidated client payloads.
- Dependencies:
  - PRD and FDD accepted.
- Parallelizable Work:
  - UI workflow prep can start in parallel after migration field names are stable, but UI coding should wait for Phase 2 and Phase 3 contracts.

## Phase 2: Projector & Projection Integration
- Goal: Make Student Support derivation consume active section settings while preserving default behavior for existing sections (`AC-003`, `AC-004`, `AC-005`).
- Tasks:
  - [ ] Extend or formalize `Projector.build/3` options so custom inactivity days and threshold rules use the service's normalized projector opts.
  - [ ] Update `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.derive/2` to resolve active settings from the snapshot's section context.
  - [ ] Include active settings in the projection payload so the tile can render current threshold labels and modal defaults.
  - [ ] Preserve current default bucket behavior when no settings row exists.
  - [ ] Keep projector logic pure and cache unaware.
- Testing Tasks:
  - [ ] Add projector tests for custom thresholds moving students between buckets.
  - [ ] Add projector tests for custom inactivity days changing active/inactive counts.
  - [ ] Add projection tests proving persisted settings override defaults and no-row sections retain existing defaults.
  - Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/projections/student_support_projector_test.exs test/oli/instructor_dashboard/data_snapshot/projections/student_support_test.exs`
- Definition of Done:
  - Student Support projection output is parameterized by active section settings.
  - Existing sections with no row produce the same classification as before.
  - Projection data includes enough settings metadata for the tile/modal display.
- Gate:
  - Projection and projector tests pass.
  - No projection output is cached outside current dashboard bundle assigns.
- Dependencies:
  - Phase 1 service API available.
- Parallelizable Work:
  - Phase 3 UI workflow can run while projector tests are being finalized, using the FDD and field names from Phase 1.

## Phase 3: Figma/UI Workflow Alignment
- Goal: Resolve design implementation details before coding the modal and matrix (`AC-001`, `AC-002`, `AC-006`, `AC-007`).
- Tasks:
  - [ ] Run the repo-local Figma-backed UI workflow (`ui_workflow` or `implement_ui`) against the Jira/Figma link in `informal.md`.
  - [ ] Capture modal structure, token mapping, icon choice, focus behavior, validation/error copy, keyboard behavior, and responsive constraints.
  - [ ] Confirm that LiveView modal plus `phx-hook` matrix remains the simplest adequate implementation; document any reason to escalate to React.
  - [ ] Update `fdd.md` and this plan if the design workflow changes implementation boundaries.
- Testing Tasks:
  - [ ] Add or update planned UI verification notes for focus trap, Esc/outside-click behavior, keyboard matrix movement, and screen-reader labels.
  - Command(s): `python3 /Users/nicocirio/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters --check plan`
- Definition of Done:
  - UI implementation brief exists or durable notes are added to the work item.
  - LiveView/hook vs React decision is confirmed before UI implementation.
  - Validation/error copy is no longer ambiguous for development.
- Gate:
  - User/design acceptance of the UI approach, or explicit documented fallback.
- Dependencies:
  - Phase 1 field names stable.
  - Figma/Jira assets accessible.
- Parallelizable Work:
  - Backend Phase 2 can continue in parallel; LiveView/modal coding should wait for this phase's output.

## Phase 4: LiveView Save Flow & Reprojection
- Goal: Wire save/cancel behavior and immediate Student Support projection replacement without evicting oracle caches (`AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`).
- Tasks:
  - [ ] Add LiveView/component events for opening, cancelling, draft updates, and saving support parameters.
  - [ ] Store modal draft state in LiveView assigns and reset it from active settings on open/cancel.
  - [ ] On save, call `StudentSupportParameters.save_for_section/3` with trusted section context and actor metadata.
  - [ ] After successful save, rebuild the current snapshot/projection for `:student_support` from existing `dashboard_oracle_results` where available.
  - [ ] Replace `dashboard_bundle_state.projections.student_support`, `dashboard_bundle_state.projection_statuses.student_support`, and `dashboard.student_support_projection`.
  - [ ] On persistence or reprojection failure, keep previous projection active and show actionable error feedback.
  - [ ] Emit `support_parameters.saved`, `support_parameters.save_failed`, and `support_parameters.reprojection_failed` telemetry/AppSignal signals.
- Testing Tasks:
  - [ ] Add LiveView tests for open/cancel/no-persist behavior.
  - [ ] Add LiveView tests for save success causing rendered Student Support output to update from rederived projection.
  - [ ] Add LiveView tests for save failure preserving prior settings/projection and showing an error.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
- Definition of Done:
  - Save applies only after persistence succeeds.
  - Cancel/Esc/outside dismissal leaves persisted settings and tile output unchanged.
  - Post-save tile output uses new settings without clearing oracle caches.
- Gate:
  - LiveView tests pass and no broad dashboard refetch is required for the happy path.
- Dependencies:
  - Phases 1 and 2 complete.
  - Phase 3 confirms UI behavior enough for event contracts.
- Parallelizable Work:
  - Phase 5 hook implementation can proceed once event names and payload shape are fixed.

## Phase 5: Modal UI & Matrix Hook
- Goal: Implement the instructor-facing modal and SVG threshold interaction with LiveView-owned draft state (`AC-001`, `AC-002`, `AC-006`, `AC-007`).
- Tasks:
  - [ ] Add `Edit parameters` affordance and tooltip to `StudentSupportTile`.
  - [ ] Add modal markup with inactivity controls, group range controls, numeric inputs, Save/Cancel, validation feedback, and accessible labels.
  - [ ] Add `assets/src/hooks/student_support_parameters_matrix.ts` and register it in `assets/src/hooks/index.ts`.
  - [ ] Implement client-local pointer/keyboard movement and final-value commit only on movement end.
  - [ ] Ensure numeric inputs remain usable if the hook fails to mount.
  - [ ] Ensure the hook does not send per-pointermove events to LiveView.
  - [ ] Apply design tokens and accessibility behavior from Phase 3.
- Testing Tasks:
  - [ ] Add Jest tests for value-to-position mapping, pointer commit payload, keyboard movement, boundary constraints, and no pointermove push events.
  - [ ] Extend LiveView tests for modal render, validation feedback, and fallback numeric input behavior.
  - Command(s): `cd assets && yarn test path/to/student_support_parameters_matrix.test.ts`
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
- Definition of Done:
  - Modal opens from the tile with current section settings.
  - Matrix interactions update draft values only on committed movement.
  - All threshold controls are keyboard operable and bounded.
  - Save/Cancel behavior matches backend contracts.
- Gate:
  - Targeted Jest and LiveView tests pass.
  - Manual keyboard/focus check completed.
- Dependencies:
  - Phase 3 UI workflow.
  - Phase 4 event contract.
- Parallelizable Work:
  - Hook unit tests can be developed in parallel with HEEx modal markup once payload shape is agreed.

## Phase 6: End-to-End Verification & Cleanup
- Goal: Prove the full feature meets requirements and repository quality gates.
- Tasks:
  - [ ] Run targeted backend, projection, LiveView, and hook tests.
  - [ ] Run `mix format` for Elixir changes.
  - [ ] Run frontend format/lint/test commands for hook changes as scope warrants.
  - [ ] Verify no stale projection remains after save in the current LiveView session.
  - [ ] Verify another instructor in the same section sees saved settings on fresh dashboard load.
  - [ ] Update `requirements.yml` proofs only when implementation is complete.
  - [ ] Prepare review notes covering security, performance, telemetry, and UI/accessibility.
- Testing Tasks:
  - [ ] Run all targeted commands from previous phases.
  - [ ] Run broader dashboard test file if multiple LiveView paths changed.
  - Command(s): `mix test test/oli/instructor_dashboard_test.exs test/oli/instructor_dashboard/data_snapshot/projections/student_support_projector_test.exs test/oli/instructor_dashboard/data_snapshot/projections/student_support_test.exs test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs`
  - Command(s): `mix format`
  - Command(s): `cd assets && yarn test path/to/student_support_parameters_matrix.test.ts`
- Definition of Done:
  - `AC-001` through `AC-007` have automated coverage or documented manual/accessibility verification.
  - No unrelated dashboard cache behavior regresses.
  - Feature is ready for review against security, performance, Elixir, and UI guidelines.
- Gate:
  - All targeted tests and format/lint gates pass, or failures are documented with blockers.
- Dependencies:
  - Phases 1 through 5 complete.
- Parallelizable Work:
  - Review prep and manual accessibility notes can be collected while final test runs execute.

## Parallelization Notes
- Backend persistence (Phase 1) and UI workflow (Phase 3) can overlap after field names stabilize.
- Projector integration (Phase 2) can proceed independently from the modal hook once the settings service returns normalized projector opts.
- LiveView save/reprojection (Phase 4) should not start before Phase 2 because it depends on a reliable `:student_support` projection rederive.
- Matrix hook work (Phase 5) can overlap with LiveView modal markup after event names and payload shapes are fixed.
- Final verification (Phase 6) should be serialized after all implementation phases because it validates cross-boundary behavior.

## Phase Gate Summary
- Gate A: Settings persistence works section-wide, validates invalid payloads, and preserves defaults.
- Gate B: Student Support projection derives buckets from active settings and preserves default behavior for old sections.
- Gate C: Figma/UI workflow confirms LiveView + hook approach or documents a necessary fallback.
- Gate D: LiveView save flow persists first, reprojects current Student Support state, and handles failures without partial apply.
- Gate E: Modal and hook satisfy keyboard, drag, validation, and no-per-pointermove-event expectations.
- Gate F: Targeted backend, LiveView, Jest, and formatting gates pass before review.
