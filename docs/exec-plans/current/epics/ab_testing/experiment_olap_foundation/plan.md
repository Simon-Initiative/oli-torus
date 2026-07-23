# Experiment XAPI And OLAP Foundation - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/requirements.yml`

## Scope
Deliver the xAPI/OLAP foundation for native A/B testing so experiment exposure, outcome, reward, rollup, media-interaction, and policy-update evidence is represented through existing xAPI host events and operational telemetry, ingested into ClickHouse through production/local/backfill paths, queryable through approved attribution contracts, available to dataset exports, and no longer dependent on PostgreSQL event-history tables.

This plan explicitly includes the final removal of `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` from `priv/repo/migrations/20260625120000_create_experiment_tables.exs`. It does not include final dashboard UX, advanced metric-query language parity, new adaptive policies, or a new analytics service.

## Clarifications & Default Assumptions
- No feature flag is planned for this work item; rollout is controlled by dependency order, migration safety, tests, and review gates.
- Existing xAPI host events carry optional `experiment_attributions` arrays. `raw_events` remains one row per xAPI statement; attribution-level analytics use a compact `experiment_attributions` projection/table keyed by `raw_event_hash`, with detailed page/activity/part/attempt/media context read by joining back to `raw_events.event_hash`.
- `Oli.Experiments` remains the synchronous runtime source for definitions, decision points, conditions, sticky assignments, and current policy state.
- ClickHouse lag must never block learner-facing assignment, exposure, outcome, reward, or policy-update flows.
- Reward duplicate protection must be replaced before `priv/repo/migrations/20260625120000_create_experiment_tables.exs` is updated to omit the event-history tables; recreating a broad PostgreSQL event-history table is outside scope.
- Code review must include security and performance lenses, with backend and requirements review also expected because this work changes Elixir/Ecto, Python ETL, ClickHouse schema, and planning artifacts.
- Jira should track this slice before downstream analytics work begins.

## Phase 1: Attribution Contract And Runtime Telemetry Hardening
- Goal: Make experiment attribution on existing xAPI statements canonical, privacy-safe, and independent of soon-to-be-removed event-history schemas.
- Tasks:
  - [x] Audit `Oli.Experiments.Telemetry` statement builders against FR-001 and AC-001.
  - [x] Finalize canonical `experiment_attributions` extension shape, required attribution fields, attribution roles, and host-event mapping for page views, part attempts, activity/page attempts, and media events.
  - [x] Refactor attribution builders so exposure/outcome/reward/rollup/media attribution can be built from request structs, receipts, retained assignment/policy state, and plain policy-update result structs or maps rather than `%Exposure{}`, `%Outcome{}`, `%Reward{}`, or `%PolicyUpdate{}`.
  - [x] Extend or version the xAPI statement schema to allow experiment attribution arrays on existing host events.
  - [x] Preserve existing xAPI pipeline emission for host events and confirm no direct S3/ClickHouse write is introduced in runtime paths.
  - [x] Add privacy assertions for learner names, emails, LMS identifiers, raw responses, full request payloads, and full policy state.
- Testing Tasks:
  - [x] Add/adjust ExUnit tests for experiment attribution on page, attempt, and media host statement types, required fields, timestamps, and privacy exclusions.
  - [x] Add schema validation tests for host xAPI statements with zero, one, and multiple experiment attributions.
  - [x] Add tests that xAPI emission failures do not roll back runtime state where covered by current runtime boundaries.
  - Command(s): `mix test test/oli/experiments/telemetry_test.exs test/oli/analytics/xapi/schema_validator_test.exs`
- Definition of Done:
  - AC-001 is covered by tests or documented statement fixtures.
  - AC-002 is covered for the runtime emission boundary, excluding later table-removal behavior.
  - Experiment attribution builders no longer require the event-history Ecto schemas as input.
- Gate:
  - Do not start PostgreSQL schema-removal work until canonical attribution payloads are stable and tests prove the extension contract.
- Dependencies:
  - Existing `Oli.Experiments.Telemetry`, runtime request structs, receipt structs, and xAPI pipeline.
- Parallelizable Work:
  - ClickHouse migration design in Phase 2 can begin after attribution field names are stable.

