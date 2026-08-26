# Learning Model: Proficiency Reads and Usage - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/learning_model_v2/usage/prd.md`
- FDD: `docs/exec-plans/current/epics/learning_model_v2/usage/fdd.md`
- Technical notes: `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`

## Scope

Implement model-aware proficiency reads for Torus delivery, dashboard, and scenario consumers. Existing `:naive` Sections must preserve current behavior and return shapes. Sections using `:lkt_aoa` must read displayed proficiency from `learning_states.aoa`, expose raw `learning_states.confidence`, and aggregate page/container/course proficiency from SRD-backed learning-objective membership.

This plan does not change LKT-AOA write behavior, Project/Section default model selection, confidence display bucketing, Authoring Insights, xAPI/ClickHouse analytics, or dashboard snapshot cache invalidation.

Each phase must add useful source code comments where the implementation contains a non-obvious domain rule, compatibility constraint, or performance guardrail. Comments should explain why the code exists or why a constraint matters; they should not restate obvious control flow.

## Clarifications & Default Assumptions

- `Section.learning_model_version` is the only model dispatch source (`AC-001`).
- `analytics_version`, Project defaults, template data, caller options, and parameter presence must not influence proficiency provider dispatch (`AC-001`).
- Existing `section_id` Metrics entry points may load the Section once and delegate; callers that already have `%Section{}` should pass it directly (`AC-002`).
- A rendered consumer must use one provider path; LKT-AOA unavailable data must return unavailable or not-enough-information rather than falling back to naive (`AC-003`).
- Naive Sections retain the existing first-attempt formula, three-first-attempt threshold, bucket thresholds, and legacy return shapes (`AC-004`, `AC-005`).
- LKT-AOA direct objective reads return `learning_states.aoa` as proficiency and `learning_states.confidence` as raw confidence (`AC-006`).
- Raw confidence is a value in `0.0..1.0`; Low/Medium/High confidence bucketing is future work.
- Missing LKT-AOA state is not enough information and must remain distinct from a real `0.0` score (`AC-007`).
- Direct LKT-AOA objective reads require at least three attempts on that objective (`AC-008`).
- New provider APIs return canonical estimates; legacy Metrics adapts estimates to existing shapes (`AC-009`).
- `raw_proficiency_per_learning_objective/2` remains naive-specific or compatibility-only and must not invent an LKT-AOA tuple shape (`AC-010`).
- Parent learning-objective aggregation derives from child learning objectives and does not persist independent parent `learning_state` rows (`AC-011`).
- Page/container/course LKT-AOA scores are unweighted arithmetic means of available Section-wide learning-objective AOA scores (`AC-012`).
- Page/container/course LKT-AOA scope scores require at least three total attempts across contributing states (`AC-013`).
- Unattempted learning objectives are omitted from scope means and do not suppress otherwise eligible scope results (`AC-014`).
- A learning objective appearing on multiple pages contributes the same Section-wide state once per applicable page or ancestor container (`AC-015`).
- Instructor/class aggregates use defined learner results; not-enough-information learners are excluded from numeric averages and represented in distributions (`AC-016`).
- Objective `SectionResource.related_activities` continues to store activity resource IDs targeting that objective; page `SectionResource.related_activities` stores embedded activity resource IDs (`AC-017`).
- Page `related_activities` is populated from Section-pinned page Revision `activity_refs`, stores distinct IDs, stores `[]` for pages without activities, and ignores direct page-objective attachments (`AC-018`).
- Page/container/course membership is derived from SectionResourceDepot by intersecting page embedded activities with objective targeted activities, with deduplicated learning-objective IDs and no delivery-time Revision query (`AC-019`, `AC-026`).
- Post-processing must update or invalidate SectionResourceDepot entries whenever `related_activities` rows change (`AC-020`).
- Dashboard oracles, dashboard projections, recommendations, CSV exports, and scenario assertions must use the model-aware facade rather than reconstructing proficiency from raw ResourceSummary counts (`AC-021`, `AC-022`).
- Dashboard snapshot cache invalidation must not change in this work item (`AC-023`).
- Authoring Insights remains descriptive analytics and does not read `learning_states` or dispatch through learner proficiency providers (`AC-024`).
- Instructor/class provider queries must be set-based and must not issue one query per learner or per learning objective (`AC-025`).
- Scenario coverage must prove both naive parity and LKT-AOA reads through realistic Section workflows (`AC-027`).
- Deployment restarts clear in-memory SRD ETS tables, so the selected rollout path is JIT SectionResource migration during depot table creation.

