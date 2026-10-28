# Learning Model: Proficiency Reads and Usage - Functional Design Document

## 1. Executive Summary

Introduce `Oli.Delivery.Proficiency` as the model-neutral read boundary and retain `Oli.Delivery.Metrics` as a compatibility facade. The facade receives a loaded `%Section{}` whenever possible, dispatches exclusively on `section.learning_model_version`, and delegates calculation to `Proficiency.Naive` or `Proficiency.LktAoa`. Providers return canonical estimates and aggregates; Metrics adapters translate those results into legacy strings, tuples, nested maps, and rows while callers migrate.

LKT-AOA direct-objective reads use the existing `learning_states` primary key and never inspect attempt history. Parent-objective results are read-time rollups over effective children. Page, container, and course results are read-time, unweighted averages over distinct Section-wide objective states. Their membership is derived entirely from `SectionResourceDepot`: objective records identify activities targeting the objective, and page records identify activities embedded in the Section-pinned page Revision.

The existing `:related_activities` post-processing action will populate both objective and page records in bulk and publish the updated records through `DepotCoordinator`. Instructor oracles will consume the same facade, expose actual numeric aggregates plus confidence/coverage, and increment their versions so old cache entries cannot satisfy the new contracts. Existing `:naive` Sections retain current outputs; incomplete LKT-AOA state or membership returns an explicit unavailable result and never falls back to naive calculations.

## 2. Requirements & Assumptions

- Functional requirements:
  - Section-owned dispatch and provider isolation satisfy FR-001 and AC-001, AC-002, AC-003.
  - Canonical estimate and aggregate contracts satisfy FR-002 and AC-004, AC-005, AC-006.
  - The naive provider preserves FR-003 and AC-007/AC-009 primitives in the provider phase; characterized legacy outputs remain unchanged until explicit facade-adapter and consumer closure for AC-008 in the consumer-migration phase.
  - LKT-AOA direct and parent reads satisfy FR-004 and AC-010, AC-011, AC-012.
  - Section-pinned projections, versioned JIT migration, and depot coherence satisfy FR-005 and AC-013, AC-014, AC-015, AC-016, AC-036.
  - SRD-only membership satisfies FR-006 and AC-017, AC-018, AC-019.
  - Learner scope aggregation satisfies FR-007 and AC-020, AC-021, AC-022.
  - Instructor aggregation satisfies FR-008 and AC-023, AC-024.
  - Consumer migration satisfies FR-009 and AC-025, AC-026, AC-027.
  - Dashboard numeric, confidence, and coverage contracts satisfy FR-010 and AC-028, AC-029.
  - Rollout, cache coherence, and telemetry satisfy FR-011 and AC-030, AC-031, AC-032.
  - Layered verification satisfies FR-012 and AC-033, AC-034, AC-035.
- Non-functional requirements:
  - Direct learner/objective reads are one set-based `learning_states` query for the requested identity sets.
  - Instructor reads do not execute once per learner, objective, page, or container.
  - Page/container/course membership performs no delivery-time database query after the depot is initialized.
  - Projection persistence and distributed depot publication cannot report success independently.
  - Telemetry uses bounded cardinality and contains no learner, attempt, activity, objective, or raw-content identifiers.
- Assumptions:
  - The `data_model` work has persisted immutable Section model selection and Section-pinned Revisions.
  - The `core_impl` work is the only writer of `learning_states`; this work is read-only with respect to model state.
  - Objective `SectionResource.children` or `objectives_with_effective_children/2` is the effective parent/child authority for delivery.
  - `SectionResourceDepot` contains page, container, and objective records and is the delivery hierarchy authority.
  - Existing Metrics results are compatibility contracts; ordering is only contractual where current callers/tests depend on it.
  - No visible confidence/coverage UI is added until its accessibility and wording contract is approved.
  - Authoring Insights remains a descriptive `ResourceSummary` consumer and is not routed through proficiency providers.

## 3. Repository Context Summary