## Phase 2: ClickHouse Schema, ETL, Local Upload, And Backfill
- Goal: Ensure experiment attributions on existing xAPI events land in ClickHouse with compact, queryable attribution-level columns through all ingest paths.
- Tasks:
  - [x] Add a ClickHouse migration under `priv/clickhouse/migrations/` for raw attribution summary support and a compact attribution-level projection/table, following `priv/clickhouse/AGENTS.md`.
  - [x] Add ClickHouse indexes or projections only where justified by attribution query contracts and supported by ClickHouse.
  - [x] Update `Oli.Analytics.XAPI.ClickHouseUploader` to transform host statements with `experiment_attributions` into attribution projection rows or equivalent queryable fields.
  - [x] Update `cloud/xapi-etl-processor/lambda_function.py` to extract the same attribution fields into Parquet/ClickHouse insert columns.
  - [x] Update `Oli.Analytics.Backfill.QueryBuilder` so S3 JSONL replay extracts attribution fields into the same ClickHouse projection.
  - [x] Ensure `raw_event_hash` plus attribution identity semantics prevent replayed JSONL from inflating experiment counts.
  - [x] Add representative shared fixtures for host xAPI statements with zero, one, and multiple experiment attributions, including media events where practical.
  - [ ] Follow up with cross-ingest parity tests or a shared extraction contract for direct upload, Lambda ETL, and backfill SQL. Known variation points are event-type detection, page-view verb handling, timestamp conversion, hash canonicalization, source metadata defaults, and scalar/JSON type coercion.
- Testing Tasks:
  - [x] Add ClickHouse migration tests or SQL assertions for goose statement boundaries and expected columns.
  - [x] Add direct uploader tests for page exposure, part-attempt outcome/reward, rollup, media attribution, and policy-update projection transforms.
  - [x] Add Python Lambda ETL tests for attribution extraction and validation failure handling.
  - [x] Add backfill query builder tests for attribution extraction from S3 JSONL.
  - Command(s): `mix test test/oli/analytics/xapi/clickhouse_uploader_test.exs test/oli/analytics/backfill/query_builder_test.exs test/mix/tasks/clickhouse_migrate_test.exs`
  - Command(s): `cd cloud/xapi-etl-processor && pytest tests`
- Definition of Done:
  - AC-003 is covered for production ETL, local direct upload, and backfill/replay paths.
  - ClickHouse schema changes are additive, retry-safe, and aligned with existing `raw_events` conventions.
  - Attribution projection rows keep stable experiment query dimensions and avoid duplicating detailed host/media/attempt fields that are already available on `raw_events`.
  - Known direct-uploader/Lambda/backfill transform variations are documented for later parity hardening.
- Gate:
  - Do not implement dashboard/report/export query contracts until ClickHouse ingest can be proven from deterministic fixtures.
- Dependencies:
  - Phase 1 canonical attribution fields and host-event mapping.
- Parallelizable Work:
  - Runtime idempotency design tasks in Phase 3 can proceed in parallel after Phase 1 stabilizes attribution contracts.

## Phase 3: Runtime Idempotency Replacement And Event-Table Decoupling
- Goal: Replace all runtime behavior that currently depends on `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`.
- Tasks:
  - [x] Identify every caller and query path that reads or writes `Exposure`, `Outcome`, `Reward`, or `PolicyUpdate` schemas.
  - [x] Add required operational fields to retained tables, limited to reward duplicate-protection state on `experiment_assignments`.
  - [x] Rewrite delivery page setup so experiment-backed alternatives decisions and exposure attributions are prepared before `page_viewed`; rendering consumes the precomputed decision map instead of assigning or recording exposure during render.
  - [x] Rewrite `record_exposure/1` to validate assignment scope, return a deterministic `ExposureReceipt`, and make exposure attribution available to `page_viewed` without inserting `experiment_exposures` or retaining exposure state in PostgreSQL.
  - [x] Rewrite `reward_eligible_assignments/3` to use sticky assignment state plus page-content branch matching instead of joining `experiment_exposures` or requiring retained exposure state.
  - [x] Rewrite `record_outcome/1` to make outcome attribution available to evaluated part-attempt xAPI and return a deterministic `OutcomeReceipt` without inserting `experiment_outcomes` or retaining outcome state in PostgreSQL.
  - [x] Rewrite `record_reward/1` to use the replacement duplicate reward guard, update current policy state, make reward attribution available to evaluated part-attempt xAPI, and emit policy-update operational telemetry/projection evidence without inserting `experiment_rewards` or `experiment_policy_updates`.
  - [x] Remove or replace PostgreSQL-backed analytics helpers that depend on event-history tables.
  - [x] Update receipt/request structs where needed, including replacing or making optional `RecordRewardRequest.outcome_id`.
  - [x] Update coupling checks to treat any new runtime, analytics, dashboard, report, or export reference to the four event-history tables as a blocker.