## Phase 1: Provider Foundation and Naive Compatibility

- Goal: Establish the model-aware proficiency boundary, canonical estimate shape, and naive provider without changing observable naive behavior.
- Tasks:
  - [ ] Add `Oli.Delivery.Proficiency` as the model-aware facade.
  - [ ] Add `Oli.Delivery.Proficiency.Estimate` with fields from the FDD canonical contract (`AC-009`).
  - [ ] Add `Oli.Delivery.Proficiency.Naive` and move or wrap the current `ResourceSummary` first-attempt formula there (`AC-004`).
  - [ ] Add Section-accepting facade functions for direct objective, per-student objective, page, container, and course reads where the existing Metrics API requires them (`AC-001`, `AC-002`).
  - [ ] Keep `Oli.Delivery.Metrics` as the compatibility facade and adapt naive estimates back into current return shapes (`AC-005`).
  - [ ] Preserve `raw_proficiency_per_learning_objective/2` as a naive compatibility path only (`AC-010`).
  - [ ] Add source code comments at the facade dispatch point explaining that `Section.learning_model_version` is authoritative and caller-provided model options are intentionally unsupported (`AC-001`, `AC-003`).
  - [ ] Add source code comments around naive compatibility adapters where return shapes are preserved for legacy callers (`AC-005`).
- Testing Tasks:
  - [ ] Add unit tests for `Estimate` labeling and not-enough-information representation.
  - [ ] Add dispatch tests proving `:naive` and `:lkt_aoa` branches are selected from the loaded Section only (`AC-001`).
  - [ ] Add tests proving `analytics_version`, Project defaults, caller options, and parameter presence do not affect dispatch (`AC-001`).
  - [ ] Add Metrics parity tests for current naive objective/page/container/course return shapes (`AC-004`, `AC-005`).
  - [ ] Add a test proving `raw_proficiency_per_learning_objective/2` remains naive-shaped and is not overloaded with an incompatible LKT-AOA tuple (`AC-010`).
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/analytics/summary/metrics_v2_test.exs`
- Definition of Done:
  - `Oli.Delivery.Proficiency` and `Oli.Delivery.Proficiency.Naive` exist.
  - Naive Sections produce semantically equivalent results through the new boundary.
  - Legacy Metrics shapes remain stable for covered entry points.
  - Non-obvious dispatch and compatibility code contains useful comments.
- Gate:
  - Gate A: Provider foundation and naive parity prove `AC-001` through `AC-005`, `AC-009`, and `AC-010`.
- Dependencies:
  - Data-model work item must provide `Section.learning_model_version`.
- Parallelizable Work:
  - Estimate unit tests and naive parity inventory can proceed in parallel with facade scaffolding.

## Phase 2: LKT-AOA Direct Reads and Aggregation

- Goal: Implement LKT-AOA provider reads from `learning_states` for direct objectives, parent objectives, learner scopes, and class/instructor aggregates.
- Tasks:
  - [ ] Add `Oli.Delivery.Proficiency.LktAoa` direct objective reads from `learning_states` by Section, user, and learning-objective ID (`AC-006`).
  - [ ] Return raw `confidence` from `learning_states.confidence`; do not bucket confidence in this work (`AC-006`, `AC-009`).
  - [ ] Implement missing-state and real-zero handling so missing rows produce not-enough-information and persisted `0.0` remains displayable (`AC-007`).
  - [ ] Enforce the three-attempt direct objective threshold from `learning_state.attempt_count` (`AC-008`).
  - [ ] Implement parent learning-objective aggregation from child learning objectives without persisting parent state rows (`AC-011`).
  - [ ] Implement page/container/course aggregation support over caller-supplied or resolved learning-objective sets using unweighted arithmetic means (`AC-012`).
  - [ ] Enforce the page/container/course three-total-attempt threshold across returned states (`AC-013`).
  - [ ] Omit unattempted learning objectives from means without suppressing otherwise eligible scope results (`AC-014`).
  - [ ] Ensure repeated learning-objective membership contributes once per page/container/course scope (`AC-015`).
  - [ ] Implement instructor/class aggregate calculations from defined learner results, excluding not-enough-information learners from numeric averages while retaining distributions (`AC-016`).
  - [ ] Implement set-based `learning_states` queries for multi-learner and multi-objective requests (`AC-025`).
  - [ ] Add source code comments explaining the distinction between displayed AOA proficiency and raw confidence, and explaining why missing state is not converted to zero (`AC-006`, `AC-007`).
  - [ ] Add source code comments on class aggregate query boundaries where set-based reads prevent learner/objective query loops (`AC-025`).
- Testing Tasks:
  - [ ] Add LKT-AOA direct objective tests for numeric AOA, raw confidence, counts, and provenance (`AC-006`, `AC-009`).
  - [ ] Add missing-state vs `0.0` score tests (`AC-007`).
  - [ ] Add direct objective threshold tests (`AC-008`).
  - [ ] Add parent objective aggregation tests (`AC-011`).
  - [ ] Add page/container/course aggregation tests for unweighted means, three-attempt threshold, unattempted objective omission, and repeated objective membership (`AC-012`, `AC-013`, `AC-014`, `AC-015`).
  - [ ] Add instructor/class aggregate tests for numeric averages and not-enough-information distributions (`AC-016`).
  - [ ] Add query-count or telemetry-style tests proving set-based reads for larger learner/objective sets (`AC-025`).
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/learning_model`
- Definition of Done:
  - LKT-AOA provider returns canonical estimates from `learning_states`.
  - Direct objective, parent objective, scope, and class aggregate policies are implemented.
  - No LKT-AOA read scans historical attempts.
  - Non-obvious AOA/confidence, missing-state, and set-based-query rules are documented in comments.
