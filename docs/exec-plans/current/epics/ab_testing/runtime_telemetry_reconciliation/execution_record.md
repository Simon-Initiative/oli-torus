# Runtime Telemetry Reconciliation - Execution Record

## Implementation Summary

Changed runtime code:
- Added `Oli.Experiments.Telemetry` for experiment xAPI statement construction and emission.
- Wired `Oli.Experiments` assignment, exposure, outcome, reward, and Thompson Sampling policy-update paths to emit experiment xAPI statements after successful runtime writes.
- Preserved PostgreSQL idempotency behavior while marking reused exposure/outcome/reward receipts with `[:oli, :experiments, :xapi, :emit, :skipped_duplicate]` telemetry instead of duplicate xAPI events.
- Classified PostgreSQL aggregate helpers in `Oli.Experiments` as operational-only through function docs.

Changed tests:
- Added statement-builder and privacy tests in `test/oli/experiments/telemetry_test.exs`.
- Extended runtime tests for assignment/reuse xAPI events, duplicate suppression, policy-update emission, and xAPI failure rollback safety.
- Added `test/oli/experiments/coupling_test.exs` to block non-experiment product code from direct temporary event-table coupling.

Changed docs:
- Added `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/reconciliation.md`.
- Marked all implementation plan phase checkboxes complete in `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/plan.md`.

## XAPI Event List

Implemented event types:
- `experiment_assigned`
- `experiment_assignment_reused`
- `experiment_exposed`
- `experiment_outcome_recorded`
- `experiment_reward_recorded`
- `experiment_policy_updated`

Each statement includes scoped identifiers, event type, idempotency key, and event-specific references. Policy-update statements include compact previous/next state hashes instead of full policy state.

## Security Review Notes

Reviewed payload construction in `Oli.Experiments.Telemetry`:
- Raw learner responses are not copied from outcome metadata into xAPI statements.
- Learner names and LMS identifiers are not included.
- Full policy state is not included; only SHA-256 hashes are emitted.
- Telemetry metadata carries non-sensitive IDs, event type, algorithm/version where available, and hashed idempotency keys.
- Runtime emits only after `Oli.Experiments.Scope` validation succeeds in the owning context.

## Performance Review Notes

Reviewed delivery/runtime hot paths:
- No direct S3 or ClickHouse network work was added to delivery transactions.
- Runtime still performs the existing bounded PostgreSQL writes needed for operational state and idempotency.
- xAPI emission delegates to the existing `Oli.Analytics.XAPI` pipeline.
- Product analytics coupling to PostgreSQL event-history tables is blocked by `test/oli/experiments/coupling_test.exs` and documented as a review blocker.

## Table Removal Gate

Jira/release tracking note:
- `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` remain temporary operational scaffolding only.
- `experiment_olap_foundation` should own the replacement xAPI/ClickHouse projection and replacement runtime idempotency contract.
- The final drop migration may land in `experiment_olap_foundation`, `analytics`, or manual QA readiness work, but it is required before `analytics` or `manual_qa` can be marked complete.

## Verification

Commands run:
- `mix test test/oli/experiments/telemetry_test.exs test/oli/experiments/runtime_test.exs test/oli/experiments/analytics_test.exs test/oli/experiments/coupling_test.exs test/oli/analytics/xapi/schema_validator_test.exs`
- `mix format`
- `rg -n "durable.*PostgreSQL|PostgreSQL.*analytics|experiment_exposures|experiment_outcomes|experiment_rewards|experiment_policy_updates" docs/exec-plans/current/epics/ab_testing`
- `rg -n "experiment_exposures|experiment_outcomes|experiment_rewards|experiment_policy_updates|Oli\\.Experiments\\.Schemas\\.(Exposure|Outcome|Reward|PolicyUpdate)|assignment_counts\\(|exposure_counts\\(|reward_counts\\(|experiment_summary\\(" lib test`
- `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --action verify_plan`
- `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --action master_validate --stage plan_present`
- `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --check plan`

Result:
- Targeted tests passed.
- Formatting passed.
- Harness trace and validation passed.
- Reference scans found only expected owning-context, schema, test, and supersession/removal-gate references.
