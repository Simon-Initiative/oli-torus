# UpGrade Data-Capture Parity - Functional Design Document

## 1. Executive Summary

Extend the existing native experiment and xAPI analytics boundaries so every durable learner statement can produce two complementary ClickHouse projections: one canonical host-event row in `raw_events`, and zero or more assignment-backed causal rows in `experiment_attributions`, joined by `raw_event_hash`. Activity-attempt host rows form the complete section-wide UpGrade-compatible outcome stream; attribution rows describe only relationships proven by the learner's assignment and immutable selected-branch provenance. This separation prevents an unattributed activity from disappearing from compatibility analysis and prevents an out-of-branch activity from being mislabeled as experiment-caused.

`Oli.Experiments` remains the sole owner of assignment, scope, branch matching, exposure, outcome, reward, and policy semantics. It will expose a reusable attribution-resolution boundary consumed by xAPI statement construction for activity, part, media, navigation, nested-content, and asynchronous events. The extension at `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]` remains the wire contract. Direct upload, the Python Lambda, and S3 backfill will implement one documented normalization contract and use deterministic hashes for replay safety.

The work is additive: no UI, export endpoint, feature flag, content republishing, assignment migration, or UpGrade-data migration is introduced. PostgreSQL remains the transactional runtime source of truth, S3 xAPI remains the durable replay source, and ClickHouse remains the supported analytical source. This design covers FR-001 through FR-014 and AC-001 through AC-026.

## 2. Requirements & Assumptions

- Functional requirements:
  - Preserve enrollment as the pseudonymous participant identity, with distinct participants for the same user in different sections (FR-001; AC-001).
  - Preserve both weighted-random assignment scopes and intervention-specific exposure provenance, while retaining intervention scope for Thompson Sampling and old evidence (FR-002, FR-003; AC-002 through AC-006).
  - Attribute supported interactions and evaluated outcomes only through assignment-backed selected-branch containment that can be reconstructed from immutable deployed content (FR-004, FR-005; AC-007 through AC-011).
  - Keep all applicable activity-attempt outcomes in `raw_events` and causal relationships in `experiment_attributions` (FR-006; AC-012, AC-013).
  - Keep continuous outcomes, Thompson rewards, and policy updates independently identifiable without changing reward eligibility, normalization, idempotency, or concurrency behavior (FR-007; AC-014 through AC-016).
  - Define stable occurrence timestamps, joins, path parity, and replay idempotency across direct upload, Lambda, replay, and backfill (FR-008 through FR-010; AC-017 through AC-020).
  - Preserve historical content and schema compatibility, privacy boundaries, bounded diagnostics, and a repository-owned compatibility proof (FR-011 through FR-014; AC-021 through AC-026).
  - Traceability details: a section-and-enrollment assignment is canonical across interventions (AC-003); weighted-random defaults and Thompson/historical scope rules follow MER-5883 (AC-004); exposure carries complete immutable provenance (AC-005); out-of-branch events remain unattributed (AC-008); outcome, reward, and policy-update evidence remain independently joinable (AC-015); and all enumerated missing-evidence, ingestion, parity, and allocation conditions are diagnosable (AC-024).
- Non-functional requirements:
  - Attribution must not depend on transient render state or mutable authoring revisions.
  - Projection must be additive, bounded, idempotent, tenant-scoped, and tolerant of historical missing fields.
  - Telemetry is included by default under `harness.yml`; feature flags and explicit performance budgets are excluded by default and are not required by this low-risk additive rollout.
  - Security and performance review are mandatory. Elixir, Python/analytics, requirements, and any other surface-specific review guidance applies to the files changed by implementation.
  - Jira MER-5885 remains the issue record; substantive scope changes follow the repository's approval-before-write Jira workflow.
  - Database migrations introduced by this work are schema-only. They must not update, derive, replay, or otherwise populate historical rows; existing events may retain null for every newly introduced column.
- Assumptions:
  - `enrollment_id`, not a user identifier, is the public analysis participant key. Existing xAPI actor values may remain for general xAPI operation but are excluded from the compatibility view, attribution payloads, telemetry dimensions, and exported shape.
  - The assignment scope contract from MER-5883 is present: new weighted-random experiments default to `section_enrollment`, explicit `intervention` remains supported, Thompson Sampling requires `intervention`, and historical missing scope normalizes to `intervention`.
  - `raw_events.event_hash` and `experiment_attributions.raw_event_hash` are the same lowercase SHA-256 of the exact persisted JSON statement. `attribution_hash` is the lowercase SHA-256 of `raw_event_hash <> ":" <> attribution.key`.
  - Compatibility inclusion uses `assigned_at <= observed_at < analysis_end`. `analysis_end` is the earliest experiment completion, archival, or requested exclusive export end, falling back to the export execution cutoff. Pause does not split the window and exposure does not gate section-wide outcomes.
  - Continuous correctness is `score / out_of`; it is `0.0` when score or denominator is zero or division fails. A missing score or denominator remains null in storage and normalizes to `0.0` only in the documented compatibility query, making storage fidelity and compatibility behavior both explicit.
  - Statements that reached S3 can be replayed. The accepted pre-persistence asynchronous xAPI crash window remains unrecoverable and is diagnosed rather than eliminated.

