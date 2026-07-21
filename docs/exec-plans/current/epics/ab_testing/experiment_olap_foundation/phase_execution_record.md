# Phase Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation`
Phase: `all phases`

## Scope from plan.md
- Implement canonical experiment xAPI contracts, runtime emission, ClickHouse ingest, query contracts, dataset-compatible event selection, observability, and PostgreSQL event-table removal.
- Update `plan.md` checkboxes as tasks are completed.

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
- 2026-07-16 design reconciliation: PRD, FDD, plan, and requirements updated to model
  experiment evidence as `experiment_attributions` on existing page, attempt, and media xAPI
  host events, with attribution-level ClickHouse extraction.

## Review Loop
- Round 1 findings: `$harness-review` security, performance, and Elixir review found one
  transactional side-effect issue: policy update xAPI emission could run before the reward
  transaction committed.
- Round 1 fixes: moved policy update xAPI emission to the post-commit reward success path while
  keeping policy state mutation under the assignment and policy locks.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
