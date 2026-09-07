# Reward and Evidence Slice

## Scope

This slice owns scored-page eligibility, transactional reward handoff persistence, atomic posterior updates, idempotency, detailed evidence dispatch, and operational telemetry in Phase 5 and the evidence portion of Phase 7.

## Authoritative Attempt Contract

- A scored page attempt is successfully finalized only when `resource_attempts.lifecycle_state == :evaluated`.
- `:active` and `:submitted` are pending states. A submitted attempt may already contain scores while manual grading remains incomplete; it still blocks later attempts.
- Canonical persisted order is `attempt_number ASC`, with `id ASC` as a deterministic defensive tie-breaker. Attempt numbers are allocated from the prior maximum, but the database currently lacks uniqueness on `(resource_access_id, attempt_number)`; Phase 2 must characterize legacy duplicates before adding a constraint or retaining the tie-break-only safeguard.
- Score validity is separate from finality: reward processing requires numeric `score`, numeric `out_of`, and `out_of > 0`, then uses `score / out_of`. Invalid evaluated rows produce a bounded data-integrity disposition.

For a binding/enrollment, inspect eligible resource attempts in canonical order. The first row governs: active or submitted blocks; the first evaluated valid attempt may be accepted; later attempts and reevaluation cannot replace it.

## Handoff Boundary

Automatic finalization, manual grading, and auto-submit retain their existing attempt and snapshot flows. After a resource attempt becomes evaluated, each path performs one bounded section-level check for an active Thompson Sampling experiment. A negative result returns immediately. A positive result processes the reward inside the current learner-attempt transaction using persisted server state, never a client-selected assignment, score, or condition.

Reward-processing failure rolls back the learner-attempt transaction. Snapshot processing does not mutate experiment state; after commit it reads `AcceptedReward` and attaches the reward attribution to the one authoritative page-attempt statement.

## Reward Transaction

The worker derives the assessment binding, enrollment, page score, canonical attempt order, and persisted assignment. Missing assignment records a skip and never creates or infers one.

One PostgreSQL reward transaction:

1. locks the decision-point policy row;
2. claims unique `(assessment_binding_id, enrollment_id)` and `(assessment_binding_id, resource_attempt_id)` reward identity;
3. computes `normalized_score >= threshold` using inclusive decimal comparison;
4. increments only the assigned condition's alpha or beta and aggregate accepted counts;
5. persists the accepted reward used to enrich the authoritative snapshot statement.

Duplicate work returns the existing disposition. Distinct concurrent rewards serialize on the policy row without lost updates. Evidence delivery cannot mutate posterior state.

## Evidence Storage and Dispatch

`AcceptedReward` is the durable source used to build reward attribution during snapshot processing. The snapshot worker emits no separate compatibility statement and never changes the posterior. The existing xAPI pipeline begins with an in-memory cast; improving durability after that boundary remains a broader analytics concern rather than a second experiment-specific dispatch path.

Extend `priv/clickhouse/migrations/` with a new ordinary goose migration that alters `experiment_attributions`, not `raw_events`. Add nullable typed fields for intervention ID/key, assessment binding ID, assessment page resource ID, resource attempt ID, disposition, threshold, normalized score, and page revision ID. Retain publication ID. Before/after policy context is not part of the ETL or ClickHouse projection and should not be added until a concrete OLAP query requirement justifies the additional storage and ingestion contract. Do not overload `content_revision_id`, which currently identifies the Alternatives revision for exposure.

Update together:

- `Oli.Experiments.XAPI.Attributions`;
- xAPI statement schema;
- direct ClickHouse uploader projection and columns;
- S3/Lambda/backfill projection contract;
- ClickHouse query/report contracts.

Remove unnecessary learner identity from detailed attribution payloads. Attribution hashes remain the sink-side deduplication boundary.

## Telemetry

Emit bounded counts/durations for queue delay, eligibility result, accepted/duplicate/skipped reward, transaction duration, posterior update, and evidence dispatch. Metadata may contain stable experiment/binding/intervention/condition identifiers and bounded reasons, but not raw responses, free-form content, email/name, or unnecessary user identity.

## Test Targets

- Characterize ordering when IDs/timestamps disagree with attempt number and when legacy attempt numbers duplicate.
- Cover active/submitted blockers, eventual transition to evaluated, later attempts, reevaluation, invalid score fields, and thresholds `0.0`, `1.0`, exact boundary, and below boundary.
- Prove rollback produces no job and success produces exactly one resource-attempt job for automatic and manual finalization.
- Cover missing assignment, duplicate/replayed work, transaction rollback, and concurrent distinct rewards.
- Test learner-attempt rollback on reward failure, snapshot sink deduplication, and proof that snapshot retry never changes posterior state.
- Retain the existing two-query batch context characterization until the resource-attempt eligibility query replaces the activity-attempt shape.