## 3. Repository Context Summary

- What we know:
  - `Oli.Experiments` owns assignments, assignment scope, branch matching, exposures, outcomes, Thompson rewards, policy updates, and the historical `upgrade_decision_point` alias.
  - `Oli.Experiments.XAPI.Attributions` owns the attribution extension and currently emits assignment, exposure, outcome, reward, policy-update, rollup, and media roles.
  - Delivery attempt snapshots and `Oli.Analytics.XAPI.Events.Attempt.ActivityAttemptEvaluated` already emit score, denominator, attempt GUID/number, activity/revision, page, section, project, a publication value, and evaluation time. The publication value is currently resolved when the asynchronous snapshot worker runs, so it is not guaranteed to be the publication under which the attempt began.
  - `Oli.Analytics.XAPI.ClickhouseUploader`, `Oli.Analytics.Backfill.QueryBuilder`, and `cloud/xapi-etl-processor/lambda_function.py` are the three projection implementations that must agree.
  - ClickHouse `raw_events` and `experiment_attributions` use `ReplacingMergeTree`; the latter already defaults missing `assignment_scope` to `intervention` and joins through the host-event hash.
  - Publications and published resources bind learner delivery to immutable revisions, and page/activity attempts preserve historical attempt identity.
  - `resource_attempts` already persists the realized page `content` and page `revision_id`. The realized content retains each Alternatives placement wrapper and only its selected child, so it is an immutable learner-attempt snapshot that proves placement ID, Alternatives resource ID, selected option, and containment of activity/content elements.
  - `activity_attempts` already persists activity resource/revision, parent resource-attempt ID, attempt GUID/number, score, denominator, and evaluation time. `part_attempts` persists its parent, part ID, attempt GUID/number, score, denominator, and evaluation time.
  - `resource_accesses` supplies page resource, section, and user. The unique section/user enrollment supplies `enrollment_id`; `section_resources` supplies project ownership. Experiment assignments already persist enrollment, section, experiment, condition, scope, assignment time, and nullable intervention identity. Interventions persist page resource and placement/content-element identity.
  - Exact publication identity is an existing platform-level attempt provenance gap. The snapshot worker resolves the section's current publication after evaluation. A section can advance after an attempt begins, and one immutable revision can appear in multiple publications, so exact attempt-time publication cannot be reconstructed reliably from revision plus the current deployment. This work documents but does not fix that behavior.
- Unknowns to confirm during detailed design/implementation:
  - Which existing navigation and nested-content statement producers are in the supported first implementation set. The contract supports the generic `interaction` role, but every producer must have a stable host-event identity and immutable placement evidence before it is enabled.
  - Whether production Lambda currently targets `raw_events` directly or a ClickHouse materialized view. The normalized row builder must remain identical either way.
  - The stable QA environment identifiers and access procedure to document in the operator runbook; these are environment configuration, not design decisions.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

1. `Oli.Experiments` owns a set-based `resolve_event_attributions/2` boundary. Inputs are a validated delivery `Scope` and one or more event provenance records; outputs are zero or more normalized assignment-backed attribution facts per event. It reuses the existing active-participation lookup and branch-containment logic rather than duplicating it in analytics modules.
2. Event provenance contains stable host facts only: event key/type, page resource and deployed page revision, content element/placement, activity resource and revision where applicable, resource/activity/part attempt identity and number, and occurrence time. For asynchronous attempt events the producer reloads the persisted attempt hierarchy and realized `resource_attempts.content`; it never accepts browser-reported experiment identity as authoritative. Publication ID continues to use the existing snapshot-pipeline lookup of the section/project's current deployment; exact attempt-time publication is deferred to separate platform work.
3. `Oli.Experiments.XAPI.Attributions` converts resolved facts into the existing extension. Add generic `interaction` as a host role, and extend bounded fields needed for assignment time, exposure time, observed time, placement, selected alternative, page/activity/attempt identities, raw score, and denominator. It continues emitting distinct `attribution_type` values for assignment, exposure, outcome, reward, and policy update.
4. Every supported xAPI producer builds its ordinary host statement first, requests applicable attributions, and attaches zero or more entries. Activity-attempt statements are emitted regardless of whether attribution resolution returns any relationship.
5. A shared projection specification, documented next to the xAPI schema, defines source JSON paths, types, null/default rules, allowed role/type pairs, and hash algorithms for both ClickHouse tables. Elixir direct upload, Python Lambda, and Elixir S3 backfill implement this specification and share golden JSONL fixtures.
6. ClickHouse migrations add only nullable columns without data-producing defaults and indexes required by scoped compatibility queries. A repository-owned, parameterized SQL script left-joins activity-attempt `raw_events` to attribution rows by `raw_event_hash`, applies the half-open assignment window, and yields enrollment, condition, observed timestamp, and normalized correctness without consulting PostgreSQL. Companion xAPI-inspection commands, diagnostic SQL, and expected-result artifacts support repeatable local acceptance and optional QA verification.
7. Existing experiment telemetry is supplemented by bounded projection and data-quality counters/queries. AppSignal receives counts, status, role, assignment scope, host event type, ingestion path, and duration; it does not receive learner, content, response, or policy-state payloads.