- Gate:
  - Gate B: LKT-AOA read behavior proves `AC-006` through `AC-016` and `AC-025`.
- Dependencies:
  - Phase 1 facade and `Estimate` contract.
  - Core implementation work item must provide `learning_states`.
- Parallelizable Work:
  - Direct objective tests and aggregate policy tests can be written in parallel once the provider contract is available.

## Phase 3: SRD Scope Membership and JIT SectionResource Migration

- Goal: Populate and consume page `SectionResource.related_activities` so page/container/course learning-objective membership resolves from SectionResourceDepot without delivery-time Revision queries.
- Tasks:
  - [ ] Update `Oli.Delivery.Sections.SectionResource` comments/docs so `related_activities` documents both objective and page semantics (`AC-017`).
  - [ ] Extend `Oli.Delivery.Sections.PostProcessing` `:related_activities` to populate objective and page rows in bulk (`AC-017`, `AC-018`).
  - [ ] For page rows, copy distinct Section-pinned page Revision `activity_refs` and ignore direct page-objective attachments (`AC-018`).
  - [ ] Extend `Oli.Delivery.Sections.SectionResourceMigration.requires_migration?/1` to detect missing page `related_activities` projection (`AC-018`, `AC-020`).
  - [ ] Extend `Oli.Delivery.Sections.SectionResourceMigration.migrate/1` so JIT depot table creation backfills page `related_activities` before `SectionResourceDepot.load/1` (`AC-018`, `AC-020`).
  - [ ] Preserve existing SectionResource field migration behavior while adding the page activity projection (`AC-020`).
  - [ ] Add `Oli.Delivery.Proficiency.Scope` to resolve page/container/course learning-objective membership from SRD rows by intersecting page embedded activities with objective targeted activities (`AC-019`).
  - [ ] Build the in-memory `activity_id -> learning_objective_ids` index once per scope resolution call and deduplicate learning-objective IDs (`AC-019`, `AC-026`).
  - [ ] Ensure post-processing updates or invalidates distributed SectionResourceDepot entries when it changes `related_activities` for an already-loaded Section (`AC-020`).
  - [ ] Add source code comments in migration and scope resolver code explaining the JIT depot migration sequence and why direct page objectives are ignored (`AC-018`, `AC-019`, `AC-026`).
