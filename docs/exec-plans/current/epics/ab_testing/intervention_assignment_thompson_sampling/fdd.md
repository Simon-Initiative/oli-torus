# Intervention-Scoped Assignment and Assessment-Driven Thompson Sampling - Functional Design Document

## 1. Executive Summary

Extend the existing `Oli.Experiments` subsystem rather than introducing a second experiment runtime. The design separates experiment-owned treatment/policy state, placed intervention instances, per-intervention assignments, and scored-page assessment bindings. A learner assignment becomes sticky on `(section enrollment, experiment, intervention)` while all accepted rewards for the experiment's interventions update its shared PostgreSQL posterior.

Authoring continues to store reusable Alternatives Groups as versioned resources and placement-local content in page revisions. Group strategy is the sole selection authority. New experiment-controlled groups use `experiment_controlled`; `upgrade_decision_point` is normalized only at read and ingest boundaries. Delivery performs one bounded active-experiment relevance check before resolving bindings, creates assignments transactionally, renders the persisted alternative, and emits detailed evidence asynchronously. Finalized scored-page attempts enqueue an Oban handoff that claims one reward and updates one policy snapshot atomically.

This design requires replacing the pre-release decision-point and mapping storage with experiment, condition, intervention, assignment, and policy-state storage, plus an ordinary ClickHouse migration where evidence dimensions change. Existing Alternatives content requires no backfill or forced republication, while QA-only experiment operational and analytical rows may be discarded.

## 2. Requirements & Assumptions

- Functional requirements:
  - Experiment structure and binding: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-017, FR-018, FR-019, FR-020.
  - Assignment and policies: FR-007, FR-008, FR-009, FR-010, FR-021, FR-022, FR-027.
  - Alternatives non-nesting structure: FR-034.
  - Assessment rewards and evidence: FR-011, FR-012, FR-013, FR-014, FR-015, FR-016, FR-023, FR-024, FR-032.
  - Compatibility and authoring surfaces: FR-025, FR-026, FR-028, FR-029, FR-030, FR-031, FR-033.
  - Acceptance traceability: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, and AC-033 are verified by the corresponding test categories in section 13.
- Non-functional requirements:
  - Assignment and reward operations use bounded PostgreSQL queries only; ClickHouse and xAPI are evidence sinks, never runtime sources.
  - Database uniqueness and row locking make assignment and reward operations concurrency-safe and idempotent.
  - Delivery without a relevant active experiment pays for only one indexed relevance query.
  - Telemetry dimensions are bounded and exclude raw responses and unnecessary learner identity.
  - Preview is inert and keyboard accessible. Learner progress and completion use a learner-specific denominator containing only content and activities from the persisted displayed alternative at each intervention, ensuring every assignment path can reach 100%.
  - PostgreSQL migrations use generated filenames and explicit `up/0` and `down/0`; ClickHouse changes use ordinary reversible migrations.
- Assumptions:
  - A condition has one stable identity within an experiment and represents a comparable treatment at every intervention where applied.
  - The stable intervention key is the page resource ID plus the page element's stable `id`; revision and publication IDs are evidence only.
  - Whole-page moves preserve the page resource ID. Page duplication creates a new page resource ID while preserving copied content-element IDs; same-page element copy or recreation generates a new element ID.
  - Existing finalized scored-page attempt ordering and normalized overall page scores are authoritative; experiment code does not recompute scoring.
  - Existing Thompson Sampling guardrail semantics remain valid at experiment scope.
  - No feature flag is added, consistent with the PRD and `harness.yml` default. Rollout is controlled by valid draft activation and normal deployment.
  - Jira is the issue system of record, but this design performs no Jira writes.
  - Both Alternatives strategies may be placed inside ordinary content containers, but no Alternatives placement may have another Alternatives placement as an ancestor.
  - The experiment feature is deployed only in QA. Migration code need not backfill, transform, or preserve pre-release experiment rows, and no mixed-version web/worker compatibility period is required.

## 3. Repository Context Summary