### 4.2 State & Data Flow

```text
PostgreSQL assignment + deployed publication/revision + attempt snapshot
    -> Oli.Experiments resolves selected-branch relationship
    -> xAPI host statement with zero..N experiment_attributions
    -> asynchronous upload pipeline
    -> S3-compatible durable JSONL (local MinIO / deployed S3)
       -> inspect and schema-validate persisted statements
       -> direct ClickHouse uploader / SQS-Lambda / replay-backfill
       -> raw_events (exactly one logical host row)
       -> experiment_attributions (one logical row per attached attribution)
    -> compatibility query LEFT JOINs on raw_event_hash
```

- Assignment occurrence uses original `assigned_at`, including assignment reuse.
- Exposure occurrence uses `exposed_at`; repeated rendering reuses the logical exposure key for the same assignment/intervention/placement/revision, while different interventions have distinct keys.
- Interaction occurrence uses the host statement timestamp.
- Evaluated outcome occurrence uses `activity_attempt.date_evaluated` as `observed_at`, not projection time.
- Reward and policy-update occurrence retain their accepted transaction timestamps. `inserted_at` is ingestion metadata and never substitutes for an occurrence time.
- A section-and-enrollment assignment can have a null assignment-level `intervention_id`; each exposure or causal interaction/outcome carries the actual intervention and immutable branch placement.

#### 4.2.1 Persisted Provenance Inventory

| Required fact | Existing durable source | Resolution | PostgreSQL change |
| --- | --- | --- | --- |
| Page attempt identity/number | `resource_attempts.id`, `attempt_guid`, `attempt_number` | Direct | None |
| Page resource | `resource_accesses.resource_id` | Join from resource attempt | None |
| Page revision | `resource_attempts.revision_id` | Direct immutable revision | None |
| Realized selected branch | `resource_attempts.content` | Traverse retained Alternatives placement and selected child | None |
| Placement/content element | Alternatives element `id` in `resource_attempts.content`; `experiment_interventions.content_element_id` | Match by page resource and element ID | None |
| Alternatives resource | Alternatives element `alternatives_id`; `experiment_definitions.alternatives_resource_id` | Match realized placement to experiment | None |
| Selected option/condition | Sole retained child `value`; assignment condition `option_id`/code | Require selected branch and assigned condition to agree | None |
| Activity resource/revision | `activity_attempts.resource_id`, `revision_id` | Direct | None |
| Activity attempt identity/number | `activity_attempts.id`, `attempt_guid`, `attempt_number` | Direct | None |
| Part identity/attempt | `part_attempts.part_id`, `id`, `attempt_guid`, `attempt_number` | Direct | None |
| Score, denominator, evaluation time | Activity/part attempt `score`, `out_of`, `date_evaluated` | Direct | None |
| Section and user | `resource_accesses.section_id`, `user_id` | Join from resource attempt | None |
| Enrollment | `enrollments` by section/user and assignment `enrollment_id` | Require the scoped enrollment and assignment to agree | None |
| Project | `section_resources.project_id` for page/section and experiment `project_id` | Require scoped project agreement | None |
| Assignment, scope, condition, assigned time | `experiment_assignments` | Direct | None |
| Intervention | `experiment_interventions` by experiment, page resource, and placement ID; assignment intervention for intervention scope | Resolve actual placement even when assignment-level intervention is null | None |
| Publication on asynchronous attempt xAPI | Current section/project deployment, resolved by `AttemptGroup.pub_id_for_section_project/2` | Preserve existing behavior; may differ from attempt-time publication after an update | None; known deferred issue |

No fields are added to the legacy `snapshots` table. In this design, "attempt snapshot" refers to the persisted attempt hierarchy—especially `resource_attempts.content`—not the legacy analytics `snapshots` rows created per part attempt.

### 4.3 Lifecycle & Ownership

