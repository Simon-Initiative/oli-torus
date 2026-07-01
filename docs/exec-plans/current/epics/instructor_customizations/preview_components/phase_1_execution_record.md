# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/preview_components`
Phase: `1`

## Scope from plan.md
- Add preview mode as a first-class third activity mode in manifests, registrations, and bundle generation.
- Keep the work additive and backwards-compatible without changing authoring or delivery behavior.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed
Notes:
- Added nullable preview registration fields, manifest parsing support, registration/projection support, webpack preview bundle generation, and preview manifest blocks for the seven scoped activity types.
- Added placeholder `preview-entry.ts` files so preview bundle generation remains buildable before preview UI implementation lands in later phases.
- No new authorization or mutation surface was introduced in this phase.
- No observability-specific code changes were needed in Phase 1 because this slice only adds registration and bundle infrastructure.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured
Verification:
- `python3 /Users/nicocirio/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/preview_components --check all`
- `mix format`
- `mix test test/oli/activities_test.exs test/oli/activities/manifest_test.exs test/oli/activities/activity_registration_test.exs`
- `cd assets && node -e "const make=require('./webpack.config.js'); const cfg=make({}, {mode:'development'}); const previewKeys=Object.keys(cfg.entry).filter((k)=>k.endsWith('_preview')).sort(); console.log(JSON.stringify(previewKeys, null, 2));"`
Results:
- Work-item validation passed before coding.
- Targeted Elixir tests passed: `37 tests, 0 failures`.
- Webpack entry verification returned the seven expected preview bundles:
  - `oli_check_all_that_apply_preview`
  - `oli_directed_discussion_preview`
  - `oli_image_hotspot_preview`
  - `oli_likert_preview`
  - `oli_multi_input_preview`
  - `oli_multiple_choice_preview`
  - `oli_ordering_preview`

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
Notes:
- No PRD/FDD/plan drift was introduced by Phase 1 implementation.
- The existing open question about `Likert` expanded remains unchanged and still belongs to later phases.

## Review Loop
- Round 1 findings: No material code-review findings for this phase. The change is additive, avoids new writes or authorization paths, and does not introduce query-pattern or performance regressions in the touched code.
- Round 1 fixes: No follow-up fixes required after review.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
