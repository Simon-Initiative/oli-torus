# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity`
Phase: `4 - Compatibility Proof And Final Verification`

## Scope from plan.md

- Prove the v0.33.0 compatibility dataset independently from causal non-page attribution.
- Cover multiple enrollments, repeated evaluations, multiple activities, branch relationships,
  both weighted-random scopes, and Thompson Sampling without expanding producer scope.
- Complete final verification and reviews, with branch reconciliation gated on prerequisite merges.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Implementation notes:

- Added `priv/clickhouse/queries/upgrade_v033_compatibility.sql`, parameterized by section and time
  range. It ASOF-joins each evaluated activity to the most recent assignment/exposure evidence for
  the same section enrollment and derives only the compatibility correctness value.
- Kept raw `score` and `out_of` untouched. Missing, zero, and non-finite division results map to
  `0.0` only in the compatibility projection.
- Expanded deterministic fixtures and tests to cover three enrollments, repeated evaluation of one
  attempt, five activities, in-branch and out-of-branch rows, intervention and section-enrollment
  weighted-random assignments, and Thompson Sampling.
- Reconfirmed that exact attempt-time publication provenance remains explicitly deferred to
  MER-5889 in `prd.md` and `fdd.md`; no publication behavior changed in this phase.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- `mix test test/oli/analytics/xapi/upgrade_data_capture_parity_contract_test.exs` - 6 tests,
  0 failures.
- `mix test test/oli/delivery/experiments test/oli/analytics/xapi test/oli/analytics/backfill test/oli/analytics/xapi_test.exs` - 116 tests, 0 failures, 1 excluded.
- `cloud/xapi-etl-processor/.venv/bin/python -m pytest cloud/xapi-etl-processor/tests` - 24 passed.
- Local ClickHouse `EXPLAIN` with concrete section/time parameters - passed against the current
  `raw_events` and `experiment_attributions` schemas.
- Final combined rerun with the previously green seed: 119 tests, 0 failures, 1 excluded. This
  followed one transient failure in the timing-sensitive pipeline-drain assertion at
  `test/oli/analytics/xapi/pipeline_test.exs:90`; the complete final-tree retry passed.

## Acceptance-Criteria Traceability

| Criteria | Representative implementation proof | Representative test proof |
| --- | --- | --- |
| AC-001 | `lib/oli/analytics/summary/attempt_group.ex` | `test/oli/analytics/xapi_test.exs` two-section enrollment test |
| AC-002, AC-004, AC-005 | `lib/oli/delivery/experiments/attempt_attributions.ex` | `test/oli/analytics/xapi_test.exs` attempt attribution cases |
| AC-003 | `lib/oli/delivery/experiments/media_attributions.ex` | `test/oli/analytics/xapi_test.exs` media attribution cases |
| AC-006, AC-007 | evaluated-attempt builders and raw projection mappings | `test/oli/analytics/xapi/events/attempt/*_test.exs` and shared parity fixture |
| AC-008, AC-009 | existing experiment runtime plus focused attribution builders | `test/oli/experiments/runtime_test.exs` and `test/oli/analytics/xapi/upgrade_data_capture_parity_contract_test.exs` |
| AC-010 | direct uploader, Lambda transformer, and replay query builder | shared `test/support/fixtures/upgrade_data_capture_parity_statement.json` assertions in all three paths |
| AC-011 | nullable raw mappings and additive ClickHouse migration | historical-field assertions in Elixir and Lambda suites |
| AC-012, AC-013 | `priv/clickhouse/queries/upgrade_v033_compatibility.sql` | compatibility fixture join and query contract tests |
| AC-014 | project/section/user/enrollment-scoped attribution queries | privacy allowlist and cross-placement/project negative tests |

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

No PRD or FDD behavior diverged. The plan records completed Phase 4 work while leaving prerequisite
branch reconciliation pending.

## Review Loop

- Round 1 findings: reviewers found cross-project ASOF matching, an unbounded evidence scan,
  nondeterministic same-timestamp evidence, incomplete query-fidelity fixtures, and missing AC-001
  and AC-010 cross-boundary proofs.
- Round 1 fixes: added project equality and negative evidence, an explicit evidence horizon,
  deterministic `argMax` tie-breaking, full evidence predicate fixtures, a two-section enrollment
  test, and a shared statement contract across direct, Lambda, and replay paths.
- Round 2 findings: no remaining security, performance, Elixir, or implementation/acceptance
  defects. Requirements review requested this concrete traceability table.
- Round 2 fixes: recorded representative implementation and test proof for AC-001 through AC-014.

## 2026-08-20 Reward Projection Follow-Up

- Manual analytics inspection found weighted-random outcome rows whose missing reward was populated
  from the host attempt score.
- Removed that fallback from direct upload, Lambda transformation, and replay/backfill. Only an
  explicit attribution payload value now populates `experiment_attributions.reward_value`.
- Extended the shared parity statement with both a scored outcome lacking reward evidence and an
  explicit `0.0` reward. Direct, Lambda, and replay tests prove null and zero remain distinct.
- Verification: affected Elixir suites passed with 70 tests, 0 failures, 1 excluded; the Lambda
  suite passed with 24 tests; formatting, compilation, diff checks, and work-item validation passed.
- Security, performance, and Elixir reviews found no remaining defects after the explicit-zero
  coverage was added.

## Branch Reconciliation Gate

- [x] Reconcile onto updated `hotfix-v0.34.1` and inspect the final-base diff.

Completed on 2026-08-20 after PR #6784 squash commit `1c14fc71c9` and PR #6786 squash commit
`539b3c98d5` landed. The final-base diff contains only MER-5885 work.

## Done Definition

- [x] Phase implementation tasks complete
- [x] Targeted tests pass
- [x] Review completed when enabled
- [x] Final verification and validation pass
- [x] External branch reconciliation gate passes