- Assignment and Thompson policy mutation remain PostgreSQL transactions owned by `Oli.Experiments`. This feature does not make ClickHouse or xAPI a runtime decision dependency.
- Exposure/outcome operational receipts remain in assignment runtime state where currently required for synchronous idempotency. Durable analytical consumers read xAPI-derived projections.
- Attempt evaluation owns activity-attempt host-event creation. Experiment attribution is enrichment and cannot suppress or roll back an otherwise valid host event.
- S3 owns replay durability after upload. ClickHouse rows are replaceable projections and may be rebuilt from the same statements.
- Publication/revision and attempt snapshots own provenance throughout historical replay; mutable authoring content is never queried.

### 4.4 Alternatives Considered

- Store all compatibility outcomes as experiment attribution rows: rejected because it would falsely imply causality for section-wide or out-of-branch activity outcomes and would drop outcomes with no attribution.
- Query PostgreSQL assignments and attempt summaries for export: rejected because it couples analytics to private transactional schemas, mutable operational retention, and current content; it also cannot guarantee path parity with replay.
- Persist attempt-time publication as part of this feature: deferred because the mismatch predates native experiments and affects the platform-wide asynchronous xAPI snapshot pipeline. This work preserves current lookup behavior and relies on immutable page/activity revisions for experiment containment; the separate issue draft defines the broader fix.
- Add experiment, placement, or selected-option fields to activity attempts or legacy snapshots: rejected because `resource_attempts.content`, assignment, condition, and intervention records already supply those facts. Duplicating them would add write paths and divergence risk without closing a provenance gap.
- Introduce a new experiment-specific event stream or transactional outbox: rejected because the PRD explicitly retains the existing xAPI durability boundary and accepted crash window.
- Duplicate branch logic in each statement producer or ETL path: rejected because assignment identity and containment semantics must remain owned by `Oli.Experiments` and replay cannot safely consult mutable content.
- Add a feature flag: not selected because consumers tolerate additive nullable/defaulted fields and producer/consumer deployment ordering provides the rollback boundary. A flag would create mixed evidence semantics without eliminating schema rollout requirements.

## 5. Interfaces

- Experiment resolution interface:
  - Input: validated `Oli.Experiments.Scope` plus a bounded list of event provenance structs/maps.
  - Output: `{:ok, %{event_key => [attribution_fact]}}` or a scoped `ExperimentError`; no match is `[]`, not an error.
  - Contract: one set-based assignment query per scope batch, historical strategy aliases accepted, and only immutable selected-branch matches returned.
- xAPI extension interface:
  - Location: `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]`.
  - Required per entry: non-empty stable `key`, `role`, `attribution_type`, `experiment_id`/UUID, `assignment_id`/key/scope, `condition_id`/code, `section_id`, `enrollment_id`, and the occurrence timestamp applicable to its type.
  - Assignment entries include original `assigned_at`, algorithm, policy version, reuse state, and nullable intervention identity.
  - Exposure/interaction/outcome entries include actual intervention, placement/content element, selected alternative, the publication value available through the existing producer path, page/content revision, and applicable attempt identities. Outcome entries additionally preserve score, `out_of`, and `observed_at`. For asynchronous attempt statements, publication retains current-deployment semantics and page/activity revision IDs provide immutable content provenance.
  - Allowed roles are bounded: the existing semantic roles plus `interaction`; `role` describes the host relationship and `attribution_type` describes the evidence carried. Schema validation rejects unknown role/type combinations and missing keys.
- ClickHouse projection interface:
  - `raw_events.event_hash` is the host join key and gains additive `enrollment_id`, stable resource/attempt fields needed by AC-012, and `observed_at` if a distinct alias is needed for query clarity.
  - `experiment_attributions.raw_event_hash` joins to the host row; `attribution_hash` is the row idempotency key. It gains additive bounded provenance, score/denominator, and occurrence timestamp columns needed by the expanded extension.
  - Missing historical `assignment_scope` reads as `intervention`; missing optional provenance remains null and is never fabricated.
- Compatibility query interface:
  - Inputs: tenant-scoped section/project or experiment filters and an exclusive execution/requested end.
  - Output: one row per applicable enrollment/activity attempt, with condition columns nullable where no causal attribution exists, plus assignment scope, assignment/intervention provenance when present, `observed_at`, raw score, denominator, and normalized correctness.
  - It starts from `raw_events FINAL` filtered to `event_type = 'activity_attempt'`, left-joins deduplicated attribution rows by hash, and applies assignment windows only to attributed relationships.
  - The checked-in script must expose clearly documented ClickHouse CLI parameters or substitution variables; it must not embed environment names, credentials, or production identifiers.
  - Companion scripts query row counts, orphan hashes, duplicates, missing expected attribution, scope defaults, reward/policy joins, and ingestion lag so an operator can distinguish bad seed data, incomplete ingestion, and an incorrect compatibility result.