- What we know:
  - `lib/oli/delivery/metrics.ex` owns the current naive formulas and exposes twelve proficiency functions with heterogeneous return shapes.
  - `lib/oli/learning_model/learning_state.ex` and migration `20260824120000_create_learning_model_operational_tables.exs` provide a composite primary key on `(section_id, user_id, learning_objective_id)` and store AOA, attempt count, unique activity-part count, and confidence.
  - `lib/oli/delivery/sections/post_processing.ex` already bulk-projects activity objective attachments into objective `related_activities`, but it neither projects page `activity_refs` nor publishes changed records to the depot.
  - `lib/oli/delivery/sections/section_resource_depot.ex` caches pages, containers, and objectives and delegates distributed mutations to `DepotCoordinator.update_all/2` or `clear/2`.
  - `PostProcessing.apply/2` is invoked by project/Section creation, blueprint/template creation, open-and-free creation, publication update, and other Section lifecycle paths using `:all`.
  - `ProgressProficiency` duplicates the naive SQL formula. `ObjectivesProficiency` delegates to Metrics but passes `section_id`, uses `ContainedObjective` for scope, and emits only distributions.
  - Dashboard cache identity already includes oracle and data versions; incrementing oracle versions naturally prevents old entries from satisfying new requests.
  - `ProficiencyAssertion` calculates class proficiency from raw naive tuples and therefore cannot verify LKT-AOA.
  - `ContainedObjective` includes relationships broader than activity-derived page membership and must remain available without becoming the LKT-AOA scope authority.