- Testing Tasks:
  - [x] Update runtime tests for assignment, stateless exposure/outcome receipts, reward duplicate calls, reward eligibility, and Thompson Sampling policy-state updates.
  - [x] Add repeated reward handoff tests proving duplicate reward calls do not double-update posterior state.
  - [x] Add tests proving exposure/outcome attribution receipts, reward attribution, and policy-update projection evidence are produced without inserting rows into the removed-table schemas.
  - [x] Add coupling tests for removed schema/table references outside migration history and schema assertion code.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/policy_test.exs test/oli/delivery/experiments/reward_handoff_test.exs test/oli/experiments/coupling_test.exs`
- Definition of Done:
  - AC-002 and AC-007 are covered for runtime behavior and duplicate policy-update protection.
  - No runtime code requires `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates`.
- Gate:
  - Do not update `20260625120000_create_experiment_tables.exs` to omit the event-history tables until duplicate reward protection, reward eligibility, and policy-state update tests pass without the event-history schemas.
- Dependencies:
  - Phase 1 attribution contract.
  - Operational-field changes should be applied to the existing native A/B testing migration when the final schema is known.
- Parallelizable Work:
  - ClickHouse query contracts in Phase 4 can start once Phase 2 attribution fixtures exist, but final query contract tests should wait for Phase 3 idempotency semantics.

## Phase 4: ClickHouse Query Contracts, Data Quality, And Observability
- Goal: Provide approved ClickHouse-backed read contracts and operational signals for downstream analytics, monitoring, and exports.
- Tasks:
  - [x] Add an internal experiment ClickHouse analytics module behind `Oli.Experiments` or `Oli.Analytics` boundaries.
  - [x] Implement scoped query contracts for experiment attribution counts, assignment share, reward summary, policy-update history, and data-quality checks.
  - [x] Ensure queries scope by institution/project/section/publication/experiment as appropriate before returning data.
  - [x] Ensure query contracts count distinct `raw_event_hash`-plus-attribution identities or otherwise respect ClickHouse deduplication semantics.
  - [x] Add data-quality checks for missing exposure, missing outcome/reward evidence, delayed policy updates, ETL lag, ClickHouse query failures, and ingest failures.
  - [x] Add telemetry events and AppSignal-safe metadata for query success/failure, validation failures, ETL lag, missing evidence, and export failures.
  - [x] Remove or rewrite any remaining product analytics usage of PostgreSQL event-history aggregate helpers.
- Testing Tasks:
  - [x] Add query contract tests using ClickHouse stubs or deterministic query assertions.
  - [x] Add tests for scope rejection and no direct PostgreSQL event-history table usage.
  - [x] Add telemetry tests for privacy-safe metadata and failure cases.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/analytics/clickhouse_analytics_test.exs test/oli/analytics/clickhouse_query_validator_test.exs`
- Definition of Done:
  - AC-004 is covered by ClickHouse-backed read contracts and coupling tests.
  - AC-006 is covered for observability and data-quality signals.
- Gate:
  - Dataset/export integration should not proceed until query contracts are scoped and do not rely on PostgreSQL event-history tables.
- Dependencies:
  - Phase 2 ClickHouse ingest.
  - Phase 3 runtime idempotency semantics.
- Parallelizable Work:
  - Dataset/export planning can proceed in parallel; implementation should consume finalized query contracts.