## 6. Data Model & Storage

- PostgreSQL:
  - No PostgreSQL schema changes are required. Existing assignments, attempts, revisions, resource access, enrollment, intervention, and section-resource records supply the facts required for assignment-backed containment and outcome evidence.
  - Do not add columns to `resource_attempts`, `activity_attempts`, `part_attempts`, experiment assignments, experiment interventions, or the legacy `snapshots` table. Do not store a second copy of page content, a serialized attribution list, or unbounded experiment state. `resource_attempts.content` already contains the immutable realized page necessary for containment.
  - Continue resolving asynchronous host-statement publication through the existing `AttemptGroup.pub_id_for_section_project/2` pattern. Do not infer, populate, or migrate an attempt-time publication value as part of this work.
- xAPI/S3:
  - The persisted statement is the canonical replay record. Add fields within the existing attribution extension and existing context extensions. Do not include learner name/email/LMS ID, raw response, free-form content, or full policy state.
  - Local verification uses the repository's MinIO `torus-xapi-dev` bucket and its CLI-accessible S3-compatible object layout. Environment-parameterized inspection must also support an authorized deployed S3 xAPI bucket without embedding credentials or bucket names.
- ClickHouse `raw_events` additive columns:
  - `enrollment_id Nullable(UInt64)`.
  - Preserve or add stable `activity_id`, `activity_revision_id`, `page_id`, activity/page/part attempt GUID and number, `score`, `out_of`, and statement `timestamp`; define `observed_at` as the statement timestamp for evaluated activity attempts in the compatibility view rather than duplicating storage unless query evidence shows a separate column is required.
  - Add minmax/bloom indexes only for measured common filters such as enrollment and activity-attempt event type.
- ClickHouse `experiment_attributions` additive columns:
  - Assignment/exposure timing: `assigned_at`, `exposed_at`, `observed_at` as nullable `DateTime64(3)`.
  - Provenance: selected alternative/option identity, placement/content-element identity, page resource/revision, activity resource/revision, activity/part attempt GUID/number, and outcome key as nullable bounded scalar columns.
  - Outcome values: raw `score` and `out_of` as nullable `Float64`; retain reward fields separately.
  - Existing nullable assignment-level `intervention_id` remains valid for `section_enrollment` assignment rows. Event-level exposure/interaction/outcome rows require the actual intervention when causal.
- ClickHouse migrations are additive, schema-only, and reversible. Every column newly introduced by this work is nullable and has no data-producing default. Migration `Up` clauses only add columns/indexes; they contain no `UPDATE`, `INSERT ... SELECT`, materialization, mutation, replay, or historical derivation. Existing rows remain unchanged and null in those columns. Migration `Down` clauses remove only the newly added columns/indexes. No PostgreSQL migration is created for this work.
- The existing historical interpretation that a missing `assignment_scope` means `intervention` is a read/projection compatibility rule for the already established field; it is not authorization to populate any new column or mutate historical rows.

## 7. Consistency & Transactions

- Assignment creation/reuse and Thompson reward/posterior mutation retain their existing PostgreSQL transaction, locking, and idempotency boundaries (FR-002, FR-007).
- xAPI emission remains asynchronous after the transaction. A failure after PostgreSQL commit but before durable S3 persistence is visible through telemetry and cannot be repaired by this work.
- Stable logical keys are producer-owned:
  - assignment key: existing canonical assignment key;
  - exposure key: assignment + intervention + placement + deployed revision;
  - interaction/outcome key: assignment + host event/attempt identity + role;
  - reward and policy-update keys: existing accepted reward and policy update keys.
- Direct and replay projection calculate hashes from the same raw statement bytes/JSON line and attribution key. `ReplacingMergeTree` converges duplicate inserts; queries that require immediate deduplication use `FINAL` or an equivalent `argMax` view.
- A malformed attribution extension fails that statement's attribution projection with an explicit diagnostic; it must not silently invent data. The raw host-event projection remains independently recoverable from S3 and can be replayed after correction.

## 8. Caching Strategy

- No new cross-request cache is introduced. Assignment and branch resolution correctness depends on section, enrollment, publication, revision, and attempt provenance; caching without all dimensions risks cross-tenant or stale attribution.
- Within one evaluation/snapshot batch, group provenance by delivery scope and reuse the existing set-based assignment query and parsed immutable page content. This request-local reuse avoids N+1 queries without creating invalidation responsibilities.
- ClickHouse projections and the compatibility query are analytical storage/query paths, not caches of runtime decisions.

## 9. Performance & Scalability Posture

