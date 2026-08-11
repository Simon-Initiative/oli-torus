# Intervention-Scoped Assignment and Assessment-Driven Thompson Sampling - Functional Design Document

## 1. Executive Summary

Extend the existing `Oli.Experiments` subsystem rather than introducing a second experiment runtime. The design separates four identities that the current implementation conflates: experiment-owned conditions, decision-point policy state, placed intervention instances, and scored-page assessment bindings. A learner assignment becomes sticky on `(section enrollment, decision point, intervention)` while all accepted rewards for interventions governed by one decision point update that decision point's shared PostgreSQL posterior.

Authoring continues to store reusable Alternatives Groups as versioned resources and placement-local content in page revisions. Group strategy is the sole selection authority. New experiment-controlled groups use `experiment_controlled`; `upgrade_decision_point` is normalized only at read and ingest boundaries. Delivery performs one bounded active-experiment relevance check before resolving bindings, creates assignments transactionally, renders the persisted alternative, and emits detailed evidence asynchronously. Finalized scored-page attempts enqueue an Oban handoff that claims one reward and updates one policy snapshot atomically.

This design requires additive PostgreSQL tables for decision-point mappings, interventions, and assessment bindings; targeted changes to existing condition, assignment, reward, and policy-state storage; an ordinary ClickHouse migration for evidence fields; no content backfill; and no forced republication.

## 2. Requirements & Assumptions

- Functional requirements:
  - Experiment structure and binding: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-017, FR-018, FR-019, FR-020.
  - Assignment and policies: FR-007, FR-008, FR-009, FR-010, FR-021, FR-022, FR-027.
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
  - A condition has one stable identity within an experiment and represents a comparable treatment at every decision point where mapped.
  - The stable intervention key is the page resource ID plus the page element's stable `id`; revision and publication IDs are evidence only.
  - Whole-page moves preserve the page resource ID. Page duplication and element recreation generate new IDs through existing editing behavior.
  - Existing finalized scored-page attempt ordering and normalized overall page scores are authoritative; experiment code does not recompute scoring.
  - Existing Thompson Sampling guardrail semantics remain valid after moving their state to decision-point scope.
  - No feature flag is added, consistent with the PRD and `harness.yml` default. Rollout is controlled by valid draft activation and normal deployment.
  - Jira is the issue system of record, but this design performs no Jira writes.

## 3. Repository Context Summary

- What we know:
  - `Oli.Experiments` already owns experiment lifecycle, assignment, policy state, reward persistence, validation, telemetry, and public authoring/runtime APIs.
  - Existing schemas under `lib/oli/experiments/schemas/` model definitions, decision points, decision-point-owned conditions, enrollment-level assignments, and JSON policy state.
  - `Oli.Resources.Alternatives` resolves strategy from the loaded Alternatives Group, while `DecisionPointStrategy` prepares delivery decisions and evidence.
  - `Oli.Delivery.Experiments.PageDecisions` discovers placement group references from attempt-pinned page content and loads group revisions through `DeliveryResolver`.
  - `RewardHandoffWorker` already provides asynchronous post-commit processing, but `RewardHandoff` currently derives full-credit rewards from activity attempts rather than finalized scored-page attempts.
  - `ExperimentsLive`, `ExperimentDetailsLive`, and `AlternativesLive` own the current authoring UI. Group management logic is duplicated and currently writes `upgrade_decision_point` on the Experiments page.
  - `Oli.Interop.Export` and `Oli.Interop.Ingest.Processor` already serialize Alternatives resources and rewire page references.
  - `priv/schemas/v0-1-0/content-alternatives.schema.json` currently requires element-level `strategy` and does not require `alternatives_id`, contrary to the target contract.
  - Published revisions and learner attempts pin delivered content, so intervention lookup must use page resource identity while recording the actual revision/publication as evidence.
