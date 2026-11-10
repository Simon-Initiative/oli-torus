# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/preview_components`
Phase: `2`

## Scope from plan.md
- Extend the Instructor View rendering pipeline so supported activities use first-class preview metadata while unsupported activities keep the legacy authoring-derived path.
- Populate preview-aware `ActivitySummary` fields, assemble a stable `preview_context`, and load only the scripts required by the page.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed
Notes:
- Extended `ActivitySummary` with preview-specific fields and updated `PageDeliveryController.render_page_preview/3` to assemble preview-aware summaries and a per-page union of required scripts.
- Updated `Oli.Rendering.Activity.Html` and `Oli.Rendering.Activity.Plaintext` to prefer preview elements in Instructor View while falling back per activity to legacy authoring elements.
- Added a stable server-to-client `preview_context` that includes rendering identity, display metadata, and a neutral `customizationTarget`.
- Added targeted warning logs when a Jira-scoped supported activity falls back to the legacy authoring path.
- Fixed a review-discovered N+1 by pre-resolving activity objective titles in a single batch before building preview contexts.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured
Verification:
- `mix format`
- `mix test test/oli/rendering/activity/html_test.exs test/oli/rendering/activity/plaintext_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
Results:
- Targeted renderer and controller tests passed: `72 tests, 0 failures`.
- Added new coverage for:
  - preview-element rendering in `Oli.Rendering.Activity.Html`
  - supported-activity fallback warnings in `Html` and `Plaintext`
  - mixed-page script selection in `PageDeliveryController`

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
Notes:
- No PRD/FDD/plan drift was introduced by Phase 2 implementation.
- The only remaining documented open question is still the final expanded design for `Likert`.

## Review Loop
- Round 1 findings: `PageDeliveryController.render_page_preview/3` initially resolved activity objectives inside the per-activity loop, which would have introduced an Instructor View N+1 query pattern on mixed pages.
- Round 1 fixes: Batched objective resolution into `preview_objective_titles_by_activity_id/2` and kept `build_preview_context/6` read-only and in-memory.
- Round 2 findings (optional): No further material security, performance, or correctness issues remained after the batching fix.
- Round 2 fixes (optional): None required.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