## Phase 5: Dataset Export Integration
- Goal: Make experiment evidence available through the existing dataset/export infrastructure using ClickHouse-backed experiment data.
- Tasks:
  - [x] Extend dataset configuration or query generation so experiment attribution rows can be selected with host event type and attribution role filters.
  - [x] Ensure dataset exports include exposure, outcome/reward, rollup, media attribution, and policy-update evidence from ClickHouse.
  - [x] Preserve existing dataset job lifecycle, status updates, manifest handling, notifications, and anonymization defaults where applicable.
  - [x] Ensure dataset export code does not query `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates`.
  - [x] Add export failure telemetry with privacy-safe metadata.
- Testing Tasks:
  - [x] Add dataset configuration/query tests for experiment attribution inclusion.
  - [x] Add tests proving export paths read ClickHouse-backed contracts and not PostgreSQL event-history tables.
  - [x] Add tests for anonymization/privacy expectations where experiment identifiers and learner/enrollment references are exported.
  - Command(s): `mix test test/oli/analytics/datasets_test.exs test/oli/experiments/coupling_test.exs`
- Definition of Done:
  - AC-005 is covered by automated tests.
  - Dataset export integration is ready for downstream analytics/manual QA evidence.
- Gate:
  - Do not mark this phase complete until export paths are covered by coupling tests and privacy checks.
- Dependencies:
  - Phase 4 query contracts.
- Parallelizable Work:
  - Final migration preparation in Phase 6 can proceed once Phase 3 has removed runtime code references.

## Phase 6: Squashed Migration Cleanup And Release Verification
- Goal: Update the existing native A/B testing PostgreSQL migration to the final schema and prove runtime, analytics, and export paths no longer depend on the temporary event-history tables.
- Tasks:
  - [x] Update `priv/repo/migrations/20260625120000_create_experiment_tables.exs` so it does not create `experiment_policy_updates`, `experiment_rewards`, `experiment_outcomes`, or `experiment_exposures`.
  - [x] Ensure all retained operational fields needed for reward duplicate protection are present in that same migration, without exposure/outcome state or policy-update idempotency breadcrumbs.
  - [x] Remove obsolete Ecto schema modules, aliases, tests, and helper functions for the dropped tables.
  - [x] Remove or rewrite PostgreSQL-backed experiment analytics functions that cannot operate without the dropped tables.
  - [x] Add schema assertions or migration tests proving the final native A/B testing migration does not create the four temporary event-history tables.
  - [x] Re-run coupling checks against runtime, analytics, dashboard, report, and export code.
  - [x] Perform an end-to-end controlled native experiment validation: assignment, exposure on page view, media attribution where applicable, evaluated part attempt, reward, policy update, xAPI output, ClickHouse attribution query, and dataset export evidence.
  - [x] Prepare review notes calling out security, performance, backend, Python ETL, ClickHouse migration, and requirements impacts.
- Testing Tasks:
  - [x] Run the full targeted Elixir test set for experiments, xAPI, ClickHouse analytics, backfill, datasets, and migration/coupling checks.
  - [x] Run Python ETL syntax validation locally; run Python ETL tests in an environment with `pytest` available.
  - [x] Run formatting.
  - Command(s): `mix test test/oli/experiments test/oli/delivery/experiments/reward_handoff_test.exs test/oli/analytics/xapi test/oli/analytics/backfill_test.exs test/oli/analytics/backfill/query_builder_test.exs test/oli/analytics/datasets_test.exs test/oli/analytics/clickhouse_analytics_test.exs test/mix/tasks/clickhouse_migrate_test.exs`
  - Command(s): `cd cloud/xapi-etl-processor && pytest tests`
  - Local fallback when `pytest` is unavailable: `cd cloud/xapi-etl-processor && PYTHONPYCACHEPREFIX=/tmp/oli-torus-pycache python3 -m py_compile lambda_function.py tests/lambda_function_test.py`
  - Command(s): `mix format`
