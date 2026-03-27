# xAPI ETL Processor Reliability - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/xapi_etl_processor_reliability/prd.md`
- FDD: `docs/exec-plans/current/epics/xapi_etl_processor_reliability/fdd.md`

## Scope

Deliver the selected single-pipeline hardening strategy for xAPI ingestion:

- refactor the Python Lambda from whole-invocation inserts to bounded incremental sub-batching
- add stage-level observability, timeout-aware request budgeting, and accurate retry accounting
- align retryable failure handling with SQS partial batch semantics and alarm-driven manual maintenance posture
- realign the raw_events schema and all ingestion paths with the canonical xAPI schema and actual Torus producer payloads, including `verb_id` preservation and video-column cleanup
- extend Torus-managed backfills with a one-time post-backfill `OPTIMIZE TABLE ... FINAL` phase and surface that phase in the admin UI
- document and validate the initial production operating posture, including SQS and Lambda settings that may live outside this repository

## Clarifications & Default Assumptions

- The chosen architecture remains `S3 JSONL -> SQS -> Lambda -> ClickHouse`; staged Parquet in S3 is out of scope for this implementation unless new evidence forces a design change.
- Eventual deduplication in `raw_events` is acceptable for this phase; query-time strict dedupe is not a default requirement.
- Retryable ClickHouse insert failures stay in the source SQS queue for retry and are not proactively copied to a custom DLQ.
- Planned ClickHouse maintenance uses an alarm-driven manual pause/resume of the Lambda event source mapping.
- Production IaC for queue retention, visibility timeout, batching window, and max concurrency may live outside this repository; this plan includes explicit coordination and documentation tasks for those settings.
- The post-backfill optimization step applies to successful non-dry-run Torus backfills where dedupe cleanup is enabled.
- `priv/schemas/xapi/v0-1-0/statement.schema.json` and the Torus xAPI producers are the source of truth for raw-events field fidelity; sink columns that cannot be populated from actual statements should be removed rather than preserved for hypothetical future data.

## Phase 1: Lambda Batching Core

- Goal: Replace whole-invocation insert behavior with bounded sub-batching and explicit commit accounting.
- Tasks:
  - [x] Refactor `cloud/xapi-etl-processor/lambda_function.py` to accumulate a current sub-batch instead of one invocation-wide `tables_to_insert` list.
  - [x] Add configurable flush boundaries for preferred row target, hard row ceiling, payload-size ceiling, end-of-invocation flush, and minimum remaining-time safety margin.
  - [x] Make ClickHouse request timeout derive from remaining Lambda budget, with the configured timeout acting as a ceiling rather than a fixed value.
  - [x] Track committed, failed, skipped, and untouched message ids separately so `batchItemFailures` reflects only uncommitted work.
  - [x] Add explicit no-progress detection for invocations that prepare work but cannot safely commit even the minimum viable sub-batch, and return those messages for retry with a distinct reason.
  - [x] Update the deprecated Arrow concatenation call from `promote=True` to `promote_options="default"`.
- Testing Tasks:
  - [x] Add targeted Python tests for mixed preparation outcomes, successful multi-flush invocation behavior, insert-sub-batch failure handling, low-volume end-of-invocation flush, and timeout-budget gating.
  - [x] Add tests that validate request timeout derivation from remaining Lambda time and that unprocessed messages are returned for retry rather than being ambiguously dropped.
  - [x] Add tests proving no-progress conditions emit a distinct signal and do not degrade into silent repeated whole-batch retries.
  - Command(s): `pytest cloud/xapi-etl-processor`
- Definition of Done:
  - Lambda can commit one or more sub-batches per invocation without requiring one combined insert for all prepared messages.
  - The handler returns precise retry accounting for failed or unprocessed messages.
  - The deprecated Arrow API warning is removed.
- Gate:
  - Core batching logic and retry accounting are stable in targeted tests before observability or Torus backfill lifecycle work builds on top.
- Dependencies:
  - FDD-selected architecture and requirements baseline are complete.
- Parallelizable Work:
  - Test scaffolding for Lambda behavior can proceed in parallel with the core refactor as long as write ownership is coordinated.

## Phase 2: Observability, Failure Posture, and Operational Controls

- Goal: Make the Lambda diagnosable in production and align operational semantics with the selected maintenance and retry model.
- Tasks:
  - [x] Add stage-level logging and telemetry for fetch, normalization, concat, Parquet serialization, ClickHouse request, flush reason, row counts, object counts, payload size, and terminal outcomes.
  - [x] Add remaining-time observations before and after major stages and before each insert attempt.
  - [x] Emit an alarmable no-progress metric or structured log outcome so repeated “prepared but could not safely commit” retries are visible to operators.
  - [x] Adjust failure forwarding behavior so ordinary retryable ClickHouse insert failures are not proactively copied to a custom DLQ.
  - [x] Document or codify the initial production runtime baseline: SQS batch size `50`, batching window `60s`, Lambda memory `1024 MB`, Lambda timeout `60s`, max concurrency `2`, and visibility timeout `>=300s`.
  - [x] Capture alarm-driven manual maintenance expectations in repository-adjacent operational docs or work-item notes, including backlog depth, oldest-message-age, repeated-insert-failure, and drain-progress alarms.
