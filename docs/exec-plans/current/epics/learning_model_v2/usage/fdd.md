# Learning Model: Proficiency Reads and Usage - Functional Design Document

## 1. Executive Summary

This work item adds a model-aware proficiency read boundary for Torus delivery, dashboard, and scenario consumers. Existing `:naive` Sections keep their current `ResourceSummary`-based behavior. Sections pinned to `:lkt_aoa` read displayed proficiency from materialized `learning_states.aoa` and expose `learning_states.confidence` as a separate raw `0.0..1.0` signal.

The implementation centers on `Oli.Delivery.Proficiency`, with provider modules for `:naive` and `:lkt_aoa`. Existing `Oli.Delivery.Metrics` functions remain as a compatibility facade while their internals move toward provider-backed dispatch.

The design is performance-driven. Proficiency reads must be set-based, must not scan historical attempts for LKT-AOA results, and must not query delivery-time Revision content to resolve page/container/course learning-objective membership. Page `SectionResource.related_activities` will be populated during Section post-processing so membership can be resolved from `SectionResourceDepot` in memory.

Full technical discussion and policy rationale live in `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`; this FDD intentionally summarizes the decisions and makes implementation boundaries explicit.

## 2. Requirements & Assumptions

- Functional requirements:
  - Dispatch proficiency reads from `Section.learning_model_version`.
  - Preserve naive formulas, thresholds, minimum-attempt behavior, and legacy return shapes.
  - Read direct LKT-AOA learning-objective estimates from `learning_states`.
  - Provide a canonical estimate shape for new consumers.
  - Aggregate LKT-AOA estimates across parent objectives, pages, containers, course scope, learners, and class views where policy is defined.
  - Populate page `SectionResource.related_activities` with embedded activity resource IDs.
  - Migrate dashboard oracles and scenario assertions away from duplicated naive formulas.
  - Keep Authoring Insights descriptive and separate from learner proficiency semantics.

- Non-functional requirements:
  - LKT-AOA reads must not scan `part_attempts`.
  - Learning-objective, learner, class, page, container, and course reads must use set-based queries.
  - Page/container/course membership must be resolved from `SectionResourceDepot` data and in-memory indexes.
  - A rendered consumer must not mix naive and LKT-AOA providers.
  - Missing LKT-AOA state must produce not-enough-information or unavailable, not numeric zero.
  - Dashboard snapshot cache invalidation must not change in this work item.

- Assumptions:
  - The core implementation work item has created and maintains `learning_states`, `prior_activity_part_evidence`, and `attempt_applications`.
  - `learning_states.aoa` is the displayed LKT-AOA proficiency value.
  - `learning_states.confidence` is returned raw only; Low/Medium/High confidence bucketing is future work.
  - Existing Sections remain `:naive` unless explicitly configured otherwise.
  - Existing `ResourceSummary` analytics remain the source for naive proficiency and descriptive analytics.
  - Page proficiency membership excludes objectives attached directly to page Revisions.

## 3. Repository Context Summary

- What we know:
  - `Oli.Delivery.Metrics` currently owns most proficiency reads and calculates naive proficiency from `Oli.Analytics.Summary.ResourceSummary`.
  - Current Metrics APIs return several legacy shapes: tuples, strings, nested maps, distribution maps, and row structures.
  - `learning_states` stores materialized LKT-AOA state keyed by Section, user, and learning objective.
  - `Oli.LearningModel.LktAoa.Application` applies write-side state only for `:lkt_aoa` Sections.
  - `Oli.Delivery.Sections.PostProcessing` already has a `:related_activities` action that populates objective SectionResources from activity objective attachments.
  - `Oli.Delivery.Sections.SectionResourceDepot` caches SectionResource rows for delivery-time reads and currently includes containers, pages, and objectives.
  - `Oli.InstructorDashboard.Oracles.ObjectivesProficiency` already delegates to Metrics.
  - `Oli.InstructorDashboard.Oracles.ProgressProficiency` currently repeats a naive `ResourceSummary` formula.
  - `Oli.Scenarios.Directives.Assert.ProficiencyAssertion` currently reconstructs naive proficiency for some paths.

- Unknowns to confirm during implementation:
  - Exact legacy return shapes for every Metrics function that must remain compatible.
  - Whether any secondary dashboard projection assumes label-derived average proficiency and must be adjusted to consume numeric aggregate values.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Introduce the following read-side modules:

- `Oli.Delivery.Proficiency`: model-aware facade for new consumers. It accepts loaded `%Section{}` structs and delegates by `section.learning_model_version`.
- `Oli.Delivery.Proficiency.Estimate`: canonical result struct for new provider APIs.
- `Oli.Delivery.Proficiency.Naive`: provider that preserves existing `ResourceSummary` formulas and thresholds.
- `Oli.Delivery.Proficiency.LktAoa`: provider that reads `learning_states`, resolves LKT-AOA scope membership, and returns canonical estimates.
- `Oli.Delivery.Proficiency.Scope`: in-memory scope resolver that derives learning-objective membership from SectionResourceDepot rows.

Keep `Oli.Delivery.Metrics` as the compatibility facade for existing callers. Metrics functions should delegate to `Oli.Delivery.Proficiency` where possible, then adapt canonical estimates back into the established return shape.

Presentation components must not branch on `learning_model_version`. The provider/facade owns model dispatch and returns values in the contract expected by the caller.

### 4.2 State & Data Flow

Direct LKT-AOA objective read:

1. Caller passes `%Section{learning_model_version: :lkt_aoa}` and one or more learning-objective IDs.
2. `Oli.Delivery.Proficiency` dispatches to `Oli.Delivery.Proficiency.LktAoa`.
3. The provider bulk-reads matching `learning_states` rows by `section_id`, `user_id` or enrolled learner set, and `learning_objective_id`.
4. Each row becomes an `Estimate` with:
   - `score: learning_state.aoa` when eligible
   - `confidence: learning_state.confidence`
   - `attempt_count`
   - `unique_activity_part_count`
   - model provenance
5. Missing rows or rows below the minimum-attempt threshold become not-enough-information.

Page/container/course LKT-AOA read:

1. Resolve the relevant page SectionResources from the SectionResourceDepot.
2. Resolve objective SectionResources from the SectionResourceDepot.
3. Build an in-memory `activity_resource_id -> learning_objective_resource_ids` index from objective SectionResource `related_activities`.
4. For each page, map page `related_activities` through that index and deduplicate learning-objective IDs.
5. For containers and course scope, union the deduplicated page objective sets across descendant pages.
6. Bulk-read learner states for the resulting learning-objective set.
7. Aggregate with the unweighted rules in section 4.3.

### 4.3 Lifecycle & Ownership

`Section.learning_model_version` is the only dispatch source. Callers must not override the selected model through an option, Project setting, parameter presence, or `analytics_version`.

Naive proficiency remains owned by `ResourceSummary` and the naive provider. LKT-AOA proficiency remains owned by `learning_states`. No read path should recompute LKT-AOA from historical PartAttempts.

Page `SectionResource.related_activities` is owned by Section post-processing. It must be populated when Section-pinned content is established or changed, including Section creation, template creation, publication updates, duplication/remix flows, and repair jobs that rebuild SectionResource projections.

For already-created SectionResource rows, use the existing JIT SectionResource migration pattern rather than introducing a broad standalone data migration as the primary path. `SectionResourceDepot.process_table_creation/1` already checks `SectionResourceMigration.requires_migration?/1`, migrates SectionResource rows when needed, and then loads the depot table. Extend that pattern so page `related_activities` is populated before a SectionResourceDepot table is created.

The SectionResourceDepot is the delivery-time source for page/container/course membership. Database row updates and depot state must not diverge after post-processing succeeds.

### 4.4 Alternatives Considered

- Continue branching inside `Oli.Delivery.Metrics`.
  - Rejected because Metrics already exposes inconsistent legacy shapes and would spread model-specific logic through compatibility code.

- Query Revisions at delivery time to determine page/objective membership.
  - Rejected because it violates the performance goal and risks resolving latest authoring content rather than Section-pinned content.

- Add a dedicated page-objective membership table.
  - Rejected for this slice because the existing SectionResourceDepot can support the required membership relation once page `related_activities` is populated.

- Fall back to naive when LKT-AOA data is unavailable.
  - Rejected because a single rendered view must not mix proficiency models.

## 5. Interfaces

- New provider facade:

```elixir
Oli.Delivery.Proficiency.proficiency_for_student_per_learning_objective(
  %Section{} = section,
  learning_objective_ids_or_revisions,
  user_id,
  opts \\ []
)

Oli.Delivery.Proficiency.proficiency_per_student_for_objective(
  %Section{} = section,
  learning_objective_ids,
  opts \\ []
)

Oli.Delivery.Proficiency.proficiency_for_student_per_page(
  %Section{} = section,
  user_id,
  page_ids_or_scope,
  opts \\ []
)

Oli.Delivery.Proficiency.proficiency_for_student_per_container(
  %Section{} = section,
  user_id,
  container_id_or_scope,
  opts \\ []
)

Oli.Delivery.Proficiency.proficiency_per_student_across(
  %Section{} = section,
  opts \\ []
)
```

