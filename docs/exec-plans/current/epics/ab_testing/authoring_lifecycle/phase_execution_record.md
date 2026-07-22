# Phase Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle`
Phase: `1-5`

## Scope from plan.md
- Implement project-level weighted random A/B Testing authoring and lifecycle management through `Oli.Experiments`.
- Keep Thompson Sampling unavailable from authoring with disabled/coming-soon UI and backend rejection.
- Preserve compatibility for existing provider-shaped authored experiment revisions without JSON workflow controls.

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

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
