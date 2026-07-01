# AI Recommendation Feedback UI - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/fdd.md`

## Scope
Complete `MER-5250` by finishing the summary-tile feedback loop for instructor AI recommendations. The plan covers prompt-persistence updates on recommendation instances, qualitative feedback persistence plus best-effort Slack delivery, and the LiveView/UI work required to replace thumbs controls with an `Additional feedback` modal flow while preserving existing regeneration behavior and accessibility requirements.

## Clarifications & Default Assumptions
- `recommendation_instances` is the right storage boundary for `original_prompt`.
- `original_prompt` will be persisted as `%{"messages" => [...]}` using the final message list sent to the provider boundary.
- `response_metadata` will be expanded only with data not already stored in first-class columns: `model`, `provider`, `registered_model_id`, `service_config_id`, `provider_usage`, and `fallback_reason`.
- Additional feedback persistence is the primary transaction outcome; Slack is a best-effort notification side effect.
- The additional feedback modal will follow the same LiveView-owned interaction pattern used by the student summary tile thresholds modal.
- Before Phase 2 implementation begins, run the repo-local `ui_workflow` for `MER-5250` so the Figma-backed summary tile and modal changes are guided by the canonical design brief and runtime UI verification flow.

## Phase 1: Recommendation Persistence & Backend Contracts
- Goal: Extend the recommendation domain so generation persists `original_prompt` plus execution metadata, and qualitative feedback can be persisted and routed to Slack through a backend-owned contract.
- Tasks:
  - [ ] Add the `original_prompt` field to `instructor_dashboard_recommendation_instances` via migration and schema updates.
  - [ ] Persist `%{"messages" => [...]}` at the final request assembly boundary for implicit generation and explicit regeneration.
  - [ ] Enrich `response_metadata` with `model`, `provider`, `registered_model_id`, and `service_config_id` without duplicating first-class columns.
  - [ ] Add a backend helper/service path for `additional_text` feedback that persists the feedback row and sends a Slack payload through `Oli.Slack`.
  - [ ] Expand the summary recommendation adapter contract to support qualitative feedback submission.
- Testing Tasks:
  - [ ] Add or update ExUnit coverage for recommendation instance persistence, metadata normalization, and qualitative feedback persistence/Slack side effects.
  - Command(s): `mix test test/oli/instructor_dashboard/recommendations/persistence_test.exs test/oli/instructor_dashboard/recommendations_test.exs test/oli/slack_test.exs`
- Definition of Done:
  - Recommendation rows persist `original_prompt` and the agreed execution metadata.
  - Additional feedback can be submitted through a backend API/contract without involving LiveView-specific logic.
  - Slack failures do not roll back persisted feedback.
- Gate:
  - Backend persistence and contract tests pass.
- Dependencies:
  - Existing `MER-5249`/`MER-5305` recommendation generation flow on this branch.
- Parallelizable Work:
  - Slack payload formatting tests can proceed in parallel with migration/schema work.

## Phase 2: LiveView & Summary Tile Interaction Flow
- Goal: Complete the dashboard interaction flow so thumbs submission swaps to `Additional feedback`, modal submission works accessibly, and regeneration behavior remains intact.
- Tasks:
  - [ ] Run `ui_workflow` for `MER-5250` in planning mode and use its canonical brief/runtime state as the design source of truth for the summary-tile and modal implementation.
  - [ ] Update the summary tile to render tooltip-backed thumbs/regenerate controls with the required accessible names and to swap thumbs controls for `Additional feedback` after sentiment submission.
  - [ ] Add additional-feedback modal state and events in the instructor dashboard LiveView/tab flow using the existing dashboard modal interaction pattern.
  - [ ] Wire modal submit/cancel/open events to the backend adapter and preserve focus-return behavior.
  - [ ] Keep regenerate behavior intact, including preserving the visible recommendation when regeneration fails.
  - [ ] Add success/error flashes or announcements consistent with the agreed best-effort Slack posture.
- Testing Tasks:
  - [ ] Add focused LiveView tests for thumbs submission, modal open/cancel/submit, success messaging, and regeneration failure preserving prior recommendation text.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Instructors can submit thumbs, open and submit/cancel additional feedback, and regenerate recommendations from the summary tile.
  - The modal is keyboard operable, focus-managed, and consistent with existing dashboard modal patterns.
  - The UI remains stable when Slack fails after feedback persistence.
- Gate:
  - Targeted LiveView tests for summary-tile interactions pass.
- Dependencies:
  - Phase 1 adapter and backend submission contract.
  - `ui_workflow` planning pass completed for `MER-5250`.
- Parallelizable Work:
  - Accessibility copy/tooltips and modal markup can be implemented in parallel with LiveView event wiring once the event names are fixed.

## Phase 3: Regression Coverage, Validation & Doc Proofs
- Goal: Close the feature with regression coverage, artifact validation, and requirement proofs.
- Tasks:
  - [ ] Review whether payload normalization or telemetry sanitization needs updates so new metadata is persisted but not leaked through public payloads beyond the intended keys.
  - [ ] Record proof commands and outcomes in `requirements.yml` if the team expects traceability updates after implementation.
  - [ ] Re-run Harness validation for the work item after code and doc changes settle.
- Testing Tasks:
  - [ ] Run the narrowest complete automated suite covering backend persistence, Slack integration, and instructor dashboard LiveView behavior.
  - Command(s): `mix test test/oli/instructor_dashboard/recommendations/persistence_test.exs test/oli/instructor_dashboard/recommendations_test.exs test/oli/slack_test.exs test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Regression tests covering the implemented behavior pass.
  - Work item docs remain aligned with final implementation.
  - No unresolved design questions remain for this scope.
- Gate:
  - Tests and work-item validation pass together.
- Dependencies:
  - Phase 1 and Phase 2 completed.
- Parallelizable Work:
  - Requirements proof updates and Harness validation can run in parallel with final manual verification.

## Parallelization Notes
- Backend prompt-persistence work and Slack payload formatting/tests are the safest Phase 1 parallel slices.
- Within Phase 2, summary tile rendering changes and LiveView event handlers can overlap once the adapter contract and modal state shape are settled.
- Full-suite verification should wait until both backend and LiveView slices are integrated.

## Phase Gate Summary
- Gate A: Recommendation persistence and qualitative feedback backend contract are implemented and covered by targeted ExUnit tests.
- Gate B: Summary tile interaction flow, modal accessibility behavior, and regeneration UX are covered by targeted LiveView tests.
- Gate C: Final targeted regression suite and Harness work-item validation pass with docs aligned to implementation.
