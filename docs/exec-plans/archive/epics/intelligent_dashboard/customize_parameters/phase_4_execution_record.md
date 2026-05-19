# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters`
Phase: `4 - LiveView Save Flow & Reprojection`

## Scope from plan.md
- Wire server-side open/cancel/draft/save behavior for Student Support parameters.
- Persist first, then rederive only the current Student Support projection from existing oracle results.
- Preserve the active projection on save or reprojection failure.

## Implementation Blocks
- [x] Core behavior changes
  - Added `IntelligentDashboardTab.handle_student_support_parameters_opened/1`.
  - Added `IntelligentDashboardTab.handle_student_support_parameters_cancelled/1`.
  - Added `IntelligentDashboardTab.handle_student_support_parameters_draft_updated/2`.
  - Added `IntelligentDashboardTab.handle_student_support_parameters_saved/2`.
  - Save uses the trusted socket section id and current actor, then rederives `:student_support` using current `dashboard_oracle_results`.
  - Successful save replaces `dashboard_bundle_state.projections.student_support`, `dashboard_bundle_state.projection_statuses.student_support`, and `dashboard.student_support_projection`.
  - Failed save or failed reprojection preserves the previous active projection.
- [x] Data or interface changes
  - Added LiveView event delegates for `student_support_parameters_opened`, `student_support_parameters_cancelled`, `student_support_parameters_draft_updated`, and `student_support_parameters_saved`.
  - Changed dashboard snapshot assembly to tolerate string request tokens via `to_string/1`, matching the bundle request token shape already stored in assigns.
- [x] Access-control or safety checks
  - Save does not accept client-supplied section id.
  - Draft updates whitelist known parameter fields and ignore unknown keys.
  - Backend validation remains authoritative through `StudentSupportParameters.save_for_section/3`.
- [x] Observability or operational updates when needed
  - Added AppSignal counter for save success.
  - Added AppSignal counter and bounded warning log for reprojection failure.

## Test Blocks
- [x] Tests added or updated
  - Added open/update/cancel draft test proving no persistence occurs before Save.
  - Added save-success test proving settings persist and the rendered dashboard payload gets the rederived Student Support projection.
  - Added save-failure test proving settings/projection are preserved.
  - Added reprojection-failure test proving persisted settings remain while active projection is not replaced.
- [x] Required verification commands run
  - `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_save_flow_test.exs`
  - `mix test test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_save_flow_test.exs test/oli/instructor_dashboard_test.exs test/oli/instructor_dashboard/data_snapshot/projections/student_support_projector_test.exs test/oli/instructor_dashboard/data_snapshot/projections/student_support_test.exs`
- [x] Results captured
  - Save-flow tests: `4 tests, 0 failures`.
  - Combined dashboard/settings/projection tests: `58 tests, 0 failures`.
  - Test startup emitted the existing unrelated `Inventory recovery failed` sandbox ownership log in one targeted run; ExUnit completed successfully.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No document divergence found.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
  - Security/performance/Elixir local review found one telemetry cardinality concern: AppSignal tags used the full dashboard scope selector, which can include many container ids.
- Round 1 fixes:
  - Replaced the metric tag with low-cardinality `dashboard_scope_type` values (`course` or `container`).
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