- What we know:
  - `Oli.Experiments` already owns experiment lifecycle, assignment, policy state, reward persistence, validation, telemetry, and public authoring/runtime APIs.
  - Experiment persistence is singular: the definition owns its Alternatives Group, conditions, interventions, assignments, and one JSON policy state; the obsolete decision-point schemas have been removed.
  - `Oli.Resources.Alternatives` resolves strategy from the loaded Alternatives Group, while `ExperimentControlledStrategy` prepares delivery decisions and evidence.
  - `Oli.Delivery.Experiments.PageDecisions` discovers placement group references from attempt-pinned page content and loads group revisions through `DeliveryResolver`.
  - `RewardHandoffWorker` already provides asynchronous post-commit processing, but `RewardHandoff` currently derives full-credit rewards from activity attempts rather than finalized scored-page attempts.
  - `ExperimentsLive`, `ExperimentDetailsLive`, and `AlternativesLive` own the current authoring UI. Group management logic is duplicated and currently writes `upgrade_decision_point` on the Experiments page.
  - `Oli.Interop.Export` and `Oli.Interop.Ingest.Processor` already serialize Alternatives resources and rewire page references.
  - `priv/schemas/v0-1-0/content-alternatives.schema.json` currently requires element-level `strategy` and does not require `alternatives_id`, contrary to the target contract.
  - Published revisions and learner attempts pin delivered content, so intervention lookup must use page resource identity while recording the actual revision/publication as evidence.
