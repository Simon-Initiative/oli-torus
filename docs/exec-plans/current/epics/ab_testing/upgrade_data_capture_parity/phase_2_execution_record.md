# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity`
Phase: `2 - Restore Focused Non-Page Attribution`

## Scope from plan.md

- Resolve attempt attribution from persisted realized content and durable scoped assignments.
- Preserve weighted-random and Thompson semantics across part, activity, and page host statements.
- Scope attempt-based and resource-only media attribution to the authoritative page resource.
- Preserve host emission on no match, historical content, or safe enrichment failure.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Focused verification:

- `mix test test/oli/delivery/experiments/attempt_attributions_test.exs test/oli/analytics/xapi_test.exs` - 18 tests, 0 failures.
- `mix test test/oli/delivery/experiments test/oli/analytics/xapi_test.exs` - 46 tests, 0 failures.
- `mix compile` - passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no design divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: reviewers identified cross-placement assignment reuse, unsupported-policy fallback, tuple cross-product overfetch, overly broad schema loading, an incompatible preload after projection, and quadratic selected-branch traversal.
- Round 1 fixes: added scope-aware intervention predicates and negative tests, failed unsupported policies safely, correlated placement tuples in SQL, projected only required fields, removed the redundant preload, and replaced generic flattening with a linear collector.
- Final review: security, performance, and Elixir reviewers reported no remaining concrete findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