- Preserve one bounded assignment query per scope batch rather than one query per event or activity. Existing reward-handoff query-count telemetry provides the pattern for attribution resolution.
- xAPI extension size grows with proven decision points only. Deduplicate attributions by stable key before serialization and do not attach all assignments in a section/page.
- Direct upload and Lambda continue bounded batch/sub-batch insertion. Adding scalar nullable columns must not introduce per-row network/database lookups.
- The compatibility query must predicate by tenant/section and time before joining, filter `raw_events` to `activity_attempt`, and join on ordered hash keys. Validate query plans and partition pruning on representative multi-section data.
- No hard latency/throughput budget is added because `harness.yml` excludes performance requirements by default and the PRD specifies no numeric SLO. Regression gates are bounded query count, bounded payload cardinality, no unscoped scans, and no material degradation in existing ingestion benchmarks/telemetry.

## 10. Failure Modes & Resilience

- No matching assignment or branch: attach no causal attribution; still emit/project the host event.
- Stale or browser-forged experiment identifiers: ignore them and resolve from scoped assignment plus immutable server-side provenance.
- Deployed revision cannot be resolved: return a scoped attribution error, emit a bounded diagnostic, and preserve the ordinary host event where safe; never fall back to mutable authoring content.
- Section publication changes between attempt creation and asynchronous snapshot execution: preserve existing behavior by emitting the current section/project publication. Continue using immutable attempt page/activity revisions for containment, expose the limitation in verification notes, and defer exact publication correction to the separate platform issue.
- Missing historical `assignment_scope`: normalize to `intervention` only in analytics interpretation.
- Historical rows with null values in columns added by this work: accept them as incomplete historical evidence. Queries expose the nulls or apply only the explicitly documented compatibility calculation; they must not imply that unavailable provenance was reconstructed.
- Invalid/missing score or denominator: retain nullable/raw values; compatibility normalization returns `0.0` according to the documented rule and exposes a bounded data-quality classification.
- Duplicate direct upload, SQS retry, replay, or overlapping backfill: deterministic host and attribution hashes converge to one logical row.
- Partial raw/attribution projection: detect orphan attribution hashes and host rows with expected-but-missing attribution; replay the durable statement rather than synthesizing evidence.
- Lambda/direct/backfill disagreement: fail golden contract tests and expose path/version counters so operators can identify the producer.
- Pre-S3 crash: surface xAPI pipeline failure/lag telemetry; no recovery guarantee.
- Scenario completed but no matching object appears in MinIO/S3: fail the local acceptance automation at the durable-boundary check and use pipeline queue/upload telemetry before attempting ClickHouse verification.
- Persisted xAPI is malformed or missing expected assignment/attribution/provenance fields: fail schema and semantic inspection before projection; preserve the object/hash as diagnostic evidence and resolve the producer defect rather than compensating in ClickHouse SQL.

## 11. Observability

- Reuse AppSignal/Telemetry conventions and add bounded events for attribution resolution duration/status, matched assignment count, assignment query count, emitted attribution count by role/scope/host type, schema rejection, projection count/failure/duration by path, and ingestion lag buckets.
- Provide scoped diagnostic queries for assignment without exposure, exposure without later attributed interaction/outcome, activity outcomes expected to be in-branch but missing attribution, accepted reward without reward/policy projection, orphan attribution/raw hashes, path/version disagreement, and assignment imbalance.
- Logs include stable event/attribution hashes, section/project IDs where operationally necessary, bounded status/reason codes, and ingestion path. They exclude enrollment/user identifiers unless a tightly scoped support path explicitly requires enrollment and is access controlled; routine metrics never use enrollment as a dimension.
- Document expected AppSignal signals and operator queries in an analytics/experiment runbook. Existing xAPI queue size/upload duration metrics remain the primary crash-window and lag indicators.

## 12. Security & Privacy

- Validate institution/project/section/enrollment participation before resolving assignments. Queries must scope assignments through the participating section and deployed project/publication.
- Treat client-supplied event details as locators only; authoritative assignment, condition, intervention, publication, revision, and branch containment come from server-side state.
- Use `enrollment_id` as the pseudonymous analysis unit. Do not add names, emails, LMS IDs, actor identifiers, raw responses, free-form page/activity content, or unbounded policy JSON to attribution payloads, ClickHouse attribution rows, compatibility output, or telemetry.
- Parameterize runtime analytical queries and retain existing identifier sanitization for configurable ClickHouse table names. Backfill credentials remain process configuration and must not appear in generated SQL/logs.
- Future export authorization is out of scope, but the repository-owned query must require explicit tenant/section or experiment scope so it cannot become an unbounded cross-tenant primitive.

## 13. Testing Strategy