- Canonical estimate:

```elixir
%Oli.Delivery.Proficiency.Estimate{
  section_id: integer(),
  user_id: integer() | nil,
  learning_objective_id: integer() | nil,
  resource_id: integer() | nil,
  resource_type: :learning_objective | :page | :container | :course | nil,
  score: float() | nil,
  label: :low | :medium | :high | :not_enough_information | :unavailable,
  confidence: float() | nil,
  attempt_count: non_neg_integer() | nil,
  unique_activity_part_count: non_neg_integer() | nil,
  contributing_learning_objective_count: non_neg_integer() | nil,
  contributing_learner_count: non_neg_integer() | nil,
  learning_model_version: :naive | :lkt_aoa
}
```

- Compatibility interface:
  - `Oli.Delivery.Metrics` keeps existing public function names and return shapes.
  - New Section-accepting overloads are preferred when callers already have `%Section{}`.
  - Existing `section_id` clauses may load the Section once, then delegate.
  - `raw_proficiency_per_learning_objective/2` remains a naive compatibility path and must not invent an LKT-AOA tuple shape.

- Scope resolver interface:

```elixir
Oli.Delivery.Proficiency.Scope.learning_objectives_for_pages(%Section{}, [page_resource_id])
Oli.Delivery.Proficiency.Scope.learning_objectives_for_container(%Section{}, container_resource_id)
Oli.Delivery.Proficiency.Scope.learning_objectives_for_course(%Section{})
```

These functions resolve from SectionResourceDepot records and return deduplicated learning-objective resource IDs.

## 6. Data Model & Storage

No new table is required for proficiency reads.

This work extends the semantics of the existing `section_resources.related_activities` field:

- For objective SectionResources, it stores activity resource IDs that target that objective.
- For page SectionResources, it stores activity resource IDs embedded in that page.
- For other SectionResource types, it remains empty unless a future contract expands it.

Update `Oli.Delivery.Sections.SectionResource` documentation so the field is not described as objective-only.

Extend `Oli.Delivery.Sections.PostProcessing` `:related_activities` to populate both objective and page rows in bulk:

1. Preserve the current objective reverse mapping from activity objective attachments.
2. For page rows, use the Section-pinned page Revision `activity_refs`.
3. Store distinct activity resource IDs.
4. Store `[]` when a page has no embedded activities.
5. Ignore objectives attached directly to page Revisions.

Existing rows should be brought forward through the established JIT SectionResource migration path:

1. Extend `Oli.Delivery.Sections.SectionResourceMigration.requires_migration?/1` so it also detects page SectionResources whose `related_activities` projection is missing or stale under the new contract.
2. Extend `Oli.Delivery.Sections.SectionResourceMigration.migrate/1` to populate page `related_activities` from Section-pinned page Revisions before `SectionResourceDepot.load/1` copies rows into ETS.
3. Preserve the current revision-field migration behavior; the page-activity projection is an additional migration responsibility, not a replacement.
4. Keep migration set-based. Do not load and update one SectionResource per page.

This approach reuses the existing JIT path:

```text
SectionResourceDepot read
  -> DepotCoordinator.init_if_necessary(...)
  -> SectionResourceDepot.process_table_creation(section_id)
  -> SectionResourceMigration.requires_migration?(section_id)
  -> SectionResourceMigration.migrate(section_id)
  -> SectionResourceDepot.load(section_id)
```

The JIT path is sufficient for rollout because deploying these changes requires shutting down and restarting the Torus server process. SectionResourceDepot tables are in-memory ETS tables, so a restarted server has no warm SRD tables. The first SRD access for each Section after deploy will create the depot table through `SectionResourceDepot.process_table_creation/1`, giving the JIT migration path a chance to populate page `related_activities` before rows are loaded into memory.

## 7. Consistency & Transactions

Read-side consistency expectations:

- A single high-level read dispatches once by Section model and does not call both providers.
- Missing LKT-AOA state is explicit not-enough-information or unavailable.
- A real `0.0` AOA score remains a valid Low proficiency score.
- Naive compatibility paths preserve existing behavior and do not write data.

Post-processing consistency expectations:

- Database `section_resources.related_activities` updates and SectionResourceDepot invalidation/update are part of one logical operation.
- If the database update succeeds but depot refresh fails, the operation must return or log an explicit failure signal rather than silently leaving stale depot data.
- Any bulk update must deduplicate IDs before persistence so repeated embedded activity references or repeated objective attachments do not double-count.

## 8. Caching Strategy

SectionResourceDepot is the cache boundary for page/container/course scope membership. LKT-AOA provider reads should use depot data for membership and issue database queries only for `learning_states` and enrolled learner sets.

