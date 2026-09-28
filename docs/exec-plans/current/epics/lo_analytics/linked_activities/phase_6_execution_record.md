# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/lo_analytics/linked_activities`
Phase: `6 - Close the Acceptance Criteria Test Gaps`

## Scope from plan.md

- [x] Close the AC-004, AC-005, AC-010, AC-019, and AC-020 test gaps.
- [x] Make no production-code changes in this phase.

## Implementation Blocks

- [x] Core behavior changes: none; this phase is test-only by design.
- [x] Data or interface changes: none.
- [x] Access-control or safety checks: no production behavior changed.
- [x] Observability or operational updates: none.

## Test Blocks

- [x] Expanded-detail coverage now checks the question-details heading, the established no-attempt content, both correctness summaries, and the shared detail renderer content including Answer Key, Hints, Explanation, Dynamic Variables, answer distribution, First Try Correct, and Eventually Correct.
- [x] Linked table sorting is covered for `title` and `total_attempts` in ascending and descending directions.
- [x] An activity without question-level analytics is asserted to show `No attempt registered for this question`.
- [x] The expansion control is asserted to expose `aria-label` values for both collapsed and expanded states.
- [x] Filtering, sorting, and pagination are asserted to leave rows collapsed.
- [x] Required verification commands run:
  - `mix test test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs test/oli_web/components/delivery/pages/activities_table_model_test.exs --seed 12345` -> `25 tests, 0 failures`.
  - `mix test test/scenarios/linked_activities/linked_activities_test.exs` -> `1 test, 0 failures`.
  - `mix format ...` -> passed.
  - `git diff --check` -> passed.
  - `validate_work_item.py ... --check all` -> passed.
  - `requirements_trace.py ... --action master_validate --stage implementation_complete` -> passed.

## Work-Item Sync

- [x] No PRD, FDD, or plan changes were required; implementation remains within the planned test-only phase.
- [x] No open questions were added.

## Review Loop

- Round 1 findings: no actionable findings. Phase 6 changes are limited to ExUnit coverage; the existing security, performance, Elixir/Phoenix, UI, and requirements review conclusions remain unchanged.
- Round 1 fixes: corrected pagination selectors and added distinct attempt counts so both sort directions are meaningfully exercised.

## Done Definition

- [x] Phase tasks complete.
- [x] Tests and verification pass.
- [x] Review completed when enabled.
- [x] Validation passes.

## Residual Risk

- The suite continues to emit the known asynchronous inventory ownership error and the existing `MultiSelect target={nil}` compile warning; neither failed the required assertions.
- Manual browser verification remains pending because no authenticated Browser MCP session was available in prior phases.