- Unknowns to confirm:
  - None block architecture. During detailed design, confirm the exact scored-page final lifecycle states and the canonical persisted attempt ordering column before writing the reward eligibility query.
  - Confirm whether existing copy/duplicate editor functions already regenerate every nested alternatives element ID; otherwise that behavior must be made explicit at those editing boundaries.
  - Confirm the current ClickHouse raw-event schema version at implementation time before naming the additive migration columns.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.Experiments` remains the public domain boundary and is split internally into focused services as implementation proceeds:

- `Configuration` validates draft definitions, experiment-owned conditions, decision points, bijective mappings, interventions, bindings, lifecycle restrictions, and deletion dependencies.
- `Strategy` normalizes group strategy: `experiment_controlled` and `upgrade_decision_point` both become internal `:experiment_controlled`; unsupported values fail closed.
- `Assignments` resolves the active experiment and intervention, reads one policy snapshot, samples through the existing policy modules, and inserts or returns the unique persisted assignment.
- `Rewards` resolves finalized assessment attempts, claims accepted rewards, updates posterior state, and writes compact evidence in one transaction.
- `Reporting` returns a bounded policy snapshot DTO for the details LiveView, including posterior, counts, allocation, guardrail mode, warning state, and update time.

Web and delivery modules remain adapters:

- `ExperimentsLive` composes experiment listing/configuration with a shared group-management component configured for `:experiment_controlled`. The shared component is extracted from the current Experiments `Decision Points` Alternatives Groups editor, whose more polished presentation and interaction model is the UX baseline.
- `AlternativesLive` adopts that Experiments-derived component configured for `:user_section_preference`, replacing its less-polished group editor while retaining its route, Learner Choice filtering, labels, and permissions.
- `PageDecisions` performs the relevance gate, derives `(page_resource_id, element_id)` from attempt content, and calls the assignment API only for experiment-controlled groups.
- `RewardHandoffWorker` receives finalized resource-attempt IDs after the scoring transaction commits and delegates to `Rewards`.
- xAPI/ClickHouse adapters emit evidence after the PostgreSQL transaction; retryable evidence delivery does not change accepted reward state.

### 4.2 State & Data Flow

Authoring flow:

1. The management surface creates a group with an implicit immutable canonical strategy and stable option IDs.
2. Page insertion stores `{type, id, alternatives_id, children}` with placement-local child content and no strategy.
3. A draft experiment creates stable experiment conditions, one or more decision points, and a bijective condition-to-option mapping for each point.
4. Placed instances are registered as interventions using page resource ID and element ID. Thompson Sampling requires one distinct scored-page binding and threshold for each intervention.
5. Activation locks the experiment definition and validates project compatibility, current-binding exclusivity, mapping completeness, all referenced working revisions, intervention existence, distinct assessments, and participating sections in one transaction.

Delivery assignment flow:

1. `PageDecisions` checks whether the section has a relevant active experiment using one indexed `exists` query. A negative result bypasses all experiment tables.
2. Group revisions are resolved from the attempt's publication-pinned content. Strategy normalization determines whether experiment behavior applies.
3. For each placed experiment-controlled element, lookup uses project/section scope, group resource ID, page resource ID, and element ID. Missing or inapplicable bindings select the first local alternative without state or evidence.
4. Revisit lookup returns the assignment by the full uniqueness key. A first encounter reads one committed decision-point policy-state snapshot, samples through `WeightedRandom` or `ThompsonSampling`, and inserts the assignment with delivery evidence.
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
2. For non-draft Thompson Sampling experiments, `Reporting.policy_snapshot/2` reads decision points, mappings, conditions, policy state, and grouped assignment counts in bounded queries.
3. The DTO calculates posterior mean from persisted alpha/beta, accepted successes/failures, observed assignment count/share, and effective guardrail mode. It never samples, scans reward history, or queries analytics stores.
4. Completed/archived data is unchanged, so the last committed snapshot is the frozen report.

### 4.3 Lifecycle & Ownership

- Alternatives Group resource: owns immutable strategy and stable option identity/label contract. New successor revisions may change labels only where allowed; strategy and option IDs cannot be changed through supported APIs.
- Page revision: owns placement element ID and local content. Publication/attempt pinning owns the delivered snapshot.
- Experiment: owns stable condition identities and lifecycle.
- Decision point: owns group binding, algorithm configuration, condition mapping, aggregate policy state, and its interventions.
- Intervention: owns logical placement identity `(page_resource_id, content_element_id)` under one decision point.
- Assessment binding: owns scored-page resource ID and inclusive threshold for one Thompson intervention.
- Assignment: owns the sticky selection for one enrollment and intervention and supplies the stable visibility decision used by rendering and learner-specific progress/completion denominator construction. Publication and page-revision snapshots are not assignment state; they are captured on assignment/exposure evidence events.
- Accepted reward: owns the immutable binding/source-attempt claim and disposition. Policy state owns reduced sufficient statistics.
- Completed/archived experiment rows are append-only/read-only through supported APIs. Sequential group reuse creates new decision-point, mapping, intervention, assignment, reward, and policy rows.

### 4.4 Alternatives Considered

- Keep conditions duplicated per decision point: rejected because FR-001 requires stable experiment-scoped identities and duplication permits drift. A mapping table is the simplest explicit shared contract.
- Encode intervention identity in `assignment_key` only: rejected because database constraints, joins, evidence, and deletion checks require typed foreign keys and indexed columns.
- Derive interventions at delivery from group occurrences without persisted binding rows: rejected because assessment bindings, lifecycle immutability, referential checks, and copy semantics require durable identity.
- Store posteriors only as reward history and recalculate: rejected because assignment and reporting must be bounded and independent of analytical stores.
- Synchronously update rewards during submission: rejected because scoring latency and failures must not block assessment completion.
- Migrate legacy page JSON and group revisions: rejected because immutable publications and existing attempts must continue to function without backfill or republication.

## 5. Interfaces

- `Oli.Experiments.create_experiment/1` and `update_experiment/2`: accept `conditions: [...]` plus `decision_points: [%{alternatives_resource_id, algorithm_config, mappings, interventions}]`; the singular legacy request shape may be accepted temporarily only as an internal compatibility adapter.
- `Oli.Experiments.validate_for_activation/2`: returns `:ok` or structured errors keyed by decision point, mapping, intervention, or assessment binding. Activation and mutation APIs require an authorized project `Scope`.
- `Oli.Experiments.assign_condition/1`: request adds `page_resource_id` and `content_element_id` for logical identity plus `page_revision_id` and `publication_id` as event-only snapshot context. The latter two values are validated from the delivery scope, forwarded to assignment/exposure evidence, and never participate in assignment lookup, uniqueness, or permanent assignment columns. The response retains condition and option identity plus assignment/evidence identifiers.
- `Oli.Experiments.assigned_condition/1`: same identity fields, read-only, and never samples or creates state.
- The existing progress/completion boundary consumes the same prepared persisted intervention decisions used by rendering. Its contract is the visible activity/resource set for that learner and attempt: displayed alternative descendants are included once, hidden sibling descendants are absent, and shared page content plus downstream assessments retain ordinary rules.
- `Oli.Experiments.record_assessment_reward/1`: accepts source resource-attempt ID and scope; binding, assignment, threshold, and score are resolved server-side rather than trusted from a client/job payload.
- `Oli.Experiments.policy_snapshot/2`: returns decision-point condition rows with posterior alpha/beta/mean, successes, failures, assignments/share, update time, effective mode, thresholds/progress, affected conditions, and imbalance warning.
- `Oli.Resources.Alternatives.normalize_strategy/1`: public documented boundary returning `{:ok, :user_section_preference | :experiment_controlled}` or `{:error, :unsupported_strategy}`. New writes use `persisted_strategy/1` and emit only canonical strings.
- Shared LiveComponent for group management is extracted from the existing Experiments `Decision Points` editor and receives `strategy`, labels, project/author, and edit capabilities. Its current Experiments UX—including group cards, option-management interactions, reorder behavior, validation/error presentation, deletion safeguards, and accessible controls—is preserved as the common baseline. It contains no strategy selector and never edits placement content.
- Content placement JSON requires `type`, `id`, `alternatives_id`, and `children`; optional legacy `strategy` remains schema-compatible but is ignored.
- Exported Alternatives resources include canonical group strategy, stable options, and content. Ingest creates/normalizes groups before `Rewiring.rewire_alternatives_groups/2` rewrites every repeated placement reference.

## 6. Data Model & Storage

PostgreSQL changes:

- `experiment_conditions`: make conditions experiment-owned. Enforce unique `(experiment_id, condition_code)`; remove decision-point ownership after copying existing rows into stable experiment condition identities. Preserve existing IDs where a condition is already unique; where old decision points duplicate a code, migration creates/reuses one canonical condition and rewires dependent rows without changing historical meaning.
- `experiment_decision_point_conditions`: `decision_point_id`, `condition_id`, `option_id`, `weight`, `position`, timestamps. Unique on `(decision_point_id, condition_id)` and `(decision_point_id, option_id)` provides the bijection; foreign keys use `on_delete: :nothing`.
- `experiment_interventions`: `decision_point_id`, `page_resource_id`, `content_element_id`, timestamps. Unique `(decision_point_id, page_resource_id, content_element_id)`; indexed `(page_resource_id, content_element_id)` for delivery and dependency checks. Intervention identity and persistence do not encode placement order: configuration displays derive ordering from the current course hierarchy and page content tree, with stable IDs used only as tie-breakers.
- `experiment_assessment_bindings`: `intervention_id`, `assessment_page_resource_id`, `threshold` as decimal/numeric, timestamps. Unique `intervention_id` and unique assessment page within a current experiment are reinforced in activation under an experiment lock because lifecycle-sensitive reuse cannot be expressed by a simple partial foreign-table index.
- `experiment_assignments`: add non-null `intervention_id` for new rows. Replace sticky uniqueness with `(experiment_id, decision_point_id, intervention_id, enrollment_id)`. Retain section/user and compact policy evidence. Do not add `publication_id` or `page_revision_id`: assignments remain sticky across publications and revisions, while delivered snapshot context belongs to xAPI/ClickHouse assignment and exposure evidence. Existing rows remain readable and are treated as legacy decision-point assignments; no conversion job is required, and new runtime paths write intervention-scoped rows only.
- Accepted reward storage: add `assessment_binding_id`, `intervention_id`, and source `resource_attempt_id`; enforce one accepted claim per binding/enrollment and one claim per binding/source attempt. Keep disposition metadata compact and immutable.
- `experiment_policy_states`: continue one row per decision point/algorithm. Store per-condition posterior alpha/beta and accepted counts in the existing bounded JSON state, with aggregate columns retained for efficient summaries. Updates lock this row.
- Decision points gain per-point policy configuration if algorithm/guardrails currently reside only on the experiment. The experiment algorithm may remain as a compatibility/default field, but new multi-point writes resolve configuration from the decision point.
- All new foreign keys use `on_delete: :nothing`; domain APIs reconcile draft dependencies explicitly. No active-history cascade is introduced.

Content storage:

- Alternatives Group revision content: `%{"strategy" => "experiment_controlled" | "user_section_preference", "options" => [...]}`. Legacy `upgrade_decision_point` is never rewritten in historical revisions.
- Placement content: `%{"type" => "alternatives", "id" => stable_element_id, "alternatives_id" => resource_id, "children" => [...]}`. Optional legacy strategy is ignored.

Analytics storage:

- Add intervention ID/key, assessment binding ID, assessment page resource ID, resource attempt ID, disposition, threshold, normalized score, publication ID, page revision ID, and before/after policy context to the existing experiment attribution/raw-event path. Assignment creation evidence records the initial delivered snapshot, and exposure evidence records the snapshot for each rendered revisit without changing the sticky assignment.
- Preserve event-only publication and page-revision context in the existing compact runtime event/outbox state only as needed for reliable retry, then rely on xAPI/ClickHouse as the durable detailed evidence store; do not promote these values to permanent assignment columns.
- ClickHouse migration and rollback preserve existing rows and make new fields nullable/defaulted for old evidence.

## 7. Consistency & Transactions

- Draft create/update/activate runs under an experiment row lock. Activation also locks referenced group resources in sorted ID order, preventing simultaneous current bindings and deadlock-prone lock inversion.
- Assignment uses a transaction with a consistent policy-state read. Thompson Sampling draws from that single state value. Insert uniqueness is the concurrency arbiter; losing transactions reload the winner. Policy assignment counts update only for the inserted assignment.
- Reward acceptance uses one transaction and locks the policy-state row before inserting the claim and updating posterior state. The unique claim plus row lock prevents duplicate increments and lost updates.
- Evidence emission occurs only after commit. Retry uses persisted accepted reward/assignment data and cannot mutate policy again.
- Attempt eligibility is deterministic: query attempts in canonical persisted order and stop at the earliest eligible attempt; pending state is a deliberate blocker.
- Authoring deletion checks group references, decision-point mappings, interventions, and assessment bindings. Draft callers receive dependency details; non-draft callers receive immutable-state errors.

## 8. Caching Strategy

- Do not cache assignments, policy state, reward eligibility, or details-page snapshots; correctness depends on the latest committed PostgreSQL state.
- Reuse publication-pinned revision loading already used by `DeliveryResolver`.
- The section relevance check may use existing section experiment tracking if transactionally maintained. If an in-memory cache is later introduced, it may cache only negative/positive relevance with explicit invalidation on activation, participation, lifecycle, and publication changes; it is not required for this work.

## 9. Performance & Scalability Posture

- Negative delivery path: one indexed `exists` query by section, active state, and relevant publication/project; no assignment, binding, policy, reward, or analytics queries.
- Positive path: batch-load relevant group revisions and intervention bindings for all placement IDs on the page; batch-load existing assignments; create only missing assignments. Avoid per-element N+1 queries.
- Assignment cost is proportional to the number of conditions for one decision point, never reward history or total experiment history.
- Reward lookup is indexed by assessment page, section/enrollment, and ordered resource attempt identity. Posterior update touches one claim row and one policy-state row.
- Reporting groups assignment counts in SQL and reads one policy row per decision point. It does not calculate next-assignment probabilities.
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
- Measurements include counts and durations/queue latency. Metadata may include experiment, decision point, intervention, condition, algorithm, assessment binding, publication, result, and bounded reason.
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

- Context/schema ExUnit tests cover FR-001 through FR-004, FR-017 through FR-020, lifecycle locks, authorization, project compatibility, bijective mappings, current-binding exclusivity, sequential reuse, and explicit deletion reconciliation.
- Policy/runtime ExUnit tests cover FR-007 through FR-010 and FR-027: independent intervention assignments, sticky revisits, deterministic random seams, one-snapshot Thompson draws, weighted random without rewards, races, negative relevance query budgets, and batched positive paths.
- Reward/Oban tests cover FR-011 through FR-016: threshold edges, normalized page score use, attempt ordering/pending blockers, missing assignments, concurrency, replay, transaction rollback, post-commit enqueue, and delayed influence.
- Rendering/progress/completion tests cover FR-005, FR-006, FR-019, FR-021, and FR-022 with differing local content, reorder/move/copy/duplicate/reinsert identity behavior, inert accessible previews, fallback, and hidden activity exclusion. Tests must create multiple interventions whose alternatives contain different numbers of required activities, assign learners to different combinations, and prove for each learner that: only displayed descendants enter the progress/completion numerator and denominator; every hidden sibling is excluded; completing all displayed requirements yields exactly 100%; incomplete displayed requirements yield the expected percentage; revisits preserve the denominator through sticky assignments; and shared content plus the bound assessment follows ordinary completion behavior without duplication.
- Add a workflow-level `Oli.Scenarios` assertion for two learners assigned to different alternatives across repeated interventions, verifying that both independently reach 100% after completing only their respective visible activities and the shared assessment. If scenario directives cannot inspect learner-visible completion inputs and final percentage, extend the scenario infrastructure before authoring this case.
- LiveView/component tests cover FR-028, FR-029, and FR-032: both routes render the shared Experiments-derived group editor with consistent polished interactions; each surface retains its own labels, strategy filter, creation behavior, and permissions; neither exposes a selector or inline content editing; and experiment configuration covers multiple decision points, validation, read-only lifecycle, posterior labels/counts/modes/warnings, refresh, and draft/weighted-random omission.
- JSON Schema fixture tests cover FR-030 for new no-strategy placements, legacy matching/conflicting/unknown strategy strings, required valid `alternatives_id`, and the parent elements-schema reference.
- Export/ingest round-trip tests cover FR-031 and FR-033 for both strategies, repeated placements, local content, rewritten IDs, missing/conflicting legacy element strategy, legacy group defaults, alias canonicalization, and immutable historical publications.
- Telemetry/xAPI/ClickHouse tests cover FR-023 and FR-024, bounded dimensions, evidence completeness, privacy exclusions, and no analytical reads in runtime paths.
- Migration tests cover FR-025 and FR-026 using representative existing experiment/content rows, explicit forward/rollback, constraints/indexes, legacy nullable compatibility, and dependency-safe rollback.
- Add an `Oli.Scenarios` workflow for authoring two placements, publishing, section participation, different sticky assignments, scored-page finalization, and posterior reuse across a later intervention. Extend the scenario DSL only if existing directives cannot express experiment configuration/assertions.
- Required gates: targeted ExUnit/LiveView/scenario tests, schema validation tests, migration up/down verification, `mix format`, `mix compile`, and applicable `.review/elixir.md`, `.review/ui.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md` review lenses.

## 14. Backwards Compatibility

- No page content, revision, publication, assignment, reward, or analytics backfill is required by the feature rollout.
- Read boundaries normalize group `upgrade_decision_point` and `experiment_controlled` identically. New group/revision/export/ingest writes use only `experiment_controlled`.
- Existing content element strategy is ignored regardless of missing, matching, conflicting, or unknown value; new placements omit it. The schema remains permissive for the legacy property.
- Legacy imported groups without strategy default to `user_section_preference`. Legacy imported `upgrade_decision_point` groups are persisted canonically.
- Historical and deployed revisions remain untouched. Editing a legacy group creates a normal successor revision with the canonical value.
- Existing experiment records remain readable. Compatibility adapters support the old single-decision-point request/report shape until callers move to lists; new configuration uses the normalized multi-point model.
- New columns needed only by new intervention assignments remain nullable for legacy rows, with constraints enforcing completeness for new writes through changesets and, where feasible, database checks.
- Completed/archived state is never recomputed; its final stored state and evidence remain frozen.

## 15. Risks & Mitigations

- Experiment-scoped condition migration could mis-map historical rows: use deterministic `(experiment_id, condition_code)` reconciliation, preserve option mappings in the new join table, validate counts before dropping old constraints, and test rollback with representative QA data.
- JSON policy state permits malformed data: centralize encode/decode validation, lock on update, fail closed, and test corrupt-state behavior.
- Element copy behavior may retain IDs: audit every copy/duplicate entry point and add identity contract tests before binding activation is enabled.
- Page-level assessment rewards touch broader attempt lifecycle code: enqueue only after commit and keep eligibility/scoring resolution in a narrow experiment adapter.
- Multiple placements can create N+1 delivery work: batch binding and assignment reads for a page and enforce query-count tests.
- Extracting the Experiments editor could accidentally broaden edits or regress its polished UX: treat the current Experiments `Decision Points` editor as the behavioral and visual baseline, extract before adapting, parameterize only strategy/labels/capabilities, and retain domain authorization, deletion safeguards, accessible reorder behavior, and immutable option identity checks on both surfaces.
- Posterior metrics can be mistaken for allocation: label `Estimated success probability`, separate observed share, show evidence counts, and never expose next-assignment probability.
- Pooled observations are correlated or semantically inconsistent: retain intervention/assessment evidence, expose thresholds, document the non-contextual assumption, and require separate decision points for unrelated treatments.
- Analytics dispatch can lag PostgreSQL: report operational truth from PostgreSQL and monitor evidence queue latency rather than blocking runtime.

## 16. Open Questions & Follow-ups

- Confirm the canonical resource-attempt ordering and finalized lifecycle predicate during slice design; this is an implementation fact, not a product decision.
- Confirm whether the existing ClickHouse attribution map can carry all new fields without physical columns; prefer additive typed columns only where query/reporting requirements justify them.
- Decide during implementation planning whether condition normalization and new binding tables should ship in one migration or dependency-ordered migrations. The required outcome and rollback behavior are fixed; batching is operational.
- Produce Figma/design guidance before implementing the expanded multi-decision-point and posterior UI if no approved design source is attached to the implementation ticket.

## 17. References

- `docs/exec-plans/current/epics/ab_testing/experiment_scoped_arms/prd.md`
- `docs/exec-plans/current/epics/ab_testing/experiment_scoped_arms/requirements.yml`
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