This work must not change dashboard snapshot cache invalidation, oracle cache keys, or rebuild behavior. Oracle versions may change only if an implementation intentionally changes an oracle payload contract; cache invalidation policy changes require separate approval.

The selected backfill strategy is JIT SectionResource migration during depot table creation. This keeps delivery reads fast after the first depot load while avoiding a large eager migration over every existing Section. Because deploy restarts clear in-memory SRD tables, no separate warmed-cache repair path is required for normal rollout.

## 9. Performance & Scalability Posture

Performance goals:

- Direct LKT-AOA objective reads are bounded by the requested learner/objective set and read only `learning_states`.
- Instructor/class LKT-AOA reads must bulk-read learners and learning states, not loop through learners or objectives with one query each.
- Page/container/course membership resolution must use in-memory SectionResourceDepot rows and must not query Revisions or PublishedResources at delivery time.
- Scope membership should build the `activity_id -> learning_objective_ids` index once per provider call and reuse it for all requested pages/scopes.
- Page, container, and course aggregates are unweighted arithmetic means, avoiding additional coverage-weight joins.
- Confidence is returned from `learning_states.confidence`; it is not recalculated from evidence at read time.

Required proof:

- Query-count tests or equivalent instrumentation must show fixed query shape when increasing learners/objectives within the same request class.
- Tests must verify no delivery-time Revision lookup is needed for page/container/course membership.

## 10. Failure Modes & Resilience

- Missing `learning_states` row:
  - Return not-enough-information for that learner/objective; omit it from scope means.

- LKT-AOA direct objective with fewer than three attempts:
  - Return not-enough-information.

- Page/container/course scope has fewer than three total attempts across available states:
  - Return not-enough-information.

- Required SRD membership projection is unavailable or page `related_activities` has not been populated:
  - Return unavailable for LKT-AOA scope reads; do not fall back to naive.

- SectionResourceDepot read fails or returns inconsistent records:
  - Return unavailable and log bounded diagnostic context with section ID and scope type.

- Legacy Metrics caller passes only `section_id`:
  - Load the Section once and delegate, or keep the existing naive implementation only where compatibility is explicitly retained.

## 11. Observability

No new dashboard is required.

Add bounded logs or telemetry where useful for:

- LKT-AOA scope membership unavailable.
- Missing SectionResourceDepot page/objective records needed for a scope.
- Post-processing failures while updating page or objective `related_activities`.
- Provider dispatch errors caused by unsupported or missing `learning_model_version`.

Use existing request, dashboard, Ecto, and AppSignal instrumentation for latency and query behavior. Avoid logging learner attempt details, activity responses, or raw historical evidence.

## 12. Security & Privacy

- Proficiency read queries must remain scoped by Section and user/enrollment.
- Instructor/class aggregates may include only learners enrolled in the target Section with learner context roles.
- LKT-AOA read paths must not expose raw PartAttempt answers, attempt histories, or evidence rows.
- Model dispatch must not be caller-controlled.
- Scenario assertion support must not provide a bypass around normal Section/user lookup semantics.

## 13. Testing Strategy

- Unit tests:
  - Estimate label classification for naive and LKT-AOA.
  - Not-enough-information vs real `0.0`.
  - Raw confidence propagation without confidence bucketing.
  - Scope resolver membership from page and objective `related_activities`.
  - Direct page-objective attachments ignored for page proficiency membership.

- Integration tests:
  - Naive parity for existing Metrics APIs and return shapes.
  - LKT-AOA direct objective reads from `learning_states`.
  - LKT-AOA page/container/course aggregation with unweighted arithmetic mean.
  - Parent learning-objective aggregation according to the LKT-AOA technical definition.
  - Instructor/class aggregates excluding not-enough-information learners from numeric averages.
  - Post-processing populates objective and page `related_activities` from Section-pinned Revisions and refreshes/invalidates the SRD.
  - Dashboard oracles delegate through the model-aware facade.
  - `ProgressProficiency` no longer reconstructs proficiency directly from `ResourceSummary`.
  - Scenario proficiency assertions pass for both `:naive` and `:lkt_aoa` Sections.

- Performance tests:
  - Query-count tests for direct objective, scope, and class reads.
  - Regression test proving page/container/course membership resolution does not query Revisions at delivery time.

- Manual validation:
  - A `:naive` Section renders existing learner and instructor proficiency values unchanged.
  - An `:lkt_aoa` Section renders AOA-backed objective and scope values.
  - Missing LKT-AOA state displays as unavailable or not enough information, not zero.
  - Dashboard snapshot cache invalidation behavior is unchanged.