- Definition of Done:
  - AC-001 through AC-007 are covered by implementation and tests.
  - `priv/repo/migrations/20260625120000_create_experiment_tables.exs` no longer creates `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates`.
  - Runtime delivery does not perform direct ClickHouse/S3 work and does not depend on ClickHouse freshness.
  - Product analytics/report/export code uses approved ClickHouse-backed contracts.
- Gate:
  - Final implementation review cannot pass unless security and performance reviews find no blocking issues and the targeted test set passes.
- Dependencies:
  - Phases 1 through 5 complete.
- Parallelizable Work:
  - Documentation/review notes can be prepared while final test runs execute.

## Parallelization Notes
- Phase 1 attribution contract work should lead; it defines extension field names and attribution roles used everywhere else.
- Phase 2 ClickHouse migration/ETL and Phase 3 runtime idempotency replacement can proceed in parallel after Phase 1, but Phase 6 cannot start until both are complete.
- Phase 4 query contracts can start with Phase 2 fixtures but should finalize only after Phase 3 confirms attribution and deduplication semantics.
- Phase 5 dataset export can be developed in parallel with late Phase 4 work if the dataset code consumes the same query module rather than duplicating SQL.
- Phase 6 is intentionally serialized because it updates the existing PostgreSQL migration to remove temporary tables from the final branch schema.

## Phase Gate Summary
- Gate A: Canonical experiment attribution extensions and privacy tests pass before downstream ingest/query work depends on fields.
- Gate B: Production ETL, direct ClickHouse upload, and backfill all ingest experiment attributions from host statements before query contracts are considered stable.
- Gate C: Runtime idempotency replacement proves branch-based reward eligibility and duplicate reward protection before the four event-history tables are removed from the existing native A/B testing migration.
- Gate D: ClickHouse-backed query contracts and coupling checks pass before dataset exports or downstream analytics consume experiment data.
- Gate E: Dataset exports include experiment evidence without PostgreSQL event-history queries before final release verification.
- Gate F: `priv/repo/migrations/20260625120000_create_experiment_tables.exs` is updated in this slice and schema assertions prove `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` are not part of the final schema.

## Decision Log
### 2026-07-16 - Plan Against Attribution Arrays On Existing xAPI Events
- Change: Updated phase tasks and gates from dedicated experiment xAPI events and flat raw columns to `experiment_attributions` on existing page, attempt, and media host events with attribution-level ClickHouse extraction.
- Reason: Multiple decision points can exist within one page or media-bearing alternative, so the implementation must preserve one raw xAPI row per host event while supporting multiple experiment attributions.
- Evidence: PRD/FDD decision to use existing host xAPI events and account for media inside decision point alternatives.
- Impact: Phase 1 owns attribution contract/schema work, Phase 2 owns attribution extraction/projection, and downstream query/export phases filter by host event type and attribution role.

### 2026-07-20 - Use Compact Attribution Projection Keyed To Raw Events
- Change: Updated the delivery plan to reflect a compact `experiment_attributions` projection/table keyed by `raw_event_hash`, rather than flat experiment columns on `raw_events` or a projection that duplicates host/media/attempt details.
- Reason: Stable experiment dimensions should be directly queryable, while detailed host statement context remains on the parent `raw_events` row.
- Evidence: Current ClickHouse migration, direct uploader, backfill query builder, Lambda ETL extraction, and tests use `raw_event_hash` joins for detailed host context.
- Impact: Phase 2 and Phase 4 validation must prove attribution extraction, dedupe, and query contracts use `raw_event_hash` plus attribution identity.

### 2026-07-20 - Track Cross-Ingest Transform Drift
- Change: Documented the intentional overlap and known variation points between the Elixir direct uploader, Python Lambda ETL, and ClickHouse backfill SQL transforms.
- Reason: Local direct upload must bypass production S3/Lambda while preserving equivalent ClickHouse semantics, but hand-maintained transforms can drift.
- Evidence: Code comparison of `lib/oli/analytics/xapi/clickhouse_uploader.ex`, `cloud/xapi-etl-processor/lambda_function.py`, and `lib/oli/analytics/backfill/query_builder.ex`.
- Impact: A later hardening task should add shared fixtures, parity assertions, or a canonical extraction contract before relying on exact cross-path equivalence for production investigations.