- Testing Tasks:
  - [x] Add tests covering INFO-level bounded logging, summarized DLQ payload behavior, and explicit last-successful-stage visibility for slow or failing runs.
  - [x] Validate that retryable insert failures remain retriable through partial batch response semantics only.
  - [x] Manually exercise representative low-volume and forced-failure runs to confirm logs make the dominant stage explicit.
  - Command(s): `pytest cloud/xapi-etl-processor`
- Definition of Done:
  - Operators can tell from one invocation's logs where time or failure occurred.
  - Retryable downstream failures stay in source SQS semantics and no longer create duplicate DLQ copies by default.
  - Initial production settings and maintenance posture are explicitly documented for rollout.
- Gate:
  - Observability and failure posture must be in place before production tuning or backlog recovery exercises are considered complete.
- Dependencies:
  - Phase 1 core batching and commit boundaries.
- Parallelizable Work:
  - Operational documentation and alarm/runbook drafting can proceed while telemetry code is being added.

## Phase 3: Raw Event Schema Fidelity and Event Semantics

- Goal: Align the ClickHouse raw-events contract with the canonical xAPI schema and the actual Torus producers so every retained column can be populated with real data and exact verb identity is preserved.
- Tasks:
  - [ ] Audit `priv/schemas/xapi/v0-1-0/statement.schema.json`, the Torus xAPI event builders under `lib/oli/analytics/xapi/events/**`, and the frontend video emitters under `assets/src/components/**` to finalize the supported raw-events field set.
  - [ ] Add a `verb_id` column to the ClickHouse `raw_events` schema and propagate it through `cloud/xapi-etl-processor/lambda_function.py`, `lib/oli/analytics/backfill/query_builder.ex`, and any repository-owned direct-ingest helpers that must stay schema-compatible.
  - [ ] Rework the raw-events video column set so only canonical producer-backed fields remain, removing `video_play_time` and keeping `video_time`, `video_length`, `video_progress`, `video_played_segments`, `video_seek_from`, and `video_seek_to` mapped from actual statement locations.
  - [ ] Resolve identified schema-vs-raw-events gaps, including explicitly deciding whether schema-defined but currently unsupported families such as `tutorMessage` are implemented now or documented as deferred follow-up work.
  - [ ] Ensure the ClickHouse migration strategy preserves operability for existing data and documents any one-time migration or backfill implications of the column changes.
- Testing Tasks:
  - [ ] Add Python tests proving `verb_id` and the retained video fields are populated correctly for `played`, `paused`, `seeked`, and `completed` statements.
  - [ ] Add ExUnit coverage for `Oli.Analytics.Backfill.QueryBuilder` so the bulk backfill path uses the same `verb_id` and video-field mappings as the Lambda path.
  - [ ] Add targeted coverage or assertions for any retained repository-owned direct-ingest helper that must continue to produce raw-events-compatible rows.
  - Command(s): `cloud/xapi-etl-processor/.venv/bin/python -m pytest cloud/xapi-etl-processor/tests/lambda_function_test.py`
  - Command(s): `mix test test/oli/analytics/backfill`
- Definition of Done:
  - The raw-events table preserves exact `verb_id` for every supported event row.
  - Every retained video-specific column is backed by at least one real producer-emitted schema field.
  - Fictitious, redundant, constant-only, or never-populated sink columns are removed or explicitly deferred with rationale.
  - Lambda ETL and Torus bulk backfill remain aligned on the same raw-events field contract.
- Gate:
  - Raw-events schema changes must be stable in both ingestion paths before final integrated rollout validation begins.
- Dependencies:
  - Phase 1 Lambda batching and Phase 2 observability work should remain intact while the raw-event field contract changes underneath them.
  - FDD schema-fidelity analysis is complete.
- Parallelizable Work:
  - Lambda-path and backfill-path mapping updates can proceed in parallel once the final raw-events column set is agreed, as long as the ClickHouse schema migration ownership is coordinated.

## Phase 4: Torus Backfill Optimization Lifecycle