- Unknowns to confirm:
  - None block architecture. During detailed design, confirm the exact scored-page final lifecycle states and the canonical persisted attempt ordering column before writing the reward eligibility query.
  - Confirm same-page copy/reinsert operations regenerate the Alternatives placement ID. Whole-page duplication must preserve content-element IDs because its new page resource ID already creates a distinct intervention and blanket regeneration could break unrelated page-local references.
  - Confirm the current ClickHouse raw-event schema version at implementation time before naming the additive migration columns.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.Experiments` remains the public domain boundary and is split internally into focused services as implementation proceeds:

- `Configuration` validates draft definitions, the experiment group binding, experiment-owned conditions and bijective mapping, Thompson Sampling interventions and bindings, lifecycle restrictions, and deletion dependencies. Weighted-random configuration contains no author-managed interventions.
- `Strategy` normalizes group strategy: `experiment_controlled` and `upgrade_decision_point` both become internal `:experiment_controlled`; unsupported values fail closed.
- `Assignments` resolves the active experiment and intervention, reads one policy snapshot, samples through the existing policy modules, and inserts or returns the unique persisted assignment.
- `Rewards` resolves finalized assessment attempts, claims accepted rewards, updates posterior state, and writes compact evidence in one transaction.
- `Reporting` returns a bounded policy snapshot DTO for the details LiveView, including posterior, counts, allocation, guardrail mode, warning state, and update time.

Web and delivery modules remain adapters:

- `ExperimentsLive` composes experiment listing/configuration with a shared group-management component configured for `:experiment_controlled`. The shared component is extracted from the current Experiments `Decision Points` Alternatives Groups editor, whose more polished presentation and interaction model is the UX baseline.
- `AlternativesLive` adopts that Experiments-derived component configured for `:user_section_preference`, replacing its less-polished group editor while retaining its route, Learner Choice filtering, labels, and permissions.
- `PageDecisions` performs the relevance gate, classifies Alternatives with one content-tree traversal, derives `(page_resource_id, element_id)` for valid placements, and calls one page-level assignment API for experiment-controlled groups.
- `RewardHandoffWorker` receives finalized resource-attempt IDs after the scoring transaction commits and delegates to `Rewards`.
- xAPI/ClickHouse adapters emit evidence after the PostgreSQL transaction; retryable evidence delivery does not change accepted reward state.

### 4.2 State & Data Flow

Authoring flow:

1. The management surface creates a group with an implicit immutable canonical strategy and stable option IDs.
2. Page insertion stores `{type, id, alternatives_id, children}` with placement-local child content and no strategy.
3. A draft experiment creates one group binding, stable experiment conditions, and one bijective condition-to-option mapping.
4. For Thompson Sampling, placed instances are explicitly registered as interventions using page resource ID and element ID, with one distinct scored-page binding and threshold for each intervention. Weighted-random drafts do not register placements.
5. Activation locks the experiment definition and validates project compatibility, current-binding exclusivity, mapping completeness, all referenced working revisions, and participating sections in one transaction. It additionally validates intervention existence and distinct assessments for Thompson Sampling only.

Delivery assignment flow:

1. `PageDecisions` checks whether the section has a relevant active experiment using one indexed `exists` query. A negative result bypasses all experiment tables.
2. Group revisions are resolved for all Alternatives references in the attempt's publication-pinned content. One traversal classifies placements as valid within ordinary containers or invalid beneath an Alternatives ancestor.
3. Valid experiment-controlled placements are resolved together using project/section scope, group resource ID, page resource ID, and element ID. For weighted random, delivery bulk inserts any missing intervention identities with conflict-safe lazy materialization before assignment lookup. Thompson Sampling resolves only explicitly configured interventions and bindings. Invalid nested placements are never submitted for assignment or exposure and select their first local alternative. Missing or inapplicable adaptive bindings use the same inert fallback.
4. Revisit lookup returns the assignment by the full uniqueness key. A first encounter reads the experiment's committed policy-state snapshot, samples through `WeightedRandom` or `ThompsonSampling`, and inserts the assignment with delivery evidence.
5. On uniqueness conflict, the transaction discards its speculative choice, reloads the winning assignment, and records a concurrency-resolution signal. Only a successful insert increments assignment counts.
6. Rendering, progress, and completion use the persisted assignment's mapped option ID, never an element strategy or a new sample. Progress/completion denominator construction traverses only each persisted displayed alternative and excludes every hidden sibling, so learners with any valid combination of intervention assignments can reach 100% after completing all content they were shown.

Reward flow:

1. Final scored-page evaluation commits independently, then enqueues the resource-attempt ID.
2. The worker finds assessment bindings for the scored page and same section/project, ordered by the existing attempt sequence.
3. For each binding/enrollment, the earliest eligible attempt governs: pending blocks later attempts; the first successfully finalized attempt proceeds; later attempts and reevaluations become bounded skips.
4. The worker resolves the assignment for the bound intervention. Missing assignment records a skip and does not create one.
5. In one `Repo.transaction`, lock the policy-state row, insert the unique accepted-reward claim keyed by binding and source resource attempt, compute binary reward using `normalized_score >= threshold`, update only the assigned condition posterior and aggregate counts, and persist before/after state metadata.
6. Duplicate claim conflict returns the prior disposition without another update. After commit, detailed xAPI/ClickHouse evidence and latency telemetry are emitted asynchronously.

Reporting flow:

1. Draft and weighted-random experiments omit posterior presentation.
2. For non-draft Thompson Sampling experiments, `Reporting.policy_snapshot/2` reads the experiment, conditions, policy state, and grouped assignment counts in bounded queries.
3. The DTO calculates posterior mean from persisted alpha/beta, accepted successes/failures, observed assignment count/share, and effective guardrail mode. It never samples, scans reward history, or queries analytics stores.
4. Completed/archived data is unchanged, so the last committed snapshot is the frozen report.

### 4.3 Lifecycle & Ownership

- Alternatives Group resource: owns immutable strategy and stable option identity/label contract. New successor revisions may change labels only where allowed; strategy and option IDs cannot be changed through supported APIs.
- Page revision: owns placement element ID and local content. Publication/attempt pinning owns the delivered snapshot.
- Experiment: owns stable condition identities and lifecycle.
- Experiment: owns the immutable assignment algorithm, one Alternatives Group, mapping, policy parameters, and posterior state.
- Intervention: owns logical placement identity `(page_resource_id, content_element_id)` under one experiment.
- Assessment binding: owns scored-page resource ID and inclusive threshold for one Thompson intervention.
- Assignment: owns the sticky selection for one enrollment and intervention and supplies the stable visibility decision used by rendering and learner-specific progress/completion denominator construction. Publication and page-revision snapshots are not assignment state; they are captured on assignment/exposure evidence events.
- Accepted reward: owns the immutable binding/source-attempt claim and disposition. Policy state owns reduced sufficient statistics.
- Completed/archived experiment rows are append-only/read-only through supported APIs. Sequential group reuse creates a new experiment with new intervention, assignment, reward, and policy rows.

### 4.4 Alternatives Considered

- Retain a one-to-one decision-point wrapper: rejected because it preserves joins, redundant foreign keys, reconciliation, and terminology without representing additional information.
- Use multiple experiment-level configuration parameters to coordinate several groups: rejected because this would be a factorial or coordinated-treatment design with assignment and analysis semantics outside the MVP.
- Encode intervention identity in `assignment_key` only: rejected because database constraints, joins, evidence, and deletion checks require typed foreign keys and indexed columns.
- Keep weighted-random interventions exclusively author-configured: rejected because weighted random has no assessment binding and manual registration becomes stale when placements are added, copied, moved, or removed.
- Derive interventions without ever persisting identity: rejected because assignments, evidence, concurrency constraints, and deletion checks benefit from typed foreign keys. Weighted-random delivery instead lazily materializes the durable row; Thompson Sampling retains explicit configuration because its assessment binding must exist before activation.
- Store posteriors only as reward history and recalculate: rejected because assignment and reporting must be bounded and independent of analytical stores.
- Synchronously update rewards during submission: rejected because scoring latency and failures must not block assessment completion.
- Migrate legacy page JSON and group revisions: rejected because immutable publications and existing attempts must continue to function without backfill or republication.

## 5. Interfaces

- `Oli.Experiments.create_experiment/1` and `update_experiment/2`: accept singular experiment fields for `alternatives_resource_id`, policy parameters, `conditions: [...]`, and Thompson-only `interventions: [...]`. Each condition carries its mapped `option_id`, weight, and position. No public decision-point list or identifier is accepted.
- New conditions in an atomic graph-create request use a non-persisted request-local `client_ref`; mappings in that payload refer to it until the context generates the stable condition code, inserts the condition, and replaces references with generated `condition_id` values. Persisted graph updates use `condition_id` directly. The reference is unique only within its request and is never stored or emitted as evidence.
- `Oli.Experiments.validate_for_activation/2`: returns `:ok` or structured errors keyed by experiment mapping, intervention, or assessment binding. Activation and mutation APIs require an authorized project `Scope`.
- `Oli.Experiments.assign_condition/1`: request adds `page_resource_id` and `content_element_id` for logical identity plus `page_revision_id` and `publication_id` as event-only snapshot context. The latter two values are validated from the delivery scope, forwarded to assignment/exposure evidence, and never participate in assignment lookup, uniqueness, or permanent assignment columns. The response retains condition and option identity plus assignment/evidence identifiers.
- `Oli.Experiments.assigned_condition/1`: same identity fields, read-only, and never samples or creates state.
- The existing progress/completion boundary consumes the same prepared persisted intervention decisions used by rendering. Its contract is the visible activity/resource set for that learner and attempt: displayed alternative descendants are included once, hidden sibling descendants are absent, and shared page content plus downstream assessments retain ordinary rules.
- `Oli.Experiments.record_assessment_reward/1`: accepts source resource-attempt ID and scope; binding, assignment, threshold, and score are resolved server-side rather than trusted from a client/job payload.
- `Oli.Experiments.policy_snapshot/2`: returns experiment condition rows with posterior alpha/beta/mean, successes, failures, assignments/share, update time, effective mode, thresholds/progress, affected conditions, and imbalance warning.
- `Oli.Resources.Alternatives.normalize_strategy/1`: public documented boundary returning `{:ok, :user_section_preference | :experiment_controlled}` or `{:error, :unsupported_strategy}`. New writes use `persisted_strategy/1` and emit only canonical strings.
- Shared LiveComponent for group management is extracted from the existing Experiments `Decision Points` editor and receives `strategy`, labels, project/author, and edit capabilities. Its current Experiments UX—including group cards, option-management interactions, reorder behavior, validation/error presentation, deletion safeguards, and accessible controls—is preserved as the common baseline. It contains no strategy selector and never edits placement content.
- Content placement JSON requires `type`, `id`, `alternatives_id`, and `children`; optional legacy `strategy` remains schema-compatible but is ignored.
- Exported Alternatives resources include canonical group strategy, stable options, and content. Ingest creates/normalizes groups before `Rewiring.rewire_alternatives_groups/2` rewrites every repeated placement reference.

## 6. Data Model & Storage

PostgreSQL changes:

- `experiment_definitions`: own `alternatives_resource_id` and policy-parameter columns directly. Metadata-only drafts may keep singular configuration nullable; activation requires it to be complete. Add the group foreign key with `on_delete: :nothing` and an indexed current-binding conflict path.
- `experiment_conditions`: retain `experiment_id` and own `option_id`, `weight`, and `position` directly. Uniqueness is `(experiment_id, condition_code)` and `(experiment_id, option_id)` for configured rows. New codes are generated from the initial label with `Oli.Utils.Slug.slugify/1` under the experiment row lock.
- `experiment_interventions`: require `experiment_id`. Uniqueness is `(experiment_id, page_resource_id, content_element_id)` with an indexed `(page_resource_id, content_element_id)` delivery path. Placement ordering remains derived from course/page structure.
- `experiment_assessment_bindings`: `intervention_id`, `assessment_page_resource_id`, `threshold` as decimal/numeric, timestamps. Unique `intervention_id` and unique assessment page within a current experiment are reinforced in activation under an experiment lock because lifecycle-sensitive reuse cannot be expressed by a simple partial foreign-table index.
- `experiment_assignments`: require `experiment_id` and `intervention_id`; sticky uniqueness is `(experiment_id, intervention_id, enrollment_id)`. Retain section/user and compact policy evidence; no `decision_point_id` is stored.
- Accepted reward storage: add `assessment_binding_id`, `intervention_id`, and source `resource_attempt_id`; enforce one accepted claim per binding/enrollment and one claim per binding/source attempt. Keep disposition metadata compact and immutable.
- `experiment_policy_states`: uniqueness is `(experiment_id, algorithm)` and the row stores per-condition posterior alpha/beta and accepted counts in bounded JSON. No `decision_point_id` is stored.
- `experiment_decision_points` and `experiment_decision_point_conditions` are removed by the direct schema replacement. Explicit rollback restores their schema shape but does not reconstruct discarded QA experiment rows.
- All new foreign keys use `on_delete: :nothing`; domain APIs reconcile draft dependencies explicitly. No active-history cascade is introduced.

Content storage:

- Alternatives Group revision content: `%{"strategy" => "experiment_controlled" | "user_section_preference", "options" => [...]}`. Legacy `upgrade_decision_point` is never rewritten in historical revisions.
- Placement content: `%{"type" => "alternatives", "id" => stable_element_id, "alternatives_id" => resource_id, "children" => [...]}`. Optional legacy strategy is ignored.

Analytics storage:

- Add intervention ID/key, assessment binding ID, assessment page resource ID, resource attempt ID, disposition, threshold, normalized score, publication ID, page revision ID, and before/after policy context to the existing xAPI attribution evidence. Project the typed identity, disposition, score, and revision fields into ClickHouse, but retain before/after policy context only in xAPI JSON until a concrete OLAP query requirement is established. Assignment creation evidence records the initial delivered snapshot, and exposure evidence records the snapshot for each rendered revisit without changing the sticky assignment.
- Preserve event-only publication and page-revision context in the existing compact runtime event/outbox state only as needed for reliable retry, then rely on xAPI/ClickHouse as the durable detailed evidence store; do not promote these values to permanent assignment columns.
- ClickHouse migration and rollback preserve existing rows and make new fields nullable/defaulted for old evidence.

## 7. Consistency & Transactions

- Draft create/update/activate runs under an experiment row lock. Activation also locks referenced group resources in sorted ID order, preventing simultaneous current bindings and deadlock-prone lock inversion.
- Assignment uses a transaction with a consistent policy-state read. Thompson Sampling draws from that single state value. Insert uniqueness is the concurrency arbiter; losing transactions reload the winner. Policy assignment counts update only for the inserted assignment.
- Reward acceptance uses one transaction and locks the policy-state row before inserting the claim and updating posterior state. The unique claim plus row lock prevents duplicate increments and lost updates.
- Evidence emission occurs only after commit. Retry uses persisted accepted reward/assignment data and cannot mutate policy again.
- Attempt eligibility is deterministic: query attempts in canonical persisted order and stop at the earliest eligible attempt; pending state is a deliberate blocker.
- Authoring deletion checks the experiment group reference, condition mappings, interventions, and assessment bindings. Draft callers receive dependency details; non-draft callers receive immutable-state errors.

## 8. Caching Strategy

- Do not cache assignments, policy state, reward eligibility, or details-page snapshots; correctness depends on the latest committed PostgreSQL state.
- Reuse publication-pinned revision loading already used by `DeliveryResolver`.
- The section relevance check may use existing section experiment tracking if transactionally maintained. If an in-memory cache is later introduced, it may cache only negative/positive relevance with explicit invalidation on activation, participation, lifecycle, and publication changes; it is not required for this work.

## 9. Performance & Scalability Posture

- Negative delivery path: one indexed `exists` query by section, active state, and relevant publication/project; no assignment, binding, policy, reward, or analytics queries.
- Positive path: batch-load relevant group revisions, bulk-materialize missing weighted-random intervention identities, resolve configured Thompson Sampling bindings, and batch-load existing assignments. Avoid per-element N+1 queries.
- Assignment cost is proportional to the number of experiment conditions, never reward history or total experiment history.
- Reward lookup is indexed by assessment page, section/enrollment, and ordered resource attempt identity. Posterior update touches one claim row and one policy-state row.
- Reporting groups assignment counts in SQL and reads one policy row per experiment. It does not calculate next-assignment probabilities.
- Emit duration telemetry for relevance, binding resolution, sampling/insert, reward queue delay, reward transaction, and snapshot load. No new numeric latency SLO is asserted because `harness.yml` defaults performance requirements to exclude, but regressions must be visible in AppSignal.

## 10. Failure Modes & Resilience

- Missing/inactive/incompatible binding: render first local alternative and emit bounded fallback reason; do not create state.
- Unknown group strategy: fail safely to deterministic first-alternative rendering in delivery, reject authoring/activation, and emit a migration anomaly.
- Mapping mismatch or changed option identity: reject draft save/activation; active structures are immutable.
- Assignment race: unique conflict reloads the persisted winner and emits `concurrency_resolved`.
- Policy sampling failure/corrupt state: do not guess a condition; deterministic fallback is rendered and an exception/error signal is emitted for repair.
- Missing assignment at reward time: record a skip; never infer or retroactively assign.
- Pending earlier attempt: skip/defer with a retryable bounded reason; later attempts cannot leapfrog it.
- Duplicate/replayed reward: return existing disposition and emit duplicate telemetry without posterior mutation.
- Oban or evidence sink failure: retry independently; submitted assessment and committed PostgreSQL state remain valid.
- Deleted/moved content: supported draft operations must reconcile dependencies; active references cannot be silently cascaded or retargeted.
- Stale details page: explicit refresh reloads the committed PostgreSQL snapshot and shows its update timestamp.

## 11. Observability

- Extend `Oli.Experiments.Telemetry` and delivery telemetry with events for section relevance, binding resolved/missing/conflict, assignment created/reused/concurrency-resolved/fallback, sampling mode, reward accepted/duplicate/skipped/failed, posterior updated, evidence dispatch, and migration anomaly.
- Measurements include counts and durations/queue latency. Metadata may include experiment, intervention, condition, algorithm, assessment binding, publication, result, and bounded reason. New telemetry does not carry decision-point identity.
- Do not include response content, raw activity state, free-form page content, scores beyond the normalized evidence field where required, email, name, or unnecessary user ID.
- AppSignal dashboards/alerts should cover fallback/error rate, reward queue-to-update latency, duplicate/skip reasons, posterior update failures, assignment imbalance warnings, and migration anomalies.
- Logs are structured and bounded. Tests that intentionally trigger them use `capture_log` or `@tag capture_log: true`.

## 12. Security & Privacy

- Every authoring API validates author/project access through `Scope`; group, page, assessment, publication, and section references must belong to the same compatible project lineage.
- Delivery derives enrollment, user, section, publication, score, assignment, and binding from trusted server relationships; client-provided identifiers cannot select another learner's assignment or reward.
- Lifecycle and dependency rules are enforced in the domain context and database, not only LiveView controls.
- Foreign keys and non-cascading deletion protect experiment history. Binding exclusivity is checked under locks to avoid authorization-valid races.
- Telemetry/evidence minimizes learner identity and excludes raw responses. Existing analytics retention and GDPR controls apply.
- Preview modes have no assignment/reward/evidence capabilities and use server-provided mode, not a client flag, as the authority.

## 13. Testing Strategy

- AC-034 is verified by authoring, schema, and delivery tests that reject nested Alternatives while permitting placements at any depth in ordinary content and failing legacy invalid nesting closed.
- AC-035 is verified by PostgreSQL and ClickHouse migration tests that remove all physical decision-point storage, assert the final singular constraints and indexes, and restore the prior schema shape on rollback without requiring QA experiment-row preservation.
- Context/schema ExUnit tests cover FR-001 through FR-004, FR-017 through FR-020, lifecycle locks, authorization, project compatibility, bijective mappings, current-binding exclusivity, sequential reuse, and explicit deletion reconciliation.
- Policy/runtime ExUnit tests cover FR-007 through FR-010 and FR-027: independent intervention assignments, sticky revisits, deterministic random seams, one-snapshot Thompson draws, weighted random without rewards, races, negative relevance query budgets, and batched positive paths.
- Reward/Oban tests cover FR-011 through FR-016: threshold edges, normalized page score use, attempt ordering/pending blockers, missing assignments, concurrency, replay, transaction rollback, post-commit enqueue, and delayed influence.
- Rendering/progress/completion tests cover FR-005, FR-006, FR-019, FR-021, and FR-022 with differing local content, reorder/move/copy/duplicate/reinsert identity behavior, inert accessible previews, fallback, and hidden activity exclusion. Tests must create multiple interventions whose alternatives contain different numbers of required activities, assign learners to different combinations, and prove for each learner that: only displayed descendants enter the progress/completion numerator and denominator; every hidden sibling is excluded; completing all displayed requirements yields exactly 100%; incomplete displayed requirements yield the expected percentage; revisits preserve the denominator through sticky assignments; and shared content plus the bound assessment follows ordinary completion behavior without duplication.
- Add a workflow-level `Oli.Scenarios` assertion for two learners assigned to different alternatives across repeated interventions, verifying that both independently reach 100% after completing only their respective visible activities and the shared assessment. If scenario directives cannot inspect learner-visible completion inputs and final percentage, extend the scenario infrastructure before authoring this case.
- LiveView/component tests cover FR-028, FR-029, and FR-032: both routes render the shared Experiments-derived group editor with consistent polished interactions; each surface retains its own labels, strategy filter, creation behavior, and permissions; neither exposes a selector or inline content editing; and experiment configuration covers the singular group/policy scope, validation, read-only lifecycle, posterior labels/counts/modes/warnings, refresh, and draft/weighted-random omission.
- JSON Schema fixture tests cover FR-030 for new no-strategy placements, legacy matching/conflicting/unknown strategy strings, required valid `alternatives_id`, and the parent elements-schema reference.
- Export/ingest round-trip tests cover FR-031 and FR-033 for both strategies, repeated placements, local content, rewritten IDs, missing/conflicting legacy element strategy, legacy group defaults, alias canonicalization, and immutable historical publications.
- Telemetry/xAPI/ClickHouse tests cover FR-023 and FR-024, bounded dimensions, evidence completeness, privacy exclusions, and no analytical reads in runtime paths.
- Migration tests cover FR-025 and FR-026 with explicit PostgreSQL and ClickHouse forward/rollback schema verification, constraints/indexes, dependency-safe ordering, and existing Alternatives content compatibility. They do not assert preservation of pre-release experiment rows.
- Add an `Oli.Scenarios` workflow for authoring two placements, publishing, section participation, different sticky assignments, scored-page finalization, and posterior reuse across a later intervention. Extend the scenario DSL only if existing directives cannot express experiment configuration/assertions.
- Required gates: targeted ExUnit/LiveView/scenario tests, schema validation tests, migration up/down verification, `mix format`, `mix compile`, and applicable `.review/elixir.md`, `.review/ui.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md` review lenses.

## 14. Backwards Compatibility

- No page content, revision, publication, assignment, reward, or analytics backfill is required by the feature rollout.
- Read boundaries normalize group `upgrade_decision_point` and `experiment_controlled` identically. New group/revision/export/ingest writes use only `experiment_controlled`.
- Existing content element strategy is ignored regardless of missing, matching, conflicting, or unknown value; new placements omit it. The schema remains permissive for the legacy property.
- Legacy imported groups without strategy default to `user_section_preference`. Legacy imported `upgrade_decision_point` groups are persisted canonically.
- Historical and deployed revisions remain untouched. Editing a legacy group preserves its `upgrade_decision_point` strategy; only newly created A/B Test Alternatives Groups use `experiment_controlled`.
- Pre-release QA experiment definitions, assignments, rewards, policy state, and experiment analytics may be deleted or recreated during the schema replacement. There is no transformation, backfill, or preservation contract for those rows.
- The completed schema enforces the singular model directly; it does not retain nullable legacy experiment columns, dual-write fields, or a long-lived multi-point request adapter.
- Experiments created after the singular schema is installed retain the normal lifecycle and immutable-history guarantees.

## 15. Risks & Mitigations

- Schema replacement could leave stale constraints or incomplete rollback behavior: verify the exact PostgreSQL and ClickHouse schema, indexes, foreign keys, and constraints after forward and rollback migrations. Do not add row-mapping logic for disposable QA experiments.
- JSON policy state permits malformed data: centralize encode/decode validation, lock on update, fail closed, and test corrupt-state behavior.
- Same-page element copy behavior may retain IDs: audit those entry points and add identity contract tests before binding activation is enabled. Do not regenerate the complete content tree during page duplication.
- Page-level assessment rewards touch broader attempt lifecycle code: enqueue only after commit and keep eligibility/scoring resolution in a narrow experiment adapter.
- Multiple placements can create N+1 delivery work: batch binding and assignment reads for a page and enforce query-count tests.
- Extracting the Experiments editor could accidentally broaden edits or regress its polished UX: treat the current Experiments `Decision Points` editor as the behavioral and visual baseline, extract before adapting, parameterize only strategy/labels/capabilities, and retain domain authorization, deletion safeguards, accessible reorder behavior, and immutable option identity checks on both surfaces.
- Posterior metrics can be mistaken for allocation: label `Estimated success probability`, separate observed share, show evidence counts, and never expose next-assignment probability.
- Pooled observations are correlated or semantically inconsistent: retain intervention/assessment evidence, expose thresholds, document the non-contextual assumption, and require separate experiments for unrelated treatments.
- Analytics dispatch can lag PostgreSQL: report operational truth from PostgreSQL and monitor evidence queue latency rather than blocking runtime.

## 16. Open Questions & Follow-ups

- Confirm the canonical resource-attempt ordering and finalized lifecycle predicate during slice design; this is an implementation fact, not a product decision.
- Confirm whether the existing ClickHouse attribution map can carry all new fields without physical columns; prefer additive typed columns only where query/reporting requirements justify them.
- Decide during implementation planning whether condition normalization and new binding tables should ship in one migration or dependency-ordered migrations. The required outcome and rollback behavior are fixed; batching is operational.
- No feature-level Figma is expected. Use the approved repo-local UI brief, established Torus authoring patterns, Tailwind light/dark semantics, and LiveView/LiveComponents by default; run the application and refine usability, accessibility, responsiveness, and visual consistency during implementation.

## 17. References

- `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/prd.md`
- `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/requirements.yml`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/TESTING.md`
- `docs/OPERATIONS.md`
- `docs/DESIGN.md`
- `docs/design-docs/attempt-handling.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/schemas/`