- Elixir unit tests:
  - assignment attribution for intervention and section-enrollment scopes, original assignment time on reuse, nullable assignment-level intervention, and distinct intervention exposures (AC-002 through AC-006);
  - selected-branch containment for multiple decision points and canonical/historical strategy values, including activity, part, media, navigation, nested content, out-of-branch events, and immutable asynchronous reconstruction (AC-007 through AC-009, AC-021);
  - activity outcome values/timestamps and independence from weighted-random rewards and Thompson reward/policy evidence (AC-010, AC-011, AC-014 through AC-016);
  - privacy allowlists, bounded cardinality, hash/key stability, and old evidence defaults (AC-020, AC-022, AC-023).
  - selected-branch resolution uses the existing realized resource-attempt content with no additional snapshot fields; a regression test documents that asynchronous publication continues to come from the current section/project deployment until the deferred platform issue is implemented.
- Projection contract tests:
  - run identical golden JSONL fixtures through the Elixir direct transformer, Python Lambda row preparation, and backfill SQL expectations; compare normalized logical rows for all fields, nulls/defaults, roles, and hashes (AC-018 through AC-020);
  - cover historical statements without scope/new fields and malformed role/type pairs;
  - run Lambda tests in `cloud/xapi-etl-processor/tests` and targeted ExUnit uploader/backfill tests.
- ClickHouse integration tests:
  - insert representative historical rows before migrating, migrate up, and assert those rows remain byte/logically unchanged with null values in every new column; inspect migration SQL to reject data mutations or data-producing defaults;
  - migrate up/down, insert new statements, duplicates, and replays, assert one logical raw row and one row per attribution, and validate left-join behavior and partition-scoped query plans (AC-012, AC-013, AC-019, AC-020).
- `Oli.Scenarios` integration coverage:
  - real project authoring, both Alternatives strategy spellings, publishing, participating sections, two enrollments for one user, repeated views, both weighted-random scopes, Thompson Sampling, multiple decision points/activities, in/out-of-branch interactions and outcomes, reward/policy evidence, and replay (AC-001, AC-025, AC-026).
  - Extend the scenario DSL only if existing directives cannot express evidence inspection; keep domain setup fixture-free.
  - Provide a deterministic acceptance-seed scenario, or a small documented set of scenarios, that can run against local development and the designated QA instance. It must emit stable labels or otherwise record the created section, experiment, enrollment, and time-window identifiers needed by the SQL scripts.
- Compatibility proof:
  - versioned SQL plus expected-result artifacts reconstruct enrollment, condition, observed timestamp, and correctness from ClickHouse alone and verify the half-open window, pause behavior, null-attribution inclusion, and zero/invalid/missing normalization (AC-017, AC-025);
  - ordinary CI does not provide ClickHouse, so CI validates schema, projection parity, deterministic hashes, scenario behavior, SQL presence/structure, and expected-result fixtures without claiming live ClickHouse execution;
  - local acceptance follows the durable data path in order: seed with scenarios, locate the new JSONL objects in MinIO, validate and inspect their xAPI statements, wait for/trigger the supported projection path, then execute the diagnostic and compatibility SQL against local ClickHouse;
  - live SQL execution and successful MinIO xAPI inspection are required acceptance steps against the local development services. QA execution is not an acceptance gate for this work item.
- Manual verification:
  - add a checked-in environment-parameterized operator runbook with prerequisites, environment-safety checks, scenario commands, identifier/time-prefix capture, MinIO/S3 CLI object discovery and download, xAPI schema and semantic inspection, ingestion-wait checks, parameterized ClickHouse commands, expected results, diagnostics, evidence capture, cleanup guidance, and an operator sign-off checklist;
  - provide a developer automation entrypoint that performs the safe local sequence using CLI-accessible MinIO and ClickHouse, accepts explicit seed identifiers/time bounds, stops on missing or invalid xAPI, and leaves inspectable evidence on failure so defects can be resolved during development;
  - execute the automated or step-by-step runbook against local MinIO and ClickHouse for feature acceptance; inspect representative persisted statements and projected rows, compare supported projection paths, and exercise missing-evidence and lag diagnostics;
  - keep the runbook adaptable to any authorized environment, including QA, so operators can repeat the same verification after the work lands without changing repository scripts or embedding environment-specific credentials and identifiers.
- Required automated gates include targeted `mix test` and `mix format` with escalation, Python Lambda tests/formatting used by that package, scenario validation and runner, xAPI schema/semantic fixture checks, SQL artifact checks, `git diff --check`, security review, performance review, and requirements review. The required local acceptance gate is successful scenario seeding, MinIO xAPI inspection/validation, and ClickHouse verification with captured evidence. QA execution is optional post-landing verification.

The implementation plan must produce, at minimum, these repository artifacts (final paths may follow existing analytics conventions):

