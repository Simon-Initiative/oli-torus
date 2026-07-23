# Experiment XAPI And OLAP Foundation - Functional Design Document

## 1. Executive Summary
Implement the durable event and OLAP foundation for native A/B testing by making experiment attribution on existing xAPI statements canonical, ingesting those attributions into ClickHouse, exposing approved ClickHouse-backed query contracts, integrating experiment evidence into dataset exports, and removing the temporary PostgreSQL experiment event-history tables in this slice.

This design satisfies FR-001 through FR-007. It treats `Oli.Experiments` as the runtime owner for definitions, conditions, sticky assignments, and current Thompson Sampling policy state, while `Oli.Analytics.XAPI`, S3 JSONL, and ClickHouse become the durable event-history path. `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` are removed from the final native A/B testing schema by updating `priv/repo/migrations/20260625120000_create_experiment_tables.exs`. Runtime behavior that currently depends on those tables is replaced by narrow operational state on retained experiment tables plus deterministic xAPI idempotency keys and ClickHouse deduplication contracts.

The simplest adequate approach is to extend existing xAPI host statements rather than introduce a new experiment xAPI object type or analytics service. The implementation adds a canonical `experiment_attributions` extension that can contain zero or more attribution objects per xAPI statement, updates production ETL and local direct upload/backfill transforms to project those attributions into ClickHouse, and replaces PostgreSQL analytics reads with ClickHouse-backed query modules. No feature flag is required; rollout is controlled by sequence, migration, tests, and review gates.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Define canonical experiment attribution extensions for existing xAPI statements and operational policy-update evidence.
  - FR-002: Emit experiment-attributed xAPI from runtime paths without direct S3 or ClickHouse work in learner-facing transactions.
  - FR-003: Ingest experiment attributions into ClickHouse through production ETL, local direct upload, and backfill/replay paths.
  - FR-004: Provide ClickHouse-backed analytics query contracts and prevent downstream analytics/report/export code from querying temporary PostgreSQL event-history tables.
  - FR-005: Include experiment attribution evidence in dataset/export infrastructure.
  - FR-006: Expose telemetry and data-quality signals for emission, validation, ingest, lag, query, export, missing-event, and delayed-policy-update failures.
  - FR-007: Replace runtime idempotency dependencies and remove `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` before this slice is complete.
- Acceptance criteria mapping:
  - AC-001: Sections 4, 5, 6, 12, and 13 define attribution shapes, required fields, and privacy exclusions.
  - AC-002: Sections 4, 5, 7, 9, and 13 define runtime xAPI emission through the existing pipeline without direct ClickHouse writes.
  - AC-003: Sections 4, 5, 6, 9, and 13 define ClickHouse ingest/query support for ETL, local upload, and backfill.
  - AC-004: Sections 4, 5, 6, 13, and 14 define approved ClickHouse-backed read contracts and removal of PostgreSQL event-history table coupling.
  - AC-005: Sections 4, 5, 6, and 13 define dataset/export integration from the xAPI/ClickHouse path.
  - AC-006: Sections 10, 11, and 13 define observability and data-quality checks.
  - AC-007: Sections 4, 6, 7, 13, and 14 define replacement idempotency behavior and the required update to the existing native A/B testing migration.
- Non-functional requirements:
  - Delivery runtime correctness must not depend on ClickHouse freshness.
  - Learner-facing transactions must not perform direct S3, Lambda, or ClickHouse network work.
  - Experiment xAPI statements and exports must avoid learner names, LMS identifiers, raw learner responses, full request payloads, and full policy state.
  - Product dashboards, reports, exports, and large aggregates must use ClickHouse-backed contracts.
  - ClickHouse migrations must follow `priv/clickhouse/AGENTS.md`.
- Assumptions:
  - `runtime_telemetry_reconciliation` has established the source-of-truth boundary and existing `Oli.Experiments.Telemetry` statement builder.
  - Existing native A/B testing runtime tables and APIs from earlier slices are present.
  - Existing xAPI upload pipeline, local ClickHouse uploader, S3 JSONL storage, Lambda ETL, ClickHouse migrations, backfill tooling, and dataset job infrastructure are available.
  - This slice owns the final removal of the four temporary PostgreSQL event-history tables.