- Unknowns to confirm:
  - N/A. Current depot coordination offers no transaction spanning PostgreSQL and distributed ETS, so the design uses database-first JIT migration followed by depot load/update and fail-closed recovery.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.Delivery.Proficiency`

- Public model-neutral API for new code.
- Accepts `%Section{}` as its first argument and rejects unsupported/missing model versions.
- Dispatches once at the boundary; no provider or presentation component re-dispatches.
- Exposes direct-objective, learner-scope, instructor-objective, and instructor-scope operations.

`Oli.Delivery.Proficiency.Estimate`

- Typed value for one learner/objective or one learner/scope display result.
- Carries identity, score, label, confidence, evidence counts, and model provenance.
- Uses atoms internally for labels: `:low`, `:medium`, `:high`, `:not_enough_information`, and `:unavailable`.
- Keeps `nil` score distinct from `0.0`; adapters alone convert labels to legacy strings.

`Oli.Delivery.Proficiency.Aggregate`

- Typed wrapper for rollups and instructor payloads.
- Contains an optional display `estimate`, an optional `numeric_score`, categorical distribution, contributing/eligible/total counts, and coverage metadata.
- Keeps numeric aggregation, display eligibility, confidence, and coverage orthogonal. Parent display eligibility depends on total attempts across all effective children, not on a per-child minimum.

`Oli.Delivery.Proficiency.Naive`

- Owns all `ResourceSummary` queries, the first-attempt formula, the three-first-attempt gate, and naive bucket boundaries.
- Produces canonical values for new APIs and retains raw summary tuple helpers only for legacy adapter implementation.
- Does not read `learning_states`.

`Oli.Delivery.Proficiency.LktAoa`

- Bulk-reads `learning_states` for requested Section, learner, and objective identity sets.
- Implements direct eligibility, parent rollup, learner scope rollup, class rollup, confidence, and coverage.
- Does not query PartAttempt, ActivityAttempt, ResourceSummary, or other attempt-history tables.

`Oli.Delivery.Proficiency.ScopeMembership`

- Pure/in-memory transformation over SectionResource records obtained from the depot.
- Builds one `activity_id => MapSet<objective_id>` index from objective `related_activities`.
- Maps page `related_activities` through that index, deduplicates objective IDs, and unions descendant page sets for container/course scopes.
- Returns an explicit membership-unavailable error when required page projections are not known to be coherent.

`Oli.Delivery.Metrics`

- Remains the compatibility facade for current callers.
- Adds preferred `%Section{}` clauses and temporary integer-ID clauses that load once and delegate.
- Converts canonical atom labels to the exact current strings and reconstructs existing tuple/map/row shapes.
- Leaves non-proficiency metrics untouched.

`Oli.Delivery.Sections.PostProcessing`

- Extends `:related_activities` to calculate objective and page projection values in the same run.
- Persists all changed SectionResource rows in bulk, reloads/returns the updated structs, and calls `DepotCoordinator.update_all/2` only after database success.
- Treats a depot publication failure as post-processing failure and logs enough bounded context for repair.

`Oli.Delivery.Sections.SectionResourceMigration`

- Owns a monotonically increasing current migration version for the complete SectionResource projection shape.
- Replaces heuristic-only readiness checks with a deterministic Section-level integer version comparison.
- Provides `ensure_current/1`, invoked by `SectionResourceDepot.process_table_creation/1` before any Section records are loaded into ETS.
- Serializes concurrent first access with a Section-row lock, rechecks the stored version inside the transaction, runs all missing migration steps including page/objective `related_activities`, and advances the marker only after every database step succeeds.

Instructor dashboard oracles and projections

- `ProgressProficiency` loads the Section and delegates proficiency to the facade while retaining its existing progress query.
- `ObjectivesProficiency` passes the Section and uses the new membership/provider boundary. It adds only data required by current dashboard consumers; confidence/coverage presentation is outside scope.
- Both affected oracle versions increment. Downstream projectors and CSV serializers prefer actual numeric fields when `learning_model_version == :lkt_aoa`; naive compatibility paths may retain current category reconstruction.
- Presentation and serializers never calculate proficiency or choose a provider.

Scenario assertion

- Resolves the Section and objective as today, calls canonical direct or class APIs, and asserts the canonical label/score.
- Supports both models without raw-summary access or formula reconstruction.

### 4.2 State & Data Flow

Direct objective flow:

1. Caller passes `%Section{}`, learner IDs, and objective IDs to `Proficiency`.
2. `Proficiency` selects exactly one provider from `learning_model_version`.
3. Naive bulk-reads `ResourceSummary`; LKT-AOA bulk-reads `learning_states` by the supplied identity sets.
4. Provider applies its own evidence gate and bucketing and returns canonical estimates keyed by objective and learner.
5. New consumers use canonical values; Metrics adapters translate them for legacy consumers.

Parent-objective flow:

1. Load effective objective children once from `SectionResourceDepot.objectives_with_effective_children/2`.
2. Build the requested parent-to-effective-child map in memory.
3. Bulk-read child learner states once.
4. Compute `sum(child.aoa * child.attempt_count) / sum(child.attempt_count)` across available effective-child states; do not read or persist parent state.
5. If total child attempts are fewer than three, return not-enough-information. Otherwise return the weighted parent estimate. No individual child minimum suppresses the parent result.

Page/container/course flow:

1. Read page, container, and objective SectionResources from the initialized depot.
2. Rely on the depot-driven JIT migration having advanced the Section to the version that introduced page projections. At that version, `related_activities: []` validly means the page embeds no activities.
3. Build one activity-to-objective index, derive each page objective set, and derive requested container/course unions from the depot hierarchy.
4. Bulk-read all required learner/objective states in one query.
5. For each learner/scope, sum available state `attempt_count`; below three returns not-enough-information.
6. Otherwise average each distinct available AOA once, irrespective of attempt count, confidence, unique parts, activity references, or page repetition.
7. For class results, average defined learner scope scores once per learner, retain excluded learners in the categorical distribution, and report contributing and total learner counts.

Projection flow:

1. Query all Section-pinned objective, activity, and page Revisions through `DeliveryResolver.section_resource_revisions/1`.
2. Reverse activity objective attachments into distinct objective-to-activity IDs.
3. Copy distinct `Revision.activity_refs` into each page record; do not inspect page `objectives`.
4. Persist changed objective and page arrays in one database transaction using parameterized Ecto/SQL operations.
5. Publish the updated SectionResource structs through `DepotCoordinator.update_all/2` after commit.
6. If distributed publication fails, clear the Section's depot table where possible and return failure; the next read reinitializes from PostgreSQL.

Legacy JIT migration flow:

1. A depot miss reaches `SectionResourceDepot.process_table_creation(section_id)`.
2. `SectionResourceMigration.ensure_current(section_id)` starts a transaction and locks the Section row.
3. It compares persisted `section_resource_migration_version` with the module's current version and returns immediately when current.
4. Otherwise it applies each missing ordered migration step, including the page/objective `related_activities` projection from Section-pinned Revisions.
5. It updates the Section marker to the current version in the same transaction and commits.
6. Only after success does `SectionResourceDepot` load PostgreSQL rows into ETS. On failure it creates no populated depot table and propagates the error so a later access can retry.

Dashboard flow:

1. Oracle context resolves the authorized Section and scope.
2. Affected oracles call the model-aware API and emit versioned payloads.
3. Deployment restarts the application, removing old in-memory cache entries; changed oracle versions additionally prevent payload-contract collisions.
4. Snapshot assembly carries actual numeric values and coverage metadata to projectors.
5. LKT-AOA projectors/serializers use actual values; naive paths preserve established outputs.

### 4.3 Lifecycle & Ownership

- `learning_states` remains owned by the core LKT-AOA write pipeline. Reads never mutate or backfill it.
- Section `learning_model_version` remains owned by trusted creation workflows and is immutable to ordinary product changesets. Section model migration is outside this work item.
- Section `section_resource_migration_version` is owned exclusively by `SectionResourceMigration`; ordinary Section changesets and user input cannot set it.
- Section-pinned Revision identity remains owned by publication and Section update workflows.
- `section_resources.related_activities` is a rebuildable delivery projection owned by Section post-processing.
- PostgreSQL is authoritative for SectionResource projections; the distributed depot is the read-optimized copy and must be updated or cleared after writes.
- Proficiency scope and aggregate results are ephemeral and are never stored in new tables.
- Oracle modules own payload schema/version; dashboard cache infrastructure owns retention and version-aware lookup.
- Metrics owns legacy shape conversion only; model rules belong to providers.

### 4.4 Alternatives Considered

- Add model branches throughout current Metrics functions: rejected because heterogeneous legacy shapes would become the provider contract and model selection would remain easy to duplicate.
- Replace Metrics immediately: rejected because the consumer inventory is broad and naive compatibility risk is high; a facade permits incremental migration.
- Add `contained_page_objectives`: rejected because both relationship sides and hierarchy already exist in the SRD; another table adds lifecycle and consistency burden.
- Use `ContainedObjective` for LKT-AOA scopes: rejected because it includes direct page-objective attachments that are explicitly excluded.
- Query pinned Revisions on every delivery read: rejected because membership is stable delivery projection data and this would add repeated database work to learner/dashboard hot paths.
- Run a deployment-wide SectionResource backfill: rejected because the repository uses depot-driven JIT SectionResource migration and a fleet-wide migration would create unnecessary rollout work and locking risk.
- Infer readiness from `related_activities != []`: rejected because a successfully projected page with no embedded activities has the same empty value as an unprocessed legacy row.
- Persist page/container/course/parent aggregates: rejected because learner state is Section-wide and changes after every evaluated attempt, making derived-state invalidation costly and unnecessary.
- Fall back to naive on missing LKT-AOA data: rejected because it silently mixes semantics inside one Section/view.
- Make one shared bucket function: rejected because evidence eligibility and the 0.4 boundary differ by provider.

## 5. Interfaces

- Canonical estimate:

```elixir
@type label :: :low | :medium | :high | :not_enough_information | :unavailable