- Goal: Extend Torus backfills so the app owns the one-time post-backfill optimization phase and exposes it in the admin UI.
- Tasks:
  - [ ] Update the backfill domain boundary in `lib/oli/analytics/backfill.ex`, `lib/oli/analytics/backfill/worker.ex`, and related modules to trigger `OPTIMIZE TABLE ... FINAL` after successful eligible non-dry-run backfills.
  - [ ] Add an explicit optimization-aware lifecycle for `BackfillRun`, preferably a first-class status such as `:optimizing`, so the process does not move directly from running to completed.
  - [ ] Update `lib/oli_web/live/admin/clickhouse_backfill_live.ex` to show optimization as the final in-progress step and surface optimization failure explicitly.
  - [ ] Ensure optimization is treated as an operationally expensive one-time cleanup step and is not introduced into steady-state ETL paths.
- Testing Tasks:
  - [ ] Add targeted ExUnit coverage for successful backfill -> optimizing -> completed transitions.
  - [ ] Add failure-path tests proving optimization errors are recorded distinctly and do not silently mark the run complete.
  - [ ] Add LiveView tests verifying the admin UI renders the optimization phase as the final in-progress step.
  - Command(s): `mix test test/oli/analytics` `mix test test/oli_web/live/admin`
- Definition of Done:
  - Eligible Torus backfills do not report full completion until the optimization phase has succeeded.
  - Optimization progress and failure are visible in the admin UI and run state.
- Gate:
  - Backfill lifecycle changes must pass targeted domain and LiveView tests before rollout guidance is finalized.
- Dependencies:
  - PRD/FDD decision on one-time post-backfill cleanup.
  - Phase 3 raw-events schema changes are complete enough that the optimization target contract is stable.
- Parallelizable Work:
  - Domain-state changes and UI rendering updates can proceed in parallel once the lifecycle shape is agreed.

## Phase 5: Integrated Verification and Rollout Readiness

- Goal: Prove the repository-owned changes satisfy the traced requirements and package the rollout posture for production use.
- Tasks:
  - [ ] Run requirement trace validation and update proof links if needed.
  - [ ] Execute targeted repository test suites for Python ETL behavior, Elixir backfill lifecycle, and admin UI changes.
  - [ ] Verify work-item docs stay aligned with implementation details and update them if the code-level rollout posture drifts.
  - [ ] Update `cloud/xapi-etl-processor/README.md` to reflect the final batching model, timeout budgeting, no-progress handling, retry and DLQ behavior, observability posture, and maintenance operating procedure.
  - [ ] Produce rollout notes covering initial production settings, maintenance pause/resume procedure, backlog-drain expectations, and when to revisit staged Parquet or materialized-view follow-up work.
  - [ ] Capture any external IaC or AWS-console changes required to realize the documented SQS/Lambda settings in production.
- Testing Tasks:
  - [ ] Run work-item validation commands for requirements, plan, and overall work-item structure.
  - [ ] Run the narrowest repository tests that cover each changed boundary, then broaden if failures indicate hidden coupling.
  - Command(s): `requirements_trace.py <work_item_dir> --action verify_plan` via the `harness-requirements` skill
  - Command(s): `requirements_trace.py <work_item_dir> --action master_validate --stage plan_present` via the `harness-requirements` skill
  - Command(s): `validate_work_item.py <work_item_dir> --check plan` via the `harness-validate` skill
- Definition of Done:
  - Repository-owned changes are covered by targeted tests and work-item validation passes.
  - Rollout notes clearly separate in-repo changes from required production configuration changes.
- Gate:
  - No rollout or implementation close-out until validation passes and the required external operating settings are explicitly called out.
- Dependencies:
  - Phases 1 through 4 complete.
- Parallelizable Work:
  - Requirements validation and rollout-note drafting can begin while final tests are being stabilized.

## Parallelization Notes

- The Lambda refactor and Torus backfill lifecycle work touch different language/runtime boundaries and can proceed in parallel after the overall design is locked.
- Within the Lambda work, core batching logic should land before or alongside observability and retry-posture cleanup, because telemetry must describe the new flush model rather than the old whole-invocation model.
- Backfill domain changes and admin UI rendering changes can be split, but both depend on agreeing on the persisted lifecycle shape.
- Raw-events schema fidelity work spans Python ETL, ClickHouse migrations, and Elixir bulk backfill SQL, so those slices can be parallelized only after the final retained column set is agreed.
- External production-setting updates should not block repository coding, but they must be tracked explicitly before rollout.

## Phase Gate Summary

- Gate A: Phase 1 proves bounded sub-batching, precise retry accounting, and timeout-aware request budgeting in targeted Python tests.
- Gate B: Phase 2 proves operators can diagnose dominant failure stages and that retryable insert failures remain in source SQS retry flow.
- Gate C: Phase 3 proves the raw-events field contract preserves exact verb identity and only retains producer-backed event-family data across ingestion paths.
- Gate D: Phase 4 proves Torus backfills expose and enforce the post-backfill optimization phase in both domain state and admin UI.
- Gate E: Phase 5 validates the work item, targeted tests, and rollout posture needed to safely ship the new ingestion behavior.
