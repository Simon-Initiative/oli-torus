# Phase Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle`
Phase: `1-5; Phase 3 FR-006 follow-up`

## Scope from plan.md
- Implement project-level weighted random A/B Testing authoring and lifecycle management through `Oli.Experiments`.
- Keep Thompson Sampling unavailable from authoring with disabled/coming-soon UI and backend rejection.
- Preserve compatibility for existing provider-shaped authored experiment revisions without JSON workflow controls.
- Gate the page-editor Alternatives and A/B Test insert elements by the current project's corresponding authoring settings.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification:
- `mix test test/oli/experiments`
- `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs`
- `mix test test/oli/editing/page_editor_test.exs test/oli_web/controllers/api/resource_controller_test.exs`
- `cd assets && yarn test test/page_editor/non_activities_feature_gating_test.tsx --runInBand`
- `cd assets && yarn check-types`
- `cd assets && yarn eslint src/data/content/resource.ts src/components/content/add_resource_content/NonActivities.tsx test/page_editor/non_activities_feature_gating_test.tsx`
- `mix format`

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

Implementation variance:
- No new `Oli.Scenarios` file was added. The implemented scope is covered by targeted context, runtime, analytics, and LiveView tests. End-to-end publish/delivery scenario coverage remains better suited to the delivery runtime scenario suite when that full workflow is extended.

## Review Loop
- Round 1 findings:
  - Replaced open-ended string-key atom conversion with a strict authoring payload key whitelist.
- Round 1 fixes:
  - Updated `Oli.Experiments.atomize_keys/1` and related validation paths to avoid raising on unknown or missing fields.
  - Added server-side project-feature validation for newly inserted Alternatives content and an explicit HTTP 403 mapping.
  - Limited feature validation traversal to resource-content containers and accumulated identity counts directly to keep page-save overhead bounded.
  - Replaced the partial TypeScript context cast with a complete typed fixture.
  - Added controller-level coverage for the HTTP error contract and synchronized FR-006 plan/evidence records.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