- Testing Tasks:
  - [ ] Add post-processing tests proving objective `related_activities` retains current behavior and page `related_activities` stores embedded activity IDs (`AC-017`, `AC-018`).
  - [ ] Add tests for pages with no embedded activities storing `[]` (`AC-018`).
  - [ ] Add tests proving direct page-objective attachments do not affect page proficiency membership (`AC-018`, `AC-019`).
  - [ ] Add SectionResourceDepot JIT migration tests proving `process_table_creation/1` migrates page `related_activities` before loading ETS (`AC-020`).
  - [ ] Add SRD scope resolver tests for page, container, and course membership with deduplicated learning-objective IDs (`AC-019`, `AC-026`).
  - [ ] Add tests proving scope resolution performs no delivery-time Revision query after SRD load (`AC-026`).
  - Command(s): `mix test test/oli/delivery/sections test/oli/delivery/proficiency`
- Definition of Done:
  - Objective and page `related_activities` semantics are both implemented and documented.
  - Existing Sections are handled through JIT migration on depot table creation after server restart.
  - Scope membership is resolved from SRD rows without Revision queries.
  - Non-obvious migration and membership rules are documented in comments.
- Gate:
  - Gate C: SRD membership and JIT migration prove `AC-017` through `AC-020` and `AC-026`.
- Dependencies:
  - Phase 1 facade for provider integration.
  - Existing SectionResourceDepot and SectionResourceMigration behavior.
- Parallelizable Work:
  - SectionResource post-processing tests and scope resolver tests can proceed in parallel.

## Phase 4: Metrics, Dashboard, and Scenario Consumer Migration

- Goal: Move direct proficiency consumers to the model-aware facade while keeping presentation contracts stable and avoiding dashboard snapshot cache invalidation changes.
- Tasks:
  - [ ] Update Metrics functions to delegate to `Oli.Delivery.Proficiency` and adapt canonical estimates to existing shapes (`AC-002`, `AC-005`, `AC-021`).
  - [ ] Update callers that already have `%Section{}` to use Section-accepting overloads rather than section-id-only paths (`AC-002`).
  - [ ] Update `Oli.InstructorDashboard.Oracles.ObjectivesProficiency` to pass Section/model-aware inputs through Metrics or the facade (`AC-021`).
  - [ ] Update `Oli.InstructorDashboard.Oracles.ProgressProficiency` to stop reconstructing proficiency from `ResourceSummary` and delegate to the model-aware boundary (`AC-021`).
  - [ ] Update dashboard projections, student support, challenging objectives, summaries, CSV exports, and recommendations where they currently reconstruct numeric proficiency from labels (`AC-021`, `AC-022`).
  - [ ] Preserve current dashboard snapshot cache invalidation, cache keys, and rebuild policy unless an oracle payload contract change requires an explicitly scoped oracle version change (`AC-023`).
  - [ ] Update `Oli.Scenarios.Directives.Assert.ProficiencyAssertion` to consume provider/facade results rather than raw naive counts (`AC-021`, `AC-027`).
  - [ ] Add a guard or regression coverage showing Authoring Insights remains descriptive and does not read `learning_states` or provider-dispatch learner proficiency (`AC-024`).
  - [ ] Add source code comments only where adapters preserve legacy shape or intentionally keep dashboard cache invalidation unchanged (`AC-005`, `AC-023`).
- Testing Tasks:
  - [ ] Add Metrics compatibility tests for migrated functions (`AC-002`, `AC-005`).
  - [ ] Add dashboard oracle tests for both `:naive` and `:lkt_aoa` Sections (`AC-021`, `AC-022`).
  - [ ] Add tests proving numeric LKT-AOA aggregates are used directly rather than reconstructed from Low/Medium/High labels (`AC-022`).
  - [ ] Add tests or documented hybrid verification proving snapshot cache invalidation behavior is unchanged (`AC-023`).
  - [ ] Add Authoring Insights regression tests proving it remains on descriptive `ResourceSummary` analytics (`AC-024`).
  - [ ] Add scenario assertion tests for naive parity and LKT-AOA reads (`AC-027`).
  - Command(s): `mix test test/oli/analytics/summary/metrics_v2_test.exs test/oli/instructor_dashboard test/oli/scenarios`
