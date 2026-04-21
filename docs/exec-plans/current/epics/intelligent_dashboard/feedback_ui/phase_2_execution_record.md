# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui`
Phase: `2 - LiveView & Summary Tile Interaction Flow`

## Scope from plan.md
- Complete the summary-tile interaction flow for thumbs, additional feedback, and regenerate.
- Add the additional-feedback modal and wire it through the instructor dashboard LiveView/tab flow.
- Preserve regenerate behavior and failure messaging.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
  - Phase 2 QA identified that `Additional feedback` disappeared after navigation because the CTA depended on ephemeral LiveView state. The FDD was updated so CTA rendering is derived from persisted `feedback_summary` for the active recommendation:
    - no persisted sentiment: show thumbs
    - persisted sentiment without qualitative feedback: show `Additional feedback`
    - persisted qualitative feedback: show non-interactive `Additional feedback submitted`
  - Phase 2 QA also identified that the action area should not keep CTAs visible while a recommendation is generating or regenerating. The tile now replaces thumbs / `Additional feedback` / `Additional feedback submitted` with a non-interactive `Thinking...` label and spinner whenever the recommendation is in `:thinking` state or a regenerate request is in flight.

## Review Loop
- Round 1 findings:
  - Summary-tile interaction state was inconsistent across reload/navigation because multiple tab code paths rebuilt `summary_tile_state` with the pre-modal shape.
  - `Additional feedback` visibility was tied only to local state instead of persisted feedback data.
- Round 1 fixes:
  - Normalized summary-tile state handling across tab/pubsub/regenerate paths so modal-related keys survive state transitions safely.
  - Extended viewer `feedback_summary` to include `additional_feedback_submitted?` and switched the tile CTA to derive from persisted feedback state.
- Round 2 findings (current):
  - The action area needed a dedicated loading state during recommendation generation/regeneration so instructors do not see thumbs or feedback actions while the backend is still working.
- Round 2 fixes (current):
  - Replaced the action controls with `Thinking...` plus a spinner during `:thinking` recommendations and while `regenerate_in_flight?` is true.
- Round 3 findings (current):
  - During explicit regeneration with an existing recommendation, the tile body was replaced by generic regenerating copy instead of preserving the last visible recommendation text.
- Round 3 fixes (current):
  - Updated summary-tile body rendering so `:regenerating` keeps the current recommendation text (when present) while still showing `Thinking...` and replacing action controls.
- Round 4 findings (current):
  - Figma does not include status copy in the recommendation header row (next to “AI Recommendation”). The visible header chip and matching `sr-only` strings were leftover from the initial recommendation-oracle / `Oli.InstructorDashboard.Recommendations` prototype, not from the finalized MER-5250 UI.
- Round 4 fixes (current):
  - Removed all header status labels (including `sr-only`) and deleted the unused `status_badge/1` and `recommendation_state_copy/3` helpers from `SummaryTile`. Loading/regeneration is communicated only via the bottom-right `Thinking...` + spinner (plus `aria-busy` on the panel and `role="status"` / `aria-live="polite"` on that indicator). FDD updated under section 4.1.
- Round 3 findings (optional):
- Round 3 fixes (optional):

## Verification Results
- `mix format lib/oli/instructor_dashboard/recommendations.ex lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex test/oli/instructor_dashboard/recommendations_test.exs test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/fdd.md docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/phase_2_execution_record.md`
- `mix test test/oli/instructor_dashboard/recommendations_test.exs test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs` -> passing targeted backend/component/tab coverage
- `mix test test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs` -> passing targeted summary-tile/tab coverage after the `Thinking...` loading-state update
- `mix test test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs` -> passing targeted summary-tile coverage after preserving prior recommendation body during regeneration
- `mix test test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs` -> passing after Round 4 removal of header status / `sr-only` prototype copy (Figma alignment)
- `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs` -> existing unrelated failure remains in assessments tile coverage: `Could not find assessment id for title "Other test revision"`

## Residual Risks
- Full LiveView dashboard coverage still has unrelated async/runtime ownership noise and the pre-existing assessments failure, so Phase 2 confidence comes from targeted summary-tile coverage rather than a clean full-file pass.
- The post-submit confirmation state is currently a non-interactive label after navigation rather than a view/edit surface; that matches current product intent but would need revisiting if the workflow later allows editing qualitative feedback.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [ ] Validation passes