## 3. Repository Context Summary
- What we know:
  - `Oli.Experiments` owns native experiment persistence and runtime APIs for assignment, exposure, outcome, reward, lifecycle, analytics summaries, and current policy-state inspection.
  - `Oli.Experiments.Telemetry` currently emits dedicated experiment statements; this design supersedes that with experiment attribution extensions on existing xAPI host statements where learner activity already exists.
  - `priv/repo/migrations/20260625120000_create_experiment_tables.exs` currently creates retained operational tables and the four temporary event-history tables. This slice updates that migration so it represents the final native A/B testing schema.
  - `experiment_assignments` is required for sticky assignment. `experiment_policy_states` is required for current Thompson Sampling assignment and posterior state.
  - `record_reward/1` and policy updates previously used temporary event-history rows for duplicate posterior-update protection. `record_exposure/1` and `record_outcome/1` now validate scope and produce attribution receipts without retaining PostgreSQL event state.
  - ClickHouse currently has one `raw_events` table in `priv/clickhouse/migrations/20260326213833_initialize.sql`, with nullable columns for video, attempt, part, page, score, and source metadata.
  - Production ingest lives in `cloud/xapi-etl-processor/lambda_function.py`; local direct ingest lives in `Oli.Analytics.XAPI.ClickHouseUploader`; S3 backfill SQL is built by `Oli.Analytics.Backfill.QueryBuilder`.
  - Dataset jobs are owned by `Oli.Analytics.Datasets` and configured through `Oli.Analytics.Datasets.JobConfig`.