Acceptance-criteria coverage:

| Criteria | Design / verification coverage |
| --- | --- |
| `AC-001`, `AC-002`, `AC-003` | Section-owned dispatch, Section-accepting overloads, and no mixed-provider fallback are covered in sections 4, 5, 7, 10, and provider dispatch tests. |
| `AC-004`, `AC-005`, `AC-010` | Naive compatibility, legacy Metrics return shapes, and `raw_proficiency_per_learning_objective/2` compatibility are covered in sections 4, 5, 13, and naive parity tests. |
| `AC-006`, `AC-007`, `AC-008`, `AC-009` | Direct LKT-AOA reads, missing-state handling, three-attempt objective eligibility, and canonical estimates are covered in sections 4, 5, 7, 10, and learning-state provider tests. |
| `AC-011`, `AC-012`, `AC-013`, `AC-014`, `AC-015`, `AC-016` | Parent, page, container, course, learner, and class aggregation policies are covered in sections 4, 5, 9, 10, and aggregation tests. |
| `AC-017`, `AC-018`, `AC-019`, `AC-020` | Objective/page `related_activities`, Section-pinned page activity projection, SRD membership, and depot coherence are covered in sections 4, 6, 7, 8, 9, and post-processing/SRD tests. |
| `AC-021`, `AC-022`, `AC-023` | Dashboard oracle migration, numeric aggregates, and unchanged snapshot cache invalidation are covered in sections 4, 8, 13, and dashboard oracle/projection tests. |
| `AC-024` | Authoring Insights exclusion is covered in sections 2, 4, 14, and a regression test that it does not read `learning_states` or dispatch through learner proficiency providers. |
| `AC-025`, `AC-026`, `AC-027` | Set-based provider reads, no delivery-time Revision membership queries, and scenario coverage are covered in sections 9 and 13. |

## 14. Backwards Compatibility

Existing `:naive` Sections remain semantically compatible. Existing Metrics callers keep their return shapes while the implementation migrates behind the facade.

Existing Authoring Insights behavior remains unchanged and continues to use descriptive `ResourceSummary` analytics.

Existing dashboard snapshot cache invalidation remains unchanged. If an oracle payload contract changes, versioning can be handled at the oracle boundary, but cache invalidation/rebuild policy is outside this work.

Existing `SectionResource.related_activities` consumers for objectives must continue to receive objective-targeting activity IDs. Extending the field for pages must not alter objective semantics.

## 15. Risks & Mitigations

- Risk: a legacy Metrics return shape changes accidentally.
  - Mitigation: add parity tests before replacing internals with provider dispatch.

- Risk: LKT-AOA views silently fall back to naive when state is missing.
  - Mitigation: centralize dispatch and make unavailable/not-enough-information explicit provider results.

- Risk: page proficiency includes directly attached page objectives.
  - Mitigation: test page membership using only embedded activity relationships.

- Risk: SectionResourceDepot and database `related_activities` diverge.
  - Mitigation: treat post-processing database updates and depot invalidation/update as one operational boundary with tests.

- Risk: instructor dashboards add per-learner/per-objective query loops.
  - Mitigation: require set-based provider queries and query-count tests.

- Risk: dashboard averages continue using label reconstruction.
  - Mitigation: expose actual numeric aggregate values from the provider and update dashboard projections to consume them where LKT-AOA is enabled.

## 16. Open Questions & Follow-ups

- Confirm the exact parent/sub-objective weighting and coverage policy from the LKT-AOA technical definition before implementing parent learning-objective aggregation.
- Identify every dashboard projection and CSV field that currently reconstructs numeric proficiency from labels before implementation planning.
- Future work: confidence Low/Medium/High bucketing and UI treatment.
- Future work: any dashboard snapshot cache invalidation or rebuild-policy changes, if later required.

## 17. References

- `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`
- `docs/exec-plans/current/epics/learning_model_v2/usage/prd.md`
- `docs/exec-plans/current/epics/learning_model_v2/usage/requirements.yml`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/fdd.md`
- `docs/exec-plans/current/epics/learning_model_v2/core_impl/fdd.md`
- `lib/oli/delivery/metrics.ex`
- `lib/oli/delivery/sections/post_processing.ex`
- `lib/oli/delivery/sections/section_resource.ex`
- `lib/oli/delivery/sections/section_resource_depot.ex`
- `lib/oli/instructor_dashboard/oracles/objectives_proficiency.ex`
- `lib/oli/instructor_dashboard/oracles/progress_proficiency.ex`
- `lib/oli/scenarios/directives/assert/proficiency_assertion.ex`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/high-level.md`
