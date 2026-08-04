# Phase Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation`
Phase: `all phases, including Phase 7 attribution type preservation`

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
- 2026-08-03 Phase 7: added orthogonal `attribution_type` to current builders, all three
  ingest paths, ClickHouse storage/query contracts, xAPI schema validation, manual QA, and
  requirements traceability. Because the epic is pre-deployment, the field is required at
  every boundary and no compatibility inference is retained for earlier payloads.

## Review Loop
- Round 1 findings: `$harness-review` security, performance, and Elixir review found one
  transactional side-effect issue: policy update xAPI emission could run before the reward
  transaction committed.
- Round 1 fixes: moved policy update xAPI emission to the post-commit reward success path while
  keeping policy state mutation under the assignment and policy locks.
- Phase 7 review findings: role/type pairs were independently validated and the motivating
  rollup/type distinction lacked cross-ingest assertions. A compatibility concern was initially
  raised, then superseded by confirmation that this epic has not been deployed.
- Phase 7 review fixes: added required role/type relationship constraints and canonical-builder
  validation, updated the original pre-deployment ClickHouse migration directly, and added
  rollup outcome assertions across direct upload, Lambda transformation, and backfill SQL
  generation. Ingest paths fail the statement or backfill query on invalid pairs, consume the
  required field directly, and contain no legacy inference.
- Phase 7 residual verification: executable backfill SQL verification remains open because no
  local ClickHouse service was running; direct uploader tests, Lambda transform assertions,
  generated-SQL contract assertions, and migration task tests pass locally.
- 2026-08-04 dev/QA remediation: added
  `priv/clickhouse/scripts/20260804_backfill_experiment_attribution_type.sql` to upgrade
  already-initialized non-production ClickHouse databases without a reset. The script maps
  direct roles to themselves, media to assignment, reward rollups via `reward_source`, remaining
  rollups to outcome, validates all rows, enforces the final non-null type, and materializes the
  skip index. It is retry-safe after partial failure but intentionally documented as a one-time,
  off-peak operation because successful reruns would rematerialize the index.
- 2026-08-04 dev/QA remediation follow-up: ClickHouse requires an explicit `DEFAULT` expression
  when converting a nullable column to a non-nullable type even after all null rows are removed.
  The script now supplies a temporary empty-string default for the conversion and removes it in
  the following statement so the final schema still requires producers to provide the field.

## Done Definition
- [x] Phase tasks complete
- [ ] Tests and verification pass; executable ClickHouse backfill verification remains open
- [x] Review completed when enabled
- [x] Validation passes