- deterministic `Oli.Scenarios` acceptance-seed YAML and companion ExUnit runner;
- an environment-parameterized xAPI inspection/validation script or task that discovers the scenario's objects, validates each JSONL statement, checks expected attribution roles/fields and privacy exclusions, and records object keys plus statement hashes;
- parameterized UpGrade-compatibility ClickHouse SQL;
- parameterized ClickHouse diagnostic SQL for ingestion completeness, joins, duplicates, and data-quality conditions;
- expected-result fixture or assertion table tied to the deterministic seed scenario;
- a safe developer automation entrypoint chaining scenario seed, local MinIO inspection, ingestion readiness, and local ClickHouse verification;
- an environment-parameterized operator runbook with a complete checklist and evidence-recording template, proven locally and reusable with an authorized QA S3 bucket/ClickHouse instance or another system.

## 14. Backwards Compatibility

- Existing xAPI statements without experiment extensions continue to project as raw host rows with zero attribution rows.
- Historical attribution entries lacking the previously established `assignment_scope` field normalize to `intervention`; all columns newly added by this work are nullable and remain null when the source statement lacks the value.
- No migration populates or backfills historical rows. Columns introduced by this work are nullable without derived defaults, and null is the expected value for existing events whose persisted statements do not contain the new evidence.
- Existing and new resource attempts remain schema-compatible. Asynchronous host statements retain the existing current-deployment publication semantics; exact attempt-time publication is not claimed by this feature. Exposure events emitted during delivery retain their contemporaneous publication value, while immutable page/activity revision IDs remain the authoritative content provenance for delayed outcome containment.
- Both `experiment_controlled` and `upgrade_decision_point` content are resolved without rewriting or republishing.
- Existing experiment assignment, selection, participation, reward, posterior, and policy-state behavior does not change. Weighted-random outcomes require no reward; Thompson remains intervention-scoped.
- Deploy ClickHouse/schema consumers before or with new producers. Rolling producer rollback leaves additive columns unused and does not invalidate old readers. Replay/backfill tooling may project new values only when explicitly invoked against durable S3 statements after deployment; it is not part of the schema migration or required to populate historical data.
- No feature flag is used. Operational rollback disables/reverts new enrichment producers while retaining additive schema and already captured evidence.

## 15. Risks & Mitigations

- Over-attribution from page-level state: require assignment-backed selected-branch containment and specific intervention/placement/revision evidence.
- N+1 assignment/content lookups: batch by scope, reuse parsed snapshots, and assert query counts.
- Divergent projection implementations: one field-mapping specification, golden cross-language fixtures, and logical-row parity tests.
- Hash divergence from JSON normalization: hash the exact persisted JSON line consistently; fixtures include whitespace/order-sensitive cases and document byte expectations.
- `ReplacingMergeTree` duplicates visible before merges: compatibility/diagnostic queries use `FINAL` or `argMax`, and idempotency tests run before and after optimization.
- Conflating outcomes and rewards: retain distinct types, keys, timestamps, columns, and tests even when one evaluation yields both.
- Increased payload/storage volume: bounded scalar fields, proven relationships only, no content/policy blobs, and monitored rows/bytes per host event.
- Privacy leakage through general `raw_events.response`: the compatibility query explicitly selects an allowlist and never exposes response/actor columns; attribution additions prohibit these values.
- Irrecoverable pre-S3 loss: document the boundary and alert on pipeline failure/lag rather than claiming replay completeness.

## 16. Open Questions & Follow-ups

- Confirm the exact first-release list of navigation and nested-content xAPI producers after waypointing their stable event keys and immutable provenance. Producers that cannot meet the contract remain unsupported until they can; this does not weaken required activity-attempt compatibility coverage.
- Confirm the production Lambda target topology (table versus materialized view) before choosing where its normalized dual-row projection is implemented.
- MER-5889 tracks the deferred asynchronous xAPI publication-provenance bug. Do not implement it in this work item.
- When QA verification is scheduled after landing, supply its connection/access procedure and evidence-storage location through environment-specific operator configuration without committing credentials.
- Follow-up outside this work item: design the authorized user-facing export/API using the compatibility query and documented half-open window.

## 17. References

- `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/prd.md`
- `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/requirements.yml`
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
- `docs/design-docs/publication-model.md`
- `docs/design-docs/attempt.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/runtime_evidence.ex`
- `lib/oli/experiments/xapi/attributions.ex`
- `lib/oli/analytics/xapi.ex`
- `lib/oli/analytics/xapi/clickhouse_uploader.ex`
- `lib/oli/analytics/backfill/query_builder.ex`
- `cloud/xapi-etl-processor/lambda_function.py`
- `priv/clickhouse/migrations/20260714120000_add_experiment_columns_to_raw_events.sql`
- `priv/clickhouse/migrations/20260811190000_add_experiment_intervention_evidence.sql`
- `priv/clickhouse/migrations/20260814120000_add_experiment_assignment_scope.sql`
- Jira MER-5883, MER-5884, MER-5885, and MER-5795