@type t :: %Oli.Delivery.Proficiency.Estimate{
  section_id: pos_integer(),
  user_id: pos_integer() | nil,
  learning_objective_id: pos_integer() | nil,
  score: float() | nil,
  label: label(),
  confidence: float() | nil,
  attempt_count: non_neg_integer(),
  unique_activity_part_count: non_neg_integer(),
  learning_model_version: :naive | :lkt_aoa
}
```

- Aggregate wrapper:

```elixir
@type t :: %Oli.Delivery.Proficiency.Aggregate{
  estimate: Estimate.t() | nil,
  numeric_score: float() | nil,
  distribution: %{optional(Estimate.label()) => non_neg_integer()},
  contributing_count: non_neg_integer(),
  eligible_count: non_neg_integer(),
  total_count: non_neg_integer(),
  coverage: map()
}
```

- Public API shape. Exact names may follow repository naming, but these responsibilities and result semantics are fixed:

```elixir
@spec estimates_for_objectives(Section.t(), [user_id()], [objective_id()], keyword()) ::
  {:ok, %{optional(objective_id()) => %{optional(user_id()) => Estimate.t()}}}
  | {:error, reason()}

@spec estimates_for_scopes(Section.t(), [user_id()], [scope()], keyword()) ::
  {:ok, %{optional(scope()) => %{optional(user_id()) => Estimate.t()}}}
  | {:error, reason()}