## Decision Log

### 2026-08-13 - Replace rather than backfill QA experiment storage

- Change: Simplified the singular persistence design to direct PostgreSQL and ClickHouse schema replacement without experiment-row transformation, preservation, dual reads, or dual writes.
- Reason: The feature has no production experiment data; it remains deployed only in QA.
- Evidence: Explicit rollout-scope clarification for the implementation handoff.
- Impact: Migration verification covers schema directionality and final constraints, while existing Alternatives content compatibility remains unchanged.
- `lib/oli/delivery/experiments/page_decisions.ex`
- `lib/oli/delivery/experiments/reward_handoff.ex`
- `lib/oli/delivery/experiments/reward_handoff_worker.ex`
- `lib/oli/resources/alternatives.ex`
- `lib/oli/resources/alternatives/decision_point_strategy.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `lib/oli_web/live/workspaces/course_author/experiment_details_live.ex`
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `lib/oli/interop/export.ex`
- `lib/oli/interop/ingest/processor/alternatives.ex`
- `priv/schemas/v0-1-0/content-alternatives.schema.json`

## Decision Log

### 2026-08-13 - Collapse the decision-point hierarchy

- Change: Moved the Alternatives Group binding, condition mapping, policy parameters, and policy state scope to the experiment and made interventions direct experiment children.
- Reason: Research shows multiple exposure points are useful only when they share experiment treatment; Torus interventions already represent those locations, while current decision points create independent sub-experiments.
- Evidence: `design/single_decision_point_analysis.md` and current schema/query waypointing.
- Impact: The implementation requires a reversible schema collapse, singular authoring/runtime interfaces, removal of decision-point evidence dimensions, and separate experiments for independent optimizations.

### 2026-08-11 - Retain readable condition codes

- Change: Keep condition codes as immutable experiment-scoped policy/API/evidence keys, generated from labels with deterministic collision suffixes under the experiment lock.
- Reason: Removing the existing code contract would materially broaden the feature, while readable codes remain valuable operationally.
- Evidence: Current policy state, delivery decisions, rewards, xAPI, and ClickHouse attribution already carry `condition_code`.
- Impact: PostgreSQL enforces `(experiment_id, condition_code)` uniqueness, codes do not change with labels, and migration preserves existing codes without implicit merging.

### 2026-08-13 - Lazily materialize weighted-random interventions

- Change: Delivery derives weighted-random interventions from valid group placements and conflict-safely persists missing identities on first encounter; Thompson Sampling interventions remain explicit configuration.
- Reason: Only adaptive interventions need advance assessment bindings. Requiring the same authoring workflow for weighted random creates unnecessary synchronization state.
- Evidence: `Oli.Experiments.assign_page_conditions/1`, activation validation, experiment-details authoring behavior, and focused tests.
- Impact: The intervention table remains the durable assignment/evidence identity, but weighted-random authoring and activation no longer depend on preconfigured rows.

### 2026-08-13 - Remove duplicated decision-point algorithm persistence

- Change: Removed the decision-point algorithm column and derive the policy from the owning experiment in authoring, activation, assignment, reward, and policy-state paths.
- Reason: Persisting the same immutable policy on both the experiment and every decision point creates an avoidable consistency invariant.
- Evidence: Generated reversible migration, singular experiment-owned schemas, `Oli.Experiments` queries and policy dispatch, plus focused configuration/runtime tests.
- Impact: Experiment definitions are the sole persisted policy source and policy state retains its algorithm identity.

### 2026-08-13 - Make assignment policy experiment-scoped

- Change: The experiment definition is authoritative for assignment algorithm across all interventions.
- Reason: Policy selection is an experiment-wide semantic choice; per-point selectors permitted incoherent mixed-policy experiments.
- Evidence: `Oli.Experiments` graph validation/insertion and experiment-details form parsing.
- Impact: Authoring exposes policy selection only during experiment creation; a follow-up removes redundant decision-point persistence.
