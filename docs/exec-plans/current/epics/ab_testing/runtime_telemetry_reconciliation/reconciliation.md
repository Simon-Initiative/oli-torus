# Runtime Telemetry Reconciliation Note

## Disposition Summary

Keep as PostgreSQL operational state:
- `experiment_definitions`: experiment identity, lifecycle, scope, and policy configuration.
- `experiment_decision_points`: delivery-time alternatives matching.
- `experiment_conditions`: active condition configuration and condition codes.
- `experiment_assignments`: sticky learner/enrollment assignment state and assignment idempotency.
- `experiment_policy_states`: current Thompson Sampling policy state required for runtime assignment.

Modify and retain temporarily as operational scaffolding:
- `experiment_exposures`: current exposure idempotency and reward eligibility support only.
- `experiment_outcomes`: current evaluated-attempt association and outcome idempotency support only.
- `experiment_rewards`: current reward idempotency and policy-update input support only.
- `experiment_policy_updates`: current duplicate-posterior-update guard and short-term operational audit only.

Remove before MVP completion:
- `experiment_exposures`
- `experiment_outcomes`
- `experiment_rewards`
- `experiment_policy_updates`

Defer to downstream slices:
- ClickHouse experiment projections, materialized views, query contracts, monitoring queries, dashboards, reports, dataset exports, and backfill tooling.

## Current Boundary

`Oli.Experiments` remains the only owner of native A/B testing PostgreSQL tables. Runtime APIs may write temporary event-history rows while the replacement idempotency path is being introduced, but those rows are not durable analytics history.

`Oli.Experiments.Telemetry` emits durable experiment history through `Oli.Analytics.XAPI.emit(:experiment, ...)` for:
- `experiment_assigned`
- `experiment_assignment_reused`
- `experiment_exposed`
- `experiment_outcome_recorded`
- `experiment_reward_recorded`
- `experiment_policy_updated`

Product dashboards, reports, exports, and aggregate analytics must use xAPI/ClickHouse-derived read paths from downstream slices, not PostgreSQL event-history tables or the temporary runtime aggregate helpers in `Oli.Experiments`.

## Caller Inventory

Allowed PostgreSQL callers:
- `Oli.Experiments` may read and write private schemas for runtime correctness, idempotency, and operational inspection.
- `lib/oli/experiments/schemas/*` defines table mappings and changesets.
- `test/oli/experiments/*` may verify runtime behavior and coupling gates.

Blocked callers:
- Delivery, authoring, analytics, dataset export, dashboard, report, and monitoring modules must not alias or query `Oli.Experiments.Schemas.Exposure`, `Outcome`, `Reward`, or `PolicyUpdate`.
- Product analytics code must not query `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates`.

Enforcement:
- `test/oli/experiments/coupling_test.exs` scans non-experiment `lib/**/*.ex` files for private event schema/table coupling.
- `Oli.Experiments` aggregate function docs classify PostgreSQL counts as operational-only, not product analytics APIs.

## Removal Readiness Checklist

Before the drop migration can land, `experiment_olap_foundation` and downstream analytics work must prove:
- Experiment xAPI statements land in durable JSONL and ClickHouse with stable event type and idempotency fields.
- ClickHouse projections or query APIs cover assignment, assignment reuse, exposure, outcome, reward, and policy-update history.
- Dataset export and dashboard/report queries read from ClickHouse-backed contracts.
- Runtime exposure/outcome/reward/policy-update idempotency no longer depends on the temporary event-history rows.
- Thompson Sampling posterior updates remain protected from duplicate rewards without `experiment_rewards` or `experiment_policy_updates`.
- Backfill/replay behavior can rebuild ClickHouse experiment history from xAPI JSONL.
- Coupling checks still prevent new product analytics reads from PostgreSQL event-history tables.

Recommended owner:
- `experiment_olap_foundation` owns the replacement xAPI/ClickHouse projection and idempotency contract.
- The actual drop migration may land in `experiment_olap_foundation`, `analytics`, or `manual_qa` readiness work, but it is a required MVP gate before `analytics` or `manual_qa` can be marked complete.

## Review Notes

Security review must verify that xAPI statements and telemetry metadata do not include learner names, LMS identifiers, raw learner responses, full policy state, or full request payloads.

Performance review must verify that runtime xAPI emission uses the existing pipeline and does not add direct S3 or ClickHouse network work to delivery transactions.
