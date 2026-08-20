# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity`
Phase: `5 - Capture Initial Condition-Assignment Events`

## Scope from plan.md

- Capture one dedicated ClickHouse condition-assignment event per newly persisted assignment.
- Keep sticky assignment reuse silent and preserve the exact persisted assignment timestamp.
- Project the event consistently through direct upload, Lambda, and replay/backfill.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Implementation notes:

- Added a schema-valid `experiment_condition_assigned` xAPI statement and bounded assignment attribution.
- Single and page-batched assignment paths emit only after the assignment transaction commits;
  sticky reuse produces no assignment statement.
- Statement and attribution timestamps come from persisted `experiment_assignments.assigned_at`.
- Direct upload, Lambda, and replay/backfill normalize `experiment_condition_assigned`, preserve the dedicated
  statement hash, and project nullable `assigned_at` plus assignment scope.
- The statement retains the established bounded Torus user-ID actor convention. The attribution
  uses section enrollment as participant identity and excludes user ID, email, LMS identity,
  responses, realized content, and policy state.
- Added bounded failure telemetry for best-effort assignment-statement emission without changing
  the assignment result.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- Final combined Elixir gate: 198 tests, 0 failures, 1 excluded.
- Lambda ETL suite: 26 passed.
- Focused schema/projection gate: 42 tests, 0 failures.
- Canonical assignment direct/replay tests: 27 tests, 0 failures.
- `mix compile`, `mix format`, JSON/schema validation, `git diff --check`, requirements checks, and
  harness validation passed.

## Acceptance-Criteria Traceability

| Criteria | Representative implementation proof | Representative test proof |
| --- | --- | --- |
| AC-015 | `lib/oli/experiments/runtime_assignment.ex`, `lib/oli/experiments.ex`, `lib/oli/analytics/xapi/events/experiment/experiment_condition_assigned.ex`, `lib/oli/experiments/xapi/condition_assignment_emitter.ex` | `test/oli/experiments/runtime_assignment_test.exs`, `test/oli/analytics/xapi/events/experiment/experiment_condition_assigned_test.exs` |
| AC-016 | direct uploader, Lambda transformer, replay query builder, ClickHouse migration, and xAPI schema | shared `test/support/fixtures/experiment_condition_assignment_statement.json` assertions in direct upload, Lambda, and replay tests |

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

No product behavior diverged. The FDD was clarified so actor identity follows the existing xAPI
user-ID convention while the assignment attribution remains enrollment-scoped and excludes direct
learner identity.

## Review Loop

- Round 1 findings: avoidable post-commit assignment reload; enrollment ID incorrectly placed in
  `raw_events.user_id`; missing Thompson/cross-path/hash proof; blank final execution record.
- Round 1 fixes: passed persisted records out of the transaction, restored the bounded user-ID
  actor, added a canonical Thompson statement fixture and hash assertions across ingestion paths,
  and completed traceability/status records.
- Round 2 findings: security, performance, and Elixir re-reviews found no remaining defects.
- Round 2 fixes: none required after the first-round corrections.

## Branch Reconciliation Gate

- [ ] Reconcile onto updated `hotfix-v0.34.1` after prerequisite PRs #6784 and #6786 merge, inspect
  the final-base diff, and rerun this record's verification commands.

This external prerequisite remains pending, so Gate E is not yet fully closed.
Checked on 2026-08-20: PR #6784 is merged into `hotfix-v0.34.1`; PR #6786 remains open.

## Done Definition

- [x] Available Phase 5 implementation tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
- [ ] External branch reconciliation gate passes
