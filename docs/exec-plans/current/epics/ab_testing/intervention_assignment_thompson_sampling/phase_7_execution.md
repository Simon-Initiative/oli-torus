# Phase 7 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `7 - Preserve Export/Ingest and Emit Detailed Evidence`

## Scope from plan.md

- Preserve canonical Alternatives Group strategy and repeated placement-local content across export/ingest.
- Complete detailed, privacy-safe experiment evidence projection and bounded operational telemetry.

## Implementation Blocks

- [x] Core behavior changes: canonical Alternatives strategy export/ingest and placement rewiring.
- [x] Data or interface changes: detailed xAPI and ClickHouse attribution projection on both direct and backfill paths.
- [x] Access-control or safety checks: evidence excludes direct learner identity and SQL literal escaping covers backslashes and control characters.
- [x] Observability or operational updates when needed: transaction-coupled reward evidence dispatch and bounded AppSignal reward/dispatch metrics.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured: final focused Phase 7 suite passed (100 tests); final legacy-publication subset passed (21 tests); compile, formatting, migration forward/rollback, diff check, and work-item validation passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged: no contract divergence identified.
- [x] Open questions added to docs when needed: none.

## Review Loop

- Round 1 findings: ClickHouse literal escaping for author-controlled intervention keys; retry-time publication/revision drift; domain-to-web hostname dependency; avoidable evidence-query projection.
- Round 1 fixes: escaped backslashes/control characters before quotes; snapshotted project/revision in the transactional job and retained current deployment only as required xAPI host-statement context; moved hostname resolution to neutral analytics configuration; removed publication joins and unused access struct projection. A proposed `resource_attempts.publication_id` addition was removed because exact publication attribution is not currently required.
- Round 2 findings: remaining low-priority evidence-worker struct projection overhead.
- Round 2 fixes (optional): deferred; one evidence row is processed per background job, and the full attempt remains required by statement construction.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