- Definition of Done:
  - Direct naive formula duplication is removed from dashboard oracles and scenario assertions, except for intentionally retained descriptive analytics.
  - Dashboard numeric LKT-AOA aggregates flow through payloads without label reconstruction.
  - Dashboard snapshot cache invalidation is unchanged.
  - Legacy UI and Metrics shapes remain compatible.
  - Comments document non-obvious compatibility adapters and cache non-changes.
- Gate:
  - Gate D: Consumer migration proves `AC-002`, `AC-005`, and `AC-021` through `AC-024`, plus scenario progress toward `AC-027`.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Dashboard oracle migration and scenario assertion migration can proceed in parallel once the facade API is stable.

## Phase 5: End-to-End Verification, Performance Proof, and Traceability

- Goal: Complete integration proof across naive and LKT-AOA Sections, reconcile requirements, and prepare the work item for review.
- Tasks:
  - [ ] Add or update realistic workflow coverage proving naive parity and LKT-AOA proficiency reads through Section workflows (`AC-027`).
  - [ ] Add performance-focused tests proving provider queries remain set-based and page/container/course membership uses SRD without delivery-time Revision queries (`AC-025`, `AC-026`).
  - [ ] Validate that no implementation changed LKT-AOA write behavior, Project/Section defaults, confidence bucketing, Authoring Insights semantics, xAPI/ClickHouse analytics, or dashboard snapshot cache invalidation.
  - [ ] Update `requirements.yml` proof paths after implementation.
  - [ ] Create phase execution records as required by the harness develop flow.
  - [ ] Run relevant formatting and focused test suites.
  - [ ] Run security, performance, Elixir, and requirements reviews because this work changes backend read behavior and PRD traceability.
  - [ ] Check source code comments added in prior phases for usefulness and remove comments that merely repeat obvious code.
- Testing Tasks:
  - [ ] Run focused provider, Metrics, SRD, dashboard, and scenario tests.
  - [ ] Run markdown/requirements validation.
  - [ ] Run `git diff --check`.
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/analytics/summary/metrics_v2_test.exs test/oli/delivery/sections test/oli/instructor_dashboard test/oli/scenarios`
  - Command(s): `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/learning_model_v2/usage --action master_validate --stage implementation_complete`
  - Command(s): `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/usage --check all`
  - Command(s): `git diff --check`
- Definition of Done:
  - All usage requirements and acceptance criteria have implementation and test proof.
  - Performance tests prove no per-learner/per-objective query loops and no delivery-time Revision membership query.
  - Scenario coverage proves both naive and LKT-AOA behavior.
  - Review findings are resolved or explicitly deferred with user approval.
  - Source comments are targeted, useful, and aligned with the implemented design.
- Gate:
  - Gate E: Final validation proves `FR-001` through `FR-009` and `AC-001` through `AC-027`; review lenses are clean; no out-of-scope cache invalidation or confidence bucketing changes are present.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Requirements reconciliation, review preparation, and broad test runs can proceed after Phase 4 behavior is complete.

## Parallelization Notes

- Phase 1 should complete before provider consumers migrate, because it establishes the stable facade and estimate contract.
- Phase 2 direct LKT-AOA reads and Phase 3 SRD membership can be developed in parallel after Phase 1 if the scope resolver interface is agreed.
- Phase 4 dashboard and scenario migration can be split by consumer area once provider contracts are stable.
- Performance tests should be added near the feature code they protect, not deferred exclusively to Phase 5.
- Source code comments should be reviewed in each phase to keep them close to the domain rules they explain.

## Phase Gate Summary

- Gate A: Provider foundation and naive compatibility are complete.
- Gate B: LKT-AOA direct reads and aggregation are complete.
- Gate C: SRD-backed page/container/course membership and JIT SectionResource migration are complete.
- Gate D: Metrics, dashboard, Authoring Insights boundary, and scenario consumers are migrated.
- Gate E: End-to-end tests, performance proof, traceability, formatting, validation, and reviews are complete.