- Unknowns to confirm:
  - Whether later query pressure should denormalize additional raw host context into the attribution projection. This design starts with compact `experiment_attributions` rows keyed back to `raw_events.event_hash` because it preserves one raw row per xAPI statement and avoids duplicating detailed host/media/attempt columns.
  - The exact user-facing dashboard shape belongs to the downstream analytics slice.
  - The final dataset output format for research users may need product review; this design only requires experiment rows to be available through the existing export path.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` remains the runtime owner. It continues to own definitions, decision points, conditions, assignments, current policy state, and scope validation. It no longer owns durable exposure/outcome/reward/policy-update history after this slice.

`Oli.Experiments.Telemetry` becomes the canonical experiment attribution renderer. Existing statement functions should be replaced or refactored into a stable attribution contract, covered by tests, and decoupled from removed Ecto schemas where needed. The module must build attribution payloads from retained runtime structs, request structs, receipts, and plain policy-update result maps rather than from `Exposure`, `Outcome`, `Reward`, or `PolicyUpdate` schemas.

Existing xAPI host-event emitters remain the upload boundary. `Oli.Experiments.Telemetry` renders attribution payloads and operational telemetry, but it does not emit a dedicated learner-facing `:experiment` xAPI statement. Host statement builders or callers attach the returned attribution arrays before the existing upload pipeline writes JSONL and handles configured local/direct upload behavior.

`cloud/xapi-etl-processor/lambda_function.py`, `Oli.Analytics.XAPI.ClickHouseUploader`, and `Oli.Analytics.Backfill.QueryBuilder` all learn the same experiment attribution extraction rules. Production ETL, local direct upload, and replay/backfill must produce equivalent attribution-level ClickHouse rows.

`Oli.Experiments.ClickHouseAnalytics` or a similarly named internal module becomes the approved experiment analytics read contract. It should build scoped ClickHouse SQL through existing `Oli.Analytics.ClickhouseAnalytics.execute_query` patterns and return public maps for downstream dashboards, reports, monitoring, and exports.

`Oli.Analytics.Datasets` remains the dataset job orchestrator. Experiment exports are added through dataset configuration/query generation rather than direct PostgreSQL queries.

### 4.2 State & Data Flow
Assignment and assignment reuse:

1. Delivery calls `Oli.Experiments.assign_condition/1`.
2. `Oli.Experiments` creates or reuses `experiment_assignments`.
3. Assignment remains operational runtime state. It is not emitted as a learner activity xAPI statement unless a downstream host event exposes or evaluates the assignment.
4. ClickHouse attribution rows are created from host xAPI events that carry assignment details.

Exposure:

1. Before emitting `page_viewed`, delivery resolves all experiment-backed alternatives decisions for the page, records exposure for renderable assigned branches, and builds exposure attribution payloads.
2. The resolved decisions are stored in the render context keyed by alternatives resource ID or decision point key so `Alternatives.select/2` can render from precomputed decisions instead of assigning again.
3. `Oli.Experiments` validates the assignment and returns a deterministic exposure receipt without inserting `experiment_exposures` or mutating `experiment_assignments.runtime_event_state`.
4. The existing `page_viewed` statement carries one `experiment_attributions` entry per decision point alternative shown on that page, with `role: "exposure"`.
5. Reward eligibility reads sticky assignment state and page-content branch matching. It does not require retained exposure state because an evaluated attempt inside the selected branch is sufficient runtime evidence for reward handoff.

Outcome and reward:

1. `Oli.Delivery.Experiments.RewardHandoff` derives deterministic outcome and reward idempotency keys from activity attempt ID and assignment ID.
2. `record_outcome/1` validates assignment scope and returns a deterministic outcome receipt without inserting `experiment_outcomes` or mutating `experiment_assignments.runtime_event_state`.
3. Evaluated `part_attempt` xAPI statements carry canonical `role: "outcome"` and `role: "reward"` attributions when the outcome/reward is derived from that part attempt. `activity_attempt` and `page_attempt` may carry `role: "rollup"` attribution only when the rolled-up attempt has an unambiguous experiment assignment or can safely include an attribution array.
4. `record_reward/1` validates assignment scope, applies a reward idempotency guard, and mutates `experiment_policy_states` when appropriate. If Thompson Sampling state changes, policy-update evidence is emitted as operational telemetry or projected analytics data rather than learner activity xAPI; no `experiment_policy_updates` row is inserted.

Media:

1. Existing media xAPI statements, including video played/paused/seeked/completed events, carry `experiment_attributions` entries when the media element is rendered within a selected decision point alternative.
2. Media attribution uses the same assignment, decision point, condition, algorithm, and policy metadata as page/attempt attribution, with media-specific context retained on the host statement.

Analytics:

1. Existing xAPI host events with experiment attribution arrays become JSONL in S3 and raw rows in ClickHouse.
2. ClickHouse projections/query contracts expose attribution-level exposure, outcome/reward, rollup, and policy-update history grouped by experiment, decision point, condition, project, section, publication, algorithm, policy version, host event type, attribution role, and time. Queries that need page, activity, part, attempt, or media details join `experiment_attributions.raw_event_hash` to `raw_events.event_hash`.
3. Dataset exports read the ClickHouse-backed experiment contract.
4. PostgreSQL remains available only for low-volume operational state such as definitions, assignments, and current policy state.

### 4.3 Lifecycle & Ownership
PostgreSQL retained ownership:

- `experiment_definitions`: definition, lifecycle, project/section scope, algorithm, policy configuration.
- `experiment_decision_points`: alternatives decision-point matching.
- `experiment_conditions`: condition codes, labels, weights, and active state.
- `experiment_assignments`: sticky assignment plus reward duplicate-protection state needed by runtime.
- `experiment_policy_states`: current adaptive policy state for assignment, including counters and duplicate reward protection metadata.

PostgreSQL removed ownership:

- `experiment_exposures`
- `experiment_outcomes`
- `experiment_rewards`
- `experiment_policy_updates`

xAPI/S3 owns durable event history. ClickHouse owns analytics serving, data-quality queries, and dataset export inputs.

### 4.4 Alternatives Considered
- Add a new experiment analytics service: rejected because existing xAPI, S3, Lambda ETL, ClickHouse, and dataset infrastructure already provide the needed path.
- Keep the four PostgreSQL event-history tables until analytics/manual QA: rejected by product direction. This slice owns removing them from `priv/repo/migrations/20260625120000_create_experiment_tables.exs`.
- Store independent experiment history as a separate primary ClickHouse event table: rejected because the durable source remains existing xAPI host statements. The implementation may use a separate physical `experiment_attributions` projection/table, but it is derived from host xAPI and keeps `raw_event_hash` as the parent reference to `raw_events`.
- Emit a new `experiment_event` xAPI object type: rejected for learner-facing exposure/outcome/reward events because existing page, attempt, and media statements are the semantic host events. Use attribution arrays so one host event can represent multiple decision point alternatives without duplicating the raw statement.
- Query ClickHouse from delivery for idempotency: rejected because delivery correctness must not depend on OLAP freshness or network calls.
- Keep full policy state in xAPI: rejected for payload size and privacy/audit reasons; emit compact hashes plus policy metadata and keep current runtime state in PostgreSQL.

## 5. Interfaces
- Runtime attribution interface:
  - `Oli.Experiments.XAPI.Attributions.attributions_for_page_view(...)` returns zero-or-more exposure attributions for a `page_viewed` statement.
  - `Oli.Experiments.XAPI.Attributions.attributions_for_part_attempt(...)` returns zero-or-more outcome/reward attributions for a `part_attempt` statement.
  - `Oli.Experiments.XAPI.Attributions.attributions_for_activity_attempt(...)` and `attributions_for_page_attempt(...)` return zero-or-more rollup attributions where the rolled-up scope is unambiguous.
  - `Oli.Experiments.XAPI.Attributions.attributions_for_media_event(...)` returns zero-or-more exposure/interaction attributions for media events rendered inside decision point alternatives.
  - `Oli.Experiments.XAPI.Attributions.attach_attributions(...)` attaches attribution arrays to existing host xAPI statements.
  - `Oli.Experiments.Telemetry.emit(:policy_updated, {policy_update_result, reward_context}, opts)` may remain operational telemetry, but it is not modeled as a learner activity xAPI object.
- Receipt contracts after table removal:
  - `ExposureReceipt`, `OutcomeReceipt`, and `RewardReceipt` remain public domain receipts, but IDs must become deterministic receipt IDs or optional values derived from idempotency keys where no PostgreSQL row exists.
  - `RecordRewardRequest.outcome_id` should be replaced or made optional in favor of `outcome_idempotency_key` and attempt references because `experiment_outcomes` will no longer exist.
  - Policy update telemetry should accept a map/struct returned by the policy update function rather than `%PolicyUpdate{}`.
- Canonical xAPI host events for experiment attribution:
  - `page_viewed`: canonical exposure host.
  - `part_attempt`: canonical outcome/reward host.
  - `activity_attempt`: optional rollup host when the activity has unambiguous or array-representable attribution.
  - `page_attempt`: optional rollup host when the page has unambiguous or array-representable attribution.
  - video/media events: exposure or interaction attribution host when media is rendered inside a selected decision point alternative.
- Required xAPI extension:
  - `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]` is an array. It may be empty or omitted when no experiment applies.
- Required attribution object fields:
  - `role`: `exposure`, `outcome`, `reward`, `rollup`, or `media_interaction`.
  - `experiment_id` and/or stable `experiment_uuid` when available.
  - `decision_point_id`, `decision_point_key`, `condition_id`, `condition_code`, `assignment_id`, `assignment_key`.
  - `algorithm`, `policy_version`, and `algorithm_version` when available.
  - Host context is inherited from the xAPI statement: actor, timestamp, section/project/publication, page/activity/part/media identifiers, score/result, and raw event hash. Detailed host fields are not repeated in the attribution payload unless needed for a stable experiment dimension.
  - Reward-specific attribution fields: `reward_value` and `reward_source`.
  - Policy-update provenance belongs to operational telemetry or a projection, with `policy_update_reason`, `previous_policy_state_hash`, and `next_policy_state_hash`; it is not required on learner activity statements.
- ClickHouse read interface:
  - `experiment_event_counts(query)` for grouped exposure/reward/outcome/rollup/policy counts from attribution projections.
  - `experiment_assignment_share(query)` for assignment share by condition and time.
  - `experiment_reward_summary(query)` for reward counts and rates.
  - `experiment_policy_update_history(query)` for policy-update audit history.
  - `experiment_data_quality(query)` for missing exposure/outcome/reward evidence and delayed policy updates.
- Dataset interface:
  - Extend dataset job configuration or query generation so experiment attribution filters include attribution projection rows from ClickHouse.

## 6. Data Model & Storage
- PostgreSQL migration:
  - Update `priv/repo/migrations/20260625120000_create_experiment_tables.exs` in place so it creates the final native A/B testing schema for this branch.
  - Add any required operational fields directly to retained tables in that migration. Candidate fields include reward duplicate-protection state on `experiment_assignments`; exposure and outcome event state should not be retained in PostgreSQL.
  - Remove creation of `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` from that migration rather than adding follow-up PostgreSQL migrations on this branch.
  - Remove or rewrite Ecto schemas `Oli.Experiments.Schemas.Exposure`, `Outcome`, `Reward`, and `PolicyUpdate` once no code references them.
  - Replace `experiment_policy_states.last_updated_from_reward_id` with a non-FK reward idempotency/provenance field because `experiment_rewards` will not exist in the final schema.
- ClickHouse migration:
  - Preserve `raw_events` as one row per xAPI statement. Do not duplicate raw rows for each experiment decision point.
  - Add a raw JSON/string column or equivalent extraction path for the `experiment_attributions` extension if the existing raw statement JSON is not sufficient for replay.
  - Add nullable raw summary columns only when they are unambiguous, such as `has_experiment_attribution` and `experiment_attribution_count`. Avoid flat `experiment_id`, `decision_point_id`, `condition_id`, or `assignment_id` columns on `raw_events` as canonical analytics fields because one raw event may carry multiple attributions.
  - Add an attribution-level ClickHouse projection/table that contains one row per attribution with a compact set of stable query dimensions. The attribution row should include `raw_event_hash` as the logical parent reference to `raw_events.event_hash`, `attribution_hash`, `host_event_type`, `experiment_role`, `experiment_id`, `experiment_uuid`, `decision_point_id`, `decision_point_key`, `condition_id`, `condition_code`, `assignment_id`, `assignment_key`, `algorithm`, `policy_version`, `algorithm_version`, `reward_value`, `reward_source`, `section_id`, `project_id`, `publication_id`, `enrollment_id`, `content_revision_id`, policy-update hashes, and `timestamp`.
  - Do not duplicate detailed host/media/attempt fields such as attempt GUIDs, video URLs, content element IDs, activity revision IDs, page IDs, activity IDs, or part IDs in the attribution projection unless a later query-pressure review justifies the denormalization. Query those details by joining `experiment_attributions.raw_event_hash` back to `raw_events.event_hash`.
  - Add indexes for attribution query dimensions where ClickHouse supports the selected index types.
- ETL mapping:
  - Production Lambda, local direct uploader, and backfill SQL must map the same `experiment_attributions` extension keys to the same attribution projection columns.
  - Attribution rows should retain the host statement `event_hash` as `raw_event_hash`; dedupe should use host statement identity plus attribution identity fields so replayed JSONL does not inflate counts.
- xAPI schema:
  - Extend `priv/schemas/xapi/v0-1-0/statement.schema.json` to allow the optional `experiment_attributions` extension on existing host statement definitions.

## 7. Consistency & Transactions
- PostgreSQL remains the synchronous consistency boundary for assignment and current adaptive policy state.
- xAPI emission happens after successful runtime validation/state mutation and must not roll back delivery if the xAPI pipeline fails.
- Exposure idempotency should be deterministic by assignment, content revision, and idempotency key. Duplicate exposure calls should return reused receipts or emit duplicate-safe statements with the same idempotency key.
- Reward idempotency must prevent duplicate Thompson Sampling posterior updates for the same reward key. The implementation must preserve this guarantee before the existing native A/B testing migration is updated to omit `experiment_rewards` and `experiment_policy_updates`.
- Policy-state updates remain transactional with the duplicate reward guard and `experiment_policy_states` update.
- ClickHouse may lag runtime and must not be read by learner-facing assignment, exposure, outcome, reward, or policy-update code.
- Analytics queries must use the selected ClickHouse deduplication strategy over `raw_event_hash` plus attribution identity so S3 replay and duplicate xAPI emission do not inflate counts.

## 8. Caching Strategy
- No application cache is required for runtime correctness.
- Do not cache experiment xAPI history in Elixir process memory.
- ClickHouse query caching is deferred to downstream analytics unless a specific dashboard/export path proves it needs caching.
- Any future cache must be scoped by institution/project/section/experiment, event filters, time window, and authorization-sensitive dimensions.

## 9. Performance & Scalability Posture
- Learner-facing runtime stays bounded to PostgreSQL assignment/policy operations plus enqueueing xAPI into the existing pipeline.
- Direct S3, Lambda, or ClickHouse writes are forbidden inside delivery transactions.
- ClickHouse attribution columns and indexes should support common compact filters: project, section, publication, host event type, experiment role, experiment, decision point, condition, algorithm, policy version, and timestamp. Page, activity, part, attempt, and media filters should use a `raw_event_hash` join to `raw_events` unless later query-pressure review justifies denormalization.
- Dataset exports and dashboards must use ClickHouse reads, not PostgreSQL scans over event history.
- The final native A/B testing schema reduces PostgreSQL write volume and table growth by omitting exposure/outcome/reward/policy-update history persistence.
- Backfill/replay must be batch-oriented through existing ClickHouse backfill jobs rather than per-event application loops.

## 10. Failure Modes & Resilience
- xAPI emit failure: runtime operation remains successful; telemetry records the exception and existing upload-pipeline failure handling applies.
- Duplicate xAPI statement: ClickHouse dedupe or query-level distinct-by-`raw_event_hash`-and-attribution prevents double counting.
- ETL parse failure for experiment attribution: Lambda logs/telemetry identify statement validation/extraction failure and the SQS failure path or DLQ handles retry/failure according to existing ETL behavior.
- ClickHouse migration partially applied: migrations use `IF NOT EXISTS` and standalone statements to support safe retry.
- ClickHouse unavailable: delivery continues; analytics/read contracts return scoped errors or unavailable status.
- Reward duplicate guard regression: tests must fail before the existing native A/B testing migration is accepted without reward or policy-update event-history tables.
- Dataset export failure: dataset job records failure through existing `Oli.Analytics.Datasets` status and notification behavior.

## 11. Observability
- Preserve existing `[:oli, :experiments, ...]` telemetry for assignment, fallback, reward handoff, policy update, and xAPI emission.
- Add or standardize metrics for:
  - statement validation failures by host event type and experiment attribution role;
  - xAPI emission success/failure and duplicate skips;
  - Lambda ETL experiment attribution extraction failures;
  - ClickHouse insert/query failures;
  - ETL lag by source file timestamp and ClickHouse inserted time;
  - dataset export failures for experiment attribution jobs;
  - missing exposure/outcome/reward evidence and delayed policy-update evidence.
- Metadata must be privacy-safe: include experiment_id or experiment_uuid, decision_point_id, condition_id, condition_code, section_id, project_id, publication_id, algorithm, policy_version, host_event_type, and attribution_role; exclude learner names, LMS IDs, raw responses, and full policy state.
- AppSignal should surface xAPI emission failures, ETL lag/failure, ClickHouse query failure, and reward duplicate-guard exceptions.

## 12. Security & Privacy
- Scope validation remains in `Oli.Experiments` for runtime events and in approved analytics query modules for ClickHouse reads.
- xAPI statements may include internal user/enrollment references needed for joins, but must not include names, emails, LMS identifiers, raw responses, or full request payloads.
- Policy updates emit hashes of prior/next state through operational telemetry or attribution projections rather than full posterior maps unless a later security review explicitly approves more detail.
- Dataset exports must honor existing project/author permissions and default anonymization behavior where supported by `JobConfig`.
- ClickHouse query contracts must enforce project/section/institution scope before exposing data to dashboards, reports, or exports.
- Code review must include security and performance lenses for this slice.

## 13. Testing Strategy
- ExUnit runtime tests:
  - Page views, part attempts, activity/page attempts, and media events include canonical experiment attribution arrays with required fields and privacy exclusions when applicable (AC-001, AC-002).
  - Exposure, outcome, reward, and policy-update paths preserve attribution/projection evidence without inserting rows into removed event-history tables (AC-002, AC-007).
  - Duplicate reward calls do not double-update Thompson Sampling policy state after the replacement idempotency contract is implemented (AC-007).
  - Reward eligibility works from sticky assignment state plus page-content branch matching after `experiment_exposures` is removed (AC-007).
  - xAPI emission failure does not roll back runtime state (AC-002).
- ClickHouse and ETL tests:
  - ClickHouse migration tests or SQL review verify standalone goose statements and expected columns/indexes (AC-003).
  - `ClickHouseUploader` transforms host statements with `experiment_attributions` into attribution projection/table rows (AC-003).
  - Lambda ETL tests cover attribution array extraction, including multiple decision points on one page/media event, and validation failures (AC-003, AC-006).
  - Backfill query tests cover attribution extraction from S3 JSONL (AC-003).
  - Follow-up parity tests should feed the same deterministic xAPI fixtures through `Oli.Analytics.XAPI.ClickHouseUploader`, `cloud/xapi-etl-processor/lambda_function.py`, and `Oli.Analytics.Backfill.QueryBuilder`, then compare shared normalized `raw_events` and `experiment_attributions` columns. The direct uploader intentionally duplicates production ETL semantics for local development, but parity should be tested rather than assumed.
  - Query contract tests verify scoped reads and distinct-by-host-event-plus-attribution behavior (AC-004).
- Dataset/export tests:
  - Dataset job configuration/query tests verify experiment rows are included from ClickHouse and not PostgreSQL (AC-005).
- Coupling and migration tests:
  - Static coupling tests fail on references to `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates` outside historical planning artifacts and any migration/schema assertion code (AC-004, AC-007).
  - Schema assertions verify `priv/repo/migrations/20260625120000_create_experiment_tables.exs` does not create the four event-history tables (AC-007).
  - Tests verify removed Ecto schemas are not referenced by runtime, analytics, dashboard, report, or export code (AC-004, AC-007).
- Validation gates:
  - Run targeted `mix test` for `test/oli/experiments/*`, `test/oli/analytics/xapi/*`, `test/oli/analytics/backfill*`, `test/oli/analytics/datasets_test.exs`, and ClickHouse task/migration tests as affected.
  - Run Python tests under `cloud/xapi-etl-processor/tests` for Lambda ETL changes.
  - Run `mix format`.
  - Run harness requirements and FDD validation.

## 14. Backwards Compatibility
- Native experiment definitions, decision points, conditions, assignments, lifecycle state, and current policy state remain valid.
- Historical rows in `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` are not migrated into new PostgreSQL tables. Durable history after this slice is xAPI/S3/ClickHouse.
- Because this branch has not shipped the native A/B testing migration, existing environments are not expected to require a separate PostgreSQL migration for these temporary event-history tables.
- Existing xAPI attempt/video/page event behavior remains unchanged.
- Existing PostgreSQL-backed experiment analytics functions that read exposure/reward tables must be removed, rewritten to ClickHouse, or restricted to retained operational tables before the final version of `20260625120000_create_experiment_tables.exs` is accepted.
- Downstream `analytics` FDD/plan work must consume this foundation and should treat earlier PostgreSQL-heavy analytics planning as superseded.

## 15. Risks & Mitigations
- Risk: Removing event-history tables from the final migration breaks reward idempotency or policy updates. Mitigation: replace duplicate reward protection first, test repeated reward handoff, and only then update `20260625120000_create_experiment_tables.exs` to omit those tables.
- Risk: ClickHouse counts are inflated by replayed JSONL. Mitigation: use `raw_event_hash` plus attribution identity and query/count distinct attribution identities for experiment analytics.
- Risk: ETL and local upload diverge. Mitigation: define shared extraction fixtures and test production Lambda, direct uploader, and backfill against the same statements. Known drift points to resolve later include event-type detection differences, page-view verb handling, timestamp coercion, raw/attribution hash canonicalization, source-file metadata defaults, and type coercion for IDs, booleans, arrays, responses, feedback, and hints.
- Risk: Learner privacy leaks through xAPI or exports. Mitigation: maintain privacy exclusions in statement tests and dataset tests; use hashes for policy state.
- Risk: ClickHouse schema changes are hard to roll back. Mitigation: additive nullable columns and standalone goose statements with reversible `Down` where feasible.
- Risk: This slice grows into final dashboard UX. Mitigation: stop at query contracts, data-quality checks, and dataset inclusion; dashboard UX belongs to the downstream analytics slice.

## 16. Open Questions & Follow-ups
- Confirm whether later dashboard, monitoring, or export workloads justify denormalizing selected raw host fields into `experiment_attributions`. The current implementation keeps the projection compact and relies on `raw_event_hash` joins for detailed host/media/attempt context.
- Consolidate or contract-test the duplicated xAPI-to-ClickHouse transform logic between `Oli.Analytics.XAPI.ClickHouseUploader`, `cloud/xapi-etl-processor/lambda_function.py`, and `Oli.Analytics.Backfill.QueryBuilder`. Known variations are event-type detection, page-view verb support, timestamp conversion, hash canonicalization, source metadata behavior, and scalar/JSON type coercion.
- Confirm whether `experiment_uuid` is currently available everywhere statements are emitted or must be added to runtime query/preload paths.
- Confirm the exact replacement storage for reward duplicate protection before implementation starts; it must not recreate a broad event-history table.
- Follow up in the analytics slice with final dashboard/report UX and Thompson Sampling monitoring surfaces.
- Follow up in manual QA with evidence that the four temporary PostgreSQL tables are absent in the target schema.

## 18. Decision Log
### 2026-07-16 - Model Experiment Evidence As Attribution On Host xAPI Events
- Change: Replaced dedicated experiment xAPI statement/object-type design with optional `experiment_attributions` arrays on existing page, attempt, and media xAPI statements plus attribution-level ClickHouse projections.
- Reason: Existing xAPI events already represent learner page views, evaluated attempts, and media interactions. A page can contain multiple decision points, so raw event columns cannot canonically store one experiment assignment.
- Evidence: Existing host event builders in `lib/oli/analytics/xapi/events/attempt/*` and media event builders in `lib/oli/analytics/xapi/events/video/*`.
- Impact: ETL, backfill, direct upload, schema validation, query contracts, and datasets must process attribution arrays and preserve raw one-row-per-xAPI-statement semantics.

### 2026-07-20 - Compact Attribution Projection With Raw Event Joins
- Change: Standardized the ClickHouse projection/table around stable experiment query dimensions and `raw_event_hash`, without duplicating detailed video, attempt, page, activity, part, or content-element fields.
- Reason: The parent `raw_events` row already owns detailed host statement context. Keeping the attribution table compact reduces ingestion drift and avoids multiplying large or unstable host columns across attribution rows.
- Evidence: Reconciled ClickHouse migration, direct uploader, backfill query builder, Lambda ETL, and related tests.
- Impact: Analytics contracts use the attribution table for scoped experiment dimensions and join to `raw_events` only when detailed host/media/attempt filters or selected fields are required.

## 17. References
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
- `docs/ISSUE_TRACKING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/attempt-handling.md`
- `docs/design-docs/gdpr.md`
- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/fdd.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/telemetry.ex`
- `lib/oli/delivery/experiments/reward_handoff.ex`
- `lib/oli/analytics/xapi.ex`
- `lib/oli/analytics/xapi/clickhouse_uploader.ex`
- `lib/oli/analytics/backfill/query_builder.ex`
- `lib/oli/analytics/datasets.ex`
- `cloud/xapi-etl-processor/lambda_function.py`
- `priv/clickhouse/AGENTS.md`
- `priv/clickhouse/migrations/20260326213833_initialize.sql`
- `priv/repo/migrations/20260625120000_create_experiment_tables.exs`
