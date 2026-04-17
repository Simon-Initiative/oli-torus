# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/intelligent_dashboard/summary_tile`
Phase: `4 - Hardening, Verification, And Closeout`

## Scope from plan.md
- Reconcile the summary recommendation boundary with the merged `MER-5305` contract.
- Finish targeted telemetry/logging hardening and broader regression verification.
- Tighten any temporary assumptions that were acceptable before the recommendation backend landed.

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

## Implementation Summary
- Replaced the summary tile's default runtime recommendation adapter with a real adapter backed by `Oli.InstructorDashboard.Recommendations`, so regenerate and thumbs interactions now use the merged `MER-5305` lifecycle service instead of a no-op placeholder.
- Normalized merged recommendation payloads at the summary boundary:
  - backend integer ids are converted to string `recommendation_id` values for LiveView event round-trips
  - backend states such as `:generating`, `:no_signal`, and `:fallback` are mapped to the tile-facing `:thinking`, `:beginning_course`, and bounded ready/unavailable states
  - viewer-specific `feedback_summary` now suppresses sentiment controls after a submission for the current recommendation
- Fixed a live interaction crash in summary recommendation telemetry/logging caused by `get_in/2` on struct assigns during real LiveView event handling.
- Updated work-item docs to remove pre-merge assumptions about `MER-5305` and to record the resolved recommendation oracle key/payload posture.

## Review Loop
- Round 1 findings:
  - The merged `MER-5305` backend contract used integer ids and backend lifecycle states that did not match the summary tile's provisional UI-facing contract, creating a stale-id risk for regenerate/thumbs interactions after the rebase.
  - Summary interaction telemetry accessed struct assigns through `get_in/2`, which crashes on real LiveView clicks.
- Round 1 fixes:
  - Added a real summary recommendation adapter and payload normalization layer at the tab/projection boundary.
  - Replaced struct-unsafe telemetry/log field access with explicit assign field extraction.

## Verification Results
- `mix test test/oli/instructor_dashboard/data_snapshot/projections/summary_projector_test.exs test/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile_test.exs test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs:440 test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs:478` -> `54 tests, 0 failures`
- `mix test test/oli/instructor_dashboard/data_snapshot/projections test/oli_web/live/delivery/instructor_dashboard` -> `251 tests, 0 failures`
- `python3 /Users/santiagosimoncelli/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/intelligent_dashboard/summary_tile --check all` -> `Work item validation passed.`
- `python3 /Users/santiagosimoncelli/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/intelligent_dashboard/summary_tile --action master_validate --stage plan_present` -> `fdd references verified`, `plan references verified`

## Residual Risks
- Manual QA against Jira/Figma for light, dark, and thinking states still needs a human pass before ticket close.
- The work item docs now reflect the merged recommendation contract, but if `MER-5305` changes its normalized payload again, the summary adapter remains the intended single reconciliation point.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
