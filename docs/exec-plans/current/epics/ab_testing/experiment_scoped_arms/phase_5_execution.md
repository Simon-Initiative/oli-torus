# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/experiment_scoped_arms`
Phase: `5 - Process Assessment Rewards Atomically and Asynchronously`

## Scope from plan.md

- Replace activity-attempt full-credit handoff with one trusted resource-attempt job after page evaluation commits.
- Resolve canonical attempt eligibility, assessment binding, persisted intervention assignment, threshold reward, and posterior update server-side.

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

No product or architecture divergence was found. Detailed evidence outbox, post-commit dispatch,
and evidence-delivery latency telemetry are explicitly Phase 7 scope. Phase 5 persists accepted
reward identity and committed policy state, while reward worker retry is idempotent.

The superseded activity-attempt/full-credit handoff implementation was removed from
`Oli.Delivery.Experiments.RewardHandoff`. The legacy delivery scenario that invokes that API is
intentionally replaced by the assessment-driven workflow in Phase 8 rather than retained as a
second reward path.

## Review Loop

- Round 1 findings: Queue insertion errors could interrupt already-finalized manual and auto-submit workflows; canonical attempt eligibility was queried once per binding; duplicate work acquired the shared policy lock before the indexed idempotency check; graded finalization performed an avoidable section lookup.
- Round 1 fixes: Made enqueue best-effort after successful evaluation, loaded canonical eligibility once, added a pre-lock accepted-reward fast path while retaining the locked/unique transactional claim, and reused the graded finalization resource access.
- Round 2 findings: The enqueue relevance gate was section-wide; Gate E coverage did not yet prove all threshold, attempt-ordering, rollback/retry, concurrency, and assignment-stability cases; missing-assignment skips were not observable; the Phase 5 plan incorrectly claimed Phase 7 evidence delivery work.
- Round 2 fixes: Restricted enqueue to an indexed active Thompson assessment binding for the attempt's page and section; expanded reward, worker, concurrency, rollback/retry, and lifecycle integration coverage; emitted bounded post-transaction disposition telemetry; and moved detailed evidence dispatch and independent evidence retry explicitly to Phase 7.

## Verification Evidence

- `mix compile --warnings-as-errors`
- `mix test test/oli/delivery/experiments/assessment_reward_handoff_test.exs test/oli/delivery/experiments/reward_handoff_worker_test.exs test/oli/delivery/attempts/page_lifecycle_test.exs test/oli/delivery/attempts/manual_grading_test.exs test/oli/delivery/attempts/auto_submit/worker_test.exs test/oli/experiments/policy_test.exs test/oli/experiments/runtime_test.exs`
- `git diff --check`
- Harness work-item validation with `--check all`

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