@spec objective_aggregates(Section.t(), [objective_id()], keyword()) ::
  {:ok, %{optional(objective_id()) => Aggregate.t()}} | {:error, reason()}

@spec scope_aggregates(Section.t(), [scope()], keyword()) ::
  {:ok, %{optional(scope()) => Aggregate.t()}} | {:error, reason()}
```

- `scope()` is a tagged value such as `{:page, resource_id}`, `{:container, resource_id}`, or `:course`; it is never an untyped model option.
- Expected errors include `{:unsupported_learning_model, value}`, `{:section_not_found, id}`, `{:scope_membership_unavailable, reason}`, and `{:invalid_scope, value}`. Providers return data-level insufficient evidence as estimates, not errors.
- Temporary Metrics integer-ID clauses call `Sections.get_section!/1` once, then delegate to the `%Section{}` clause. Internal call sites with a Section must not use the ID clause.
- Legacy adapter mapping is explicit: canonical labels map to current strings (`"Low"`, `"Medium"`, `"High"`, `"Not enough data"`); `:unavailable` maps only to a consumer-supported unavailable state and never to a naive result.
- `raw_proficiency_per_learning_objective/2` is marked naive-only/deprecated or moved under `Proficiency.Naive`; it cannot dispatch to LKT-AOA with a new tuple interpretation.
- `SectionResourceDepot` gains a bulk read helper only if existing `get_section_resources_by_type_ids/2` plus hierarchy functions cannot supply the records without repeated queries. Membership logic remains outside the depot storage adapter.
- `SectionResourceMigration.current_version/0` returns the integer projection version expected by the release. `ensure_current/1` returns `{:ok, :current | :migrated}` or `{:error, reason}`; `SectionResourceDepot.process_table_creation/1` must not call its loader after an error.

## 6. Data Model & Storage

- No new proficiency or membership table is introduced.
- Reuse `learning_states` and its composite primary key for direct/bulk lookups. The primary-key order supports Section-scoped learner/objective reads; query-plan tests determine whether an additional Section/objective/user index is necessary for instructor workloads. No speculative index is required before evidence.
- Reuse `section_resources.related_activities bigint[]` with type-specific semantics:
  - objective: distinct activity resource IDs whose Section-pinned activity Revision targets the objective;
  - page: distinct activity resource IDs in the Section-pinned page Revision's `activity_refs`;
  - other types: `[]` unless a future contract states otherwise.
- Update `SectionResource` module documentation to state both meanings.
- Add non-null integer `sections.section_resource_migration_version`, defaulting legacy and newly inserted raw rows to `0`. `SectionResourceMigration` defines the positive current version and is the only writer.
- Empty page activity membership is valid data only when the Section marker is at least the version that introduced page `related_activities`. A lower version requires JIT migration; `[]` is never itself a readiness signal.
- Normal Section creation/post-processing should populate current projections and advance the marker. If a creation path does not, first depot access safely performs the JIT migration.
- Parent, page, container, course, and class aggregates are computed at read time and are not persisted.
- No change is made to `ContainedObjective`, `ContainedPage`, ResourceSummary, attempt history, or Authoring Insights storage.

## 7. Consistency & Transactions

- Compute projection values before opening the write transaction; write all changed page/objective arrays in one transaction using parameterized values.
- JIT migration locks the Section row with `FOR UPDATE`, rechecks its version after acquiring the lock, applies missing ordered steps, and advances the marker within one transaction. This prevents concurrent nodes from independently marking incomplete work current.
- A database error rolls back every related-activities update and prevents depot publication.
- After commit, publish the exact updated structs through `DepotCoordinator.update_all/2`. If that fails, best-effort clear the Section depot and return an error so callers do not treat post-processing as successful.
- Existing `PostProcessing.apply/2` currently ignores the private projection function's `:error`. Implementation must make `:related_activities` failure observable to lifecycle callers, either with a result-returning internal API and raising compatibility wrapper or an explicit result contract migrated across all call sites.
- Cross-system atomicity between PostgreSQL and distributed ETS is impossible. Fail-closed ordering—database first, then update-or-clear depot—ensures the depot is never intentionally populated with uncommitted data and can recover by reload.
- Read paths do not hold transactions while traversing depot data or formatting results.
- A single provider invocation uses one captured Section/model value and cannot redispatch mid-call.

## 8. Caching Strategy

- `SectionResourceDepot` remains the only new hot-path membership cache. Do not add a second activity/objective membership cache until measurement demonstrates a need.
- Projection writes use `DepotCoordinator.update_all/2`; on uncertain publication, clear the Section table so the next access reloads PostgreSQL.
- Provider estimates and aggregates are not globally cached in this work item because learning state changes after attempts and cache invalidation would broaden the write path.
- Instructor dashboard results continue using the existing oracle cache. Increment `ProgressProficiency.version/0` and `ObjectivesProficiency.version/0` when their calculations/payloads change.
- Cache keys already include oracle and data versions. The mandatory rollout restart clears existing in-memory cache state; on first access each Section's depot performs the versioned JIT migration before loading. Section model migration handling is outside scope.
- Ordinary attempt-driven freshness continues to follow the dashboard's existing data-version/snapshot lifecycle; this work does not introduce a parallel invalidation system.

## 9. Performance & Scalability Posture

- Normalize/deduplicate all requested learner, objective, activity, page, and scope IDs before reads.
- For each provider call, fetch all needed `learning_states` using set predicates on `section_id`, `user_id`, and `learning_objective_id`, then group in memory. Never call Repo from an inner learner/objective loop.
- Build the activity-to-objective index once per scope request in `O(A + R)`, where `A` is objective-activity relationships and `R` is page activity references.
- Derive all requested page and container objective sets in one hierarchy traversal; reuse sets for ancestor unions.
- Keep `MapSet` values during derivation and convert to stable sorted lists only at API/serialization boundaries.
- Objective/page projection uses a bounded number of bulk queries and one bulk update independent of relationship count. Parameterized Ecto/SQL avoids the current interpolated CASE construction and query-size/injection concerns.
- Query-count tests must show constant database round trips for fixed operation type as learner/objective cardinality grows; result processing may grow linearly with returned rows.
- Telemetry/AppSignal should make provider duration, row count, scope count, unavailable count, and query-count regressions observable. No fixed latency SLO is invented in this work item.

## 10. Failure Modes & Resilience

- Unsupported or absent Section model: return `{:error, {:unsupported_learning_model, value}}`; do not assume naive.
- Integer-ID compatibility lookup fails: return/raise according to the legacy function's established contract before provider dispatch.
- Missing direct learning state: return a not-enough-information estimate with `score: nil`, not zero.
- Direct state below three attempts: return not-enough-information while preserving evidence counts and confidence.
- No available states in a page/container/course: return not-enough-information with zero contributors.
- JIT migration fails: do not load/populate that Section's depot table, do not advance its migration version, and propagate the failure so later access can retry; never use `ContainedObjective`, latest authoring Revisions, or naive fallback.
- Empty but ready page projection: treat as a valid scope with no objectives, not an infrastructure failure.
- Post-processing database failure: roll back and report failure.
- Depot update failure after commit: clear depot best-effort, log bounded Section/projection counts, and report failure so retry/repair can reload the database truth.
- Missing objective SectionResources: return bounded unavailable/partial metadata and log counts; never log learner IDs or dump the requested identity lists.
- Dashboard cache contains an old payload: oracle-version mismatch produces a miss; projection code must reject malformed new-version payloads explicitly.
- One learner lacks evidence in a class aggregate: exclude that learner from the numeric mean but include not-enough-information in the distribution and coverage counts.
- Parent total child attempts are fewer than three: return not-enough-information; no individual child minimum suppresses an otherwise eligible parent.

## 11. Observability

- Emit one telemetry span/event per public provider operation with bounded fields: model, operation (`direct_objective`, `parent_objective`, `learner_scope`, `class_scope`), scope type, duration, requested counts, returned row count, defined count, unavailable count, and outcome.
- Emit projection telemetry with Section type (not ID), page/objective/activity counts, changed row count, database duration, depot publication outcome, and total duration.
- Log errors with bounded Section slug or ID only where existing operational policy permits it; never log user IDs, attempt IDs, objective/activity ID lists, raw Revision content, scores, or confidence values.
- Use AppSignal to inspect provider latency, error rate, and cardinality/query scaling during test-environment rollout.
- Add explicit warning/error reason codes for projection-not-ready, depot-publication failure, unsupported model, and malformed oracle payload.
- No new alerts are mandated until baseline traffic establishes useful thresholds.

## 12. Security & Privacy

- Preserve existing controller/LiveView/oracle authorization and Section-scoped enrollment boundaries. The proficiency API is a domain service, not a new public endpoint.
- Every query is constrained by the supplied authorized Section ID; do not accept a Section ID and an independently supplied model or tenant identity.
- Instructor aggregates may expose learner rows only through existing instructor-authorized consumers. Aggregate confidence has no new minimum-enrollment suppression, consistent with the technical notes, but existing privacy policies still apply.
- Use parameterized queries for bulk projection and state reads. Replace raw interpolation of SectionResource IDs/activity arrays in the current projection update.
- Telemetry and logs exclude learner identifiers and sensitive educational records.
- Do not expose internal model coefficients or Revision parameter payloads through proficiency responses.
- This work adds no role, permission, route, or user-controlled model-selection surface.

## 13. Testing Strategy

- Pure/provider ExUnit tests:
  - estimate validation, label mapping, `nil` versus `0.0`, naive/LKT boundary differences, and aggregate math;
  - naive formula and legacy return-shape characterization;
  - direct LKT-AOA eligibility and confidence from persisted state;
  - parent attempt-count weighting and the aggregate three-total-attempt display gate, including a child below three that does not suppress the parent;
  - page/container/course deduplication, unweighted averaging, missing-state omission, scope-wide three-attempt gate, multi-page reuse, and class contributor counts.
- Query/integration ExUnit tests:
  - assert LKT-AOA reads issue no attempt/ResourceSummary query;
  - compare query counts for small and large learner/objective sets;
  - prove membership performs no Repo call after depot initialization;
  - test the existing `learning_states` primary key query plan and add an index only if needed.
- Section post-processing tests:
  - objective and page type-specific arrays from Section-pinned Revisions;
  - direct page-objective attachments excluded;
  - duplicates removed and empty pages stored as `[]`;
  - creation, blueprint/template, publication update, duplication/remix, and repair/migration invocation paths;
  - database rollback, distributed update, update failure followed by clear/reload, and multi-node coherence where supported.
- JIT migration tests:
  - legacy version `0` migrates on first depot initialization and advances only after page/objective projections commit;
  - a current Section performs no migration writes;
  - a failed step rolls back projection changes and the version marker;
  - concurrent initialization serializes on the Section row and performs each version step once;
  - a successfully migrated page with no activities retains `[]` without retriggering migration;
  - new Section creation either marks current after post-processing or is safely upgraded on first access.
- Consumer tests:
  - every Metrics entry point retains naive behavior;
  - student lesson/prologue/review/dashboard, classic instructor helpers, LO elements, expanded objectives, and `get_objectives_and_subobjectives/2` receive model-aware results without UI dispatch;
  - ProgressProficiency has no direct ResourceSummary formula;
  - oracle versions and payloads carry numeric aggregates required by current consumers; no confidence/coverage UI is introduced;
  - summary/projector/CSV paths use actual LKT-AOA values and retain naive compatibility.
- Scenario tests:
  - extend the proficiency assertion to canonical estimates;
  - execute real authoring, publishing, section creation, enrollment, attempt evaluation, and assertion workflows for both models;
  - validate YAML through `Oli.Scenarios.validate_file/1` and run the companion ExUnit runner.
- Review and gates:
  - run targeted `mix test` suites, then broader delivery/instructor-dashboard regressions as risk warrants;
  - run `mix format` and `git diff --check`;
  - required review lenses are security, performance, Elixir, and requirements; add UI review only if visible confidence/coverage behavior enters scope.

## 14. Backwards Compatibility

- Existing Sections remain `:naive`; no migration rewrites them to LKT-AOA.
- Existing Metrics function names and argument forms remain during migration. `%Section{}` is preferred; integer-ID forms perform one Section lookup.
- Naive formula, minimum evidence rule, exact 0.4/0.8 boundaries, strings, maps, tuples, and student rows remain byte-for-byte or semantically equivalent.
- LKT-AOA uses `< 0.4` Low, `0.4..0.8` Medium, and `> 0.8` High; this intentionally differs from naive at exactly 0.4.
- `raw_proficiency_per_learning_objective/2` remains explicitly naive-only or deprecated; it never changes tuple meaning by Section model.
- Existing `ContainedObjective` consumers and Authoring Insights remain unchanged.
- The mandatory application restart clears old in-memory cache payloads, and oracle version increments prevent contract collisions. Naive dashboard numeric reconstruction may remain for compatibility, but LKT-AOA never uses it.
- Presentation label adapters continue emitting `"Not enough data"` where legacy contracts require it even though canonical code uses `:not_enough_information`.

## 15. Risks & Mitigations

- JIT migration can be triggered concurrently across nodes: serialize with a Section-row lock, recheck the version inside the transaction, and mark current only after all projection writes succeed.
- Post-processing currently swallows projection errors: make failure part of the lifecycle contract and add rollback/update-clear tests.
- Distributed depot cannot share a PostgreSQL transaction: commit database truth first, then update or clear all depots and fail closed until reload.
- Large compatibility surface can hide drift: characterize every Metrics function before extracting code and migrate consumers in bounded groups.
- Instructor reads can become N+1: expose only bulk provider APIs for dashboard use and enforce query-count tests.
- Label-based downstream calculations can silently survive: inventory formulas with repository search and require actual numeric LKT-AOA payload tests for summaries and CSV.
- Stale oracle/snapshot data can survive code deployment: require the application restart and increment affected oracle versions.
- Confidence can be mistaken for proficiency: distinct contract fields, no score modification, and no new display until UX approval.
- Raw SQL projection construction is fragile: use parameterized bulk updates and validate arrays rather than interpolating identifiers.

## 16. Open Questions & Follow-ups

- Confidence and coverage presentation is explicitly deferred to a separate UI work item.
- `get_objectives_and_subobjectives/2` keeps its current label/distribution contract unless implementation discovers a concrete current consumer that requires additional canonical fields.

## 17. References

- `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`
- `docs/exec-plans/current/epics/learning_model_v2/usage/prd.md`
- `docs/exec-plans/current/epics/learning_model_v2/usage/requirements.yml`
- `docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/`
- `docs/exec-plans/current/epics/learning_model_v2/core_impl/`
- [MER-5846](https://eliterate.atlassian.net/browse/MER-5846)
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/attempt.md`
- `lib/oli/delivery/metrics.ex`
- `lib/oli/delivery/sections/post_processing.ex`
- `lib/oli/delivery/sections/section_resource.ex`
- `lib/oli/delivery/sections/section_resource_depot.ex`
- `lib/oli/learning_model/learning_state.ex`
- `lib/oli/instructor_dashboard/oracles/progress_proficiency.ex`
- `lib/oli/instructor_dashboard/oracles/objectives_proficiency.ex`
- `lib/oli/scenarios/directives/assert/proficiency_assertion.ex`
