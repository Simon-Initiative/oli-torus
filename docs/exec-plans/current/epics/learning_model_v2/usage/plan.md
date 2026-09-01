# Learning Model: Proficiency Reads and Usage - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/learning_model_v2/usage/prd.md`
- FDD: `docs/exec-plans/current/epics/learning_model_v2/usage/fdd.md`
- Requirements: `docs/exec-plans/current/epics/learning_model_v2/usage/requirements.yml`
- Informal technical notes: `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`
- Jira: [MER-5846](https://eliterate.atlassian.net/browse/MER-5846)

## Scope

Deliver model-aware proficiency reads selected exclusively by the persisted Section model. Extract naive behavior from `Oli.Delivery.Metrics` without changing existing results; add canonical estimate/aggregate contracts and an LKT-AOA provider over materialized `learning_states`; project Section-pinned page activity membership into `SectionResource.related_activities`; upgrade legacy SectionResources through deterministic depot-driven JIT migration; resolve page/container/course membership entirely from the initialized depot; migrate learner, instructor, dashboard, export, and scenario consumers; and add bounded telemetry and regression coverage.

Guardrails:

- Do not change Authoring Insights or its descriptive `ResourceSummary` calculations.
- Do not train model parameters, persist derived aggregates, add a contained-page-objective table, expose a model override, or add confidence/coverage UI.
- Do not run a deployment-wide SectionResource backfill. Legacy rows migrate per Section on first depot initialization.
- Do not fall back to naive when an LKT-AOA dependency is unavailable.
- Preserve publication pinning, Section tenancy, authorization, and current naive output contracts.
- Use useful source-code comments and module/function documentation for non-obvious invariants: model-specific threshold differences, missing-versus-zero semantics, parent attempt-count weighting, scope deduplication, JIT migration locking/version advancement, database/depot ordering, and intentionally naive-only compatibility functions. Avoid comments that merely restate the code.

## Clarifications & Default Assumptions

- Parent proficiency is weighted by each effective child's `attempt_count`.
- Parent display eligibility depends on at least three total attempts across all effective children; no per-child minimum applies.
- Direct LKT-AOA objectives require three attempts on that objective.
- Page/container/course learner scopes require three total attempts across their distinct available objective states and use an unweighted arithmetic mean of available AOA values.
- `sections.section_resource_migration_version` is a non-null integer controlled only by `SectionResourceMigration`. Version `0` means migration is required; the implementation defines a positive current version.
- `SectionResourceDepot.process_table_creation/1` must complete `SectionResourceMigration.ensure_current/1` before loading ETS records.
- Application restart during rollout clears old in-memory dashboard/depot cache state. Section model migration handling remains out of scope.
- `get_objectives_and_subobjectives/2` retains its current label/distribution contract unless a concrete current consumer requires another field.
- Confidence and coverage remain canonical backend signals where already required by contracts, but no new presentation work is included.
- Existing Section model and LKT-AOA state work in `data_model` and `core_impl` is complete and remains the source of truth.

## Phase 1: Characterize Naive Contracts and Establish Canonical Boundaries

- Goal: Lock down existing behavior before extracting it, then introduce model-neutral types and dispatch without changing consumers.
- Tasks:
  - [x] Inventory all proficiency functions in `Oli.Delivery.Metrics`, their call sites, return shapes, ordering expectations, and direct formula duplicates; explicitly classify Authoring Insights as out of scope. (FR-003, FR-009; AC-008, AC-009, AC-027)
  - [x] Add characterization tests for naive formula results, the three-first-attempt gate, exact `0.4`/`0.8` boundaries, missing data, ordering, and every legacy tuple/map/string/student-row shape. (FR-003; AC-007, AC-008)
  - [x] Implement `Oli.Delivery.Proficiency.Estimate` and `Aggregate` with types, validation/construction helpers, atom labels, `nil` versus `0.0` semantics, evidence fields, and model provenance. (FR-002; AC-004, AC-005, AC-006)
  - [x] Implement the `Oli.Delivery.Proficiency` facade with `%Section{}`-first bulk APIs and dispatch solely on `learning_model_version`; reject unsupported versions and caller model overrides. This establishes the error contract used later, while missing-state/projection behavior remains in Phase 4. (FR-001; AC-001, AC-002)
  - [x] Add temporary integer-ID compatibility clauses only where existing APIs require them, ensuring each loads the Section once and delegates.
  - [x] Author useful module and function documentation explaining the canonical contract, provider ownership, missing-versus-zero rule, and why dispatch never uses `analytics_version` or presentation-layer options.
- Testing Tasks:
  - [x] Run new canonical type/facade unit tests and the existing Metrics proficiency suite before extraction.
  - [x] Add negative tests for unsupported models, independent model options, and `analytics_version` changes.
  - Command(s): `mix test test/oli/analytics/summary/metrics_v2_test.exs test/oli/delivery/metrics/proficiency_contract_test.exs test/oli/delivery/proficiency_test.exs test/oli/delivery/proficiency_integration_test.exs test/oli/delivery/proficiency`
  - Command(s): `mix format --check-formatted`
- Definition of Done:
  - Current naive contracts are executable specifications; canonical values distinguish absent evidence from zero; dispatch is Section-owned and no production caller has changed behavior.
  - Non-obvious public contracts and invariants have useful source comments/docs.
- Gate:
  - Gate A: AC-001, AC-002, AC-004, AC-005, and AC-006 pass; existing integration tests plus the focused boundary suite establish the pre-extraction naive baseline for AC-007, AC-008, and AC-009. Provider primitives for AC-007 and AC-009 close in Gate B, while full heterogeneous adapter parity for AC-008 closes with consumer migration in Gate E. AC-003 closes in Gate D when missing LKT state and scope projections exist to exercise.
- Dependencies:
  - Completed `data_model` model-selection work; no dependency on later phases.
- Parallelizable Work:
  - Canonical struct/type implementation can proceed alongside naive characterization after the call-site inventory fixes the required shapes.

## Phase 2: Extract the Naive Provider and Implement LKT-AOA Objective Reads

- Goal: Put all model-specific objective queries, evidence rules, and bucketing behind providers while preserving naive compatibility.
- Tasks:
  - [x] Move the shared naive objective `ResourceSummary` tuple query and bucketing primitives into `Oli.Delivery.Proficiency.Naive`; preserve the first-attempt formula and `<= 0.4`, `<= 0.8` bucket rules exactly. Production Metrics consumer queries and heterogeneous shape adapters remain in Phase 5 so this phase does not change callers. (FR-003; AC-007, AC-009)
  - [x] Keep `raw_proficiency_per_learning_objective/2` explicitly naive-only or deprecate it; document why its tuple shape cannot represent LKT-AOA. (FR-003; AC-009)
  - [x] Implement set-based `Oli.Delivery.Proficiency.LktAoa` direct-objective reads from `learning_states` by Section, learner IDs, and objective IDs with no attempt-history or ResourceSummary access. (FR-004, FR-008; AC-010, AC-024)
  - [x] Apply direct eligibility and LKT-AOA buckets: below three attempts is not-enough-information; Low is `< 0.4`, Medium is `0.4..0.8`, High is `> 0.8`. (FR-004; AC-011)
  - [x] Implement parent rollup from effective child SectionResources using `sum(aoa * attempt_count) / sum(attempt_count)` and the three-total-child-attempt gate; never persist or prefer a parent state row. (FR-004; AC-012)
  - [x] Preserve confidence and evidence fields independently from score/label without adding UI behavior. (FR-002; AC-006)
  - [x] Add bounded provider telemetry for model, operation, duration, requested/returned counts, defined/unavailable counts, and outcome without identifiers. (FR-011; AC-032)
  - [x] Add useful source comments around the intentional 0.4 boundary difference, direct versus parent evidence gates, attempt-count weighting, and why parent rows are derived rather than persisted.
- Testing Tasks:
  - [x] Prove naive facade output remains byte-for-byte or semantically equivalent after extraction.
  - [x] Cover missing LKT state versus a valid zero AOA, direct threshold boundaries, a child below three that does not suppress an eligible parent, total-child attempts below three, and parent weighting.
  - [x] Capture Ecto query telemetry to prove LKT reads do not touch attempt/summary tables and query count does not grow once per learner/objective.
  - [x] Verify telemetry metadata is bounded and contains no learner/objective/attempt identifiers.
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/analytics/summary/metrics_v2_test.exs`
  - Command(s): `mix format --check-formatted`
- Definition of Done:
  - Both providers return canonical contracts; Metrics naive outputs remain stable; LKT direct/parent results follow approved math and use only materialized state.
  - Provider math and compatibility constraints have precise, durable source comments/docs.
- Gate:
  - Gate B: AC-006, AC-007, AC-009 through AC-012, AC-024, and AC-032 pass with query-bound evidence. Existing characterization tests preserve the AC-008 compatibility baseline; explicit canonical adapters for every heterogeneous Metrics shape close with the Phase 5 consumer migration.
- Dependencies:
  - Gate A; completed `core_impl` materialized-state writer.
- Parallelizable Work:
  - Naive extraction and LKT direct-query implementation can proceed concurrently after canonical interfaces merge; parent rollup follows effective-child contract availability.

## Phase 3: Add Versioned JIT SectionResource Migration and Page Projections

- Goal: Make page/objective activity relationships deterministic, Section-pinned, and available before depot reads without a fleet-wide backfill.
- Tasks:
  - [x] Add a safe Ecto migration for non-null integer `sections.section_resource_migration_version` with default `0`; do not backfill SectionResources in the schema migration. (FR-005; AC-036)
  - [x] Add the schema field without exposing it through ordinary/user-controlled Section changesets.
  - [x] Refactor related-activities projection into a reusable bulk operation shared by normal post-processing and JIT migration. Preserve objective reversal and add page `Revision.activity_refs`, distinct IDs, valid empty arrays, and no direct page-objective attachments. (FR-005; AC-013, AC-014, AC-016)
  - [x] Replace interpolated CASE SQL with parameterized Ecto/SQL and make projection errors observable rather than swallowed.
  - [x] Implement `SectionResourceMigration.current_version/0` and ordered migration steps, adding `ensure_current/1` with a Section-row `FOR UPDATE` lock, in-transaction version recheck, projection writes, and marker advancement only after all steps succeed. (FR-005; AC-015, AC-036)
  - [x] Update `SectionResourceDepot.process_table_creation/1` to call `ensure_current/1` and load ETS only after success; propagate failure without leaving a populated table.
  - [x] Update normal Section/template creation, publication update, duplication/remix, and repair paths to project current data, advance the version when appropriate, and update or clear distributed depot entries. (FR-005; AC-015)
  - [x] Update `SectionResource` and migration module documentation with type-specific `related_activities` semantics, version ownership, retry behavior, and database-before-depot ordering.
  - [x] Add useful source comments explaining why `[]` cannot indicate readiness, why version advancement shares the projection transaction, why the row is locked/rechecked, and why depot loading follows commit.
- Testing Tasks:
  - [x] Test objective/page projections from exact Section-pinned Revisions, deduplication, empty pages, and exclusion of page-level objective attachments.
  - [x] Test version `0` first-access migration, current-version no-op, ordered future-version behavior, rollback without marker advancement, retry, and new-Section marking/fallback.
  - [x] Test concurrent `ensure_current/1` calls to prove serialization and a single effective migration.
  - [x] Test depot initialization failure and database/depot coherence for singleton and distributed coordinators where supported.
  - [x] Test each relevant Section lifecycle call path invokes projection/version handling.
  - Command(s): `mix test test/oli/delivery/sections/section_resource_migration_test.exs test/oli/delivery/sections/section_resource_depot_test.exs test/oli/delivery/sections/post_processing_test.exs`
  - Command(s): `mix test test/oli/delivery/sections_test.exs test/oli/delivery/sections/blueprint_test.exs`
  - Command(s): `mix format --check-formatted`
- Definition of Done:
  - A legacy Section is upgraded once, just in time and transactionally before depot load; a valid empty page is distinguishable through the Section version; all normal mutation paths maintain database/depot coherence.
  - Migration and consistency invariants are documented in source where future maintainers will encounter them.
- Gate:
  - Gate C: AC-013 through AC-016 and AC-036 pass, including concurrency, rollback, retry, and distributed-depot evidence.
- Dependencies:
  - Gate A for shared contract terminology; can otherwise proceed independently of Phase 2 provider internals.
- Parallelizable Work:
  - Schema/version work, projection query refactor, and lifecycle call-site inventory can proceed concurrently; transaction integration waits for those pieces.

## Phase 4: Implement SRD-Only Scope Membership and Aggregation

- Goal: Calculate learner and class page/container/course proficiency from depot relationships and set-based learning-state reads.
- Tasks:
  - [ ] Implement `Oli.Delivery.Proficiency.ScopeMembership` over initialized page/container/objective SectionResources, building one activity-to-objective index and deduplicated page objective sets. (FR-006; AC-017)
  - [ ] Derive container and course sets from descendant page SectionResources and the depot hierarchy; never use `ContainedObjective` as authority or query Revisions at delivery time. (FR-006; AC-018, AC-019)
  - [ ] Implement one set-based learning-state read for all requested learner/objective identities and compute each learner scope using total attempt eligibility plus an unweighted mean of distinct available AOA values. (FR-007; AC-020, AC-021, AC-022)
  - [ ] Implement class aggregation as the unweighted mean of defined learner results, retaining unavailable learners in distributions and reporting contributing/total counts. (FR-008; AC-023)
  - [ ] Return explicit unavailable errors for failed JIT/depot infrastructure and never switch providers or broaden membership.
  - [ ] Add useful source comments for the activity-set intersection, direct-page-objective exclusion, distinct-LO rule, Section-wide state reuse across pages, unweighted scope math, and defined-learner class denominator.
- Testing Tasks:
  - [ ] Cover duplicate activities/LOs, one LO on multiple pages, descendant-container unions, course root scope, direct page objectives excluded, and a page with no activities.
  - [ ] Cover fewer than three total attempts, missing LO state omitted, unattempted LO not suppressing an eligible scope, equal LO weighting, and equal learner weighting.
  - [ ] Prove scope membership performs no database query after depot initialization and bulk state query counts stay bounded as learners/objectives grow.
  - [ ] Cover JIT migration failure/unavailable behavior and absence of naive fallback.
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/delivery/sections/section_resource_depot_test.exs`
  - Command(s): `mix format --check-formatted`
- Definition of Done:
  - Page/container/course membership and proficiency satisfy the approved math using only SRD membership plus bulk model-state reads; query counts and unavailable behavior are proven.
  - The non-obvious membership and aggregation rules are explained by useful source comments/docs.
- Gate:
  - Gate D: AC-003, AC-017 through AC-024, and relevant AC-032 query/telemetry checks pass.
- Dependencies:
  - Gates B and C.
- Parallelizable Work:
  - Pure membership derivation and aggregate math/tests can proceed concurrently against fixtures/structs; provider integration follows both.

## Phase 5: Migrate Learner, Instructor, Oracle, Snapshot, and Export Consumers

- Goal: Route all real proficiency consumers through the selected provider while preserving presentation contracts and delivering actual numeric LKT-AOA aggregates.
- Tasks:
  - [ ] Migrate student lesson, prologue, review, dashboard page/container, and learning-objective page-element calls to Section-aware facade APIs without UI model branching. (FR-009; AC-025)
  - [ ] Migrate classic instructor dashboard helpers, expanded objective views, individual-student distributions, and `Sections.get_objectives_and_subobjectives/2`; keep the latter's current label/distribution shape unless a concrete caller requires more. (FR-009; AC-026)
  - [ ] Replace `ProgressProficiency`'s direct ResourceSummary formula with model-aware bulk scope reads while retaining its progress calculation. (FR-009; AC-027)
  - [ ] Update `ObjectivesProficiency` to pass the loaded Section and consume model-aware objective results without using `ContainedObjective` as LKT-AOA membership authority. (FR-009; AC-026)
  - [ ] Add actual numeric LKT-AOA aggregates required by current oracle payloads, increment affected oracle versions, and keep confidence/coverage presentation out of scope. (FR-010; AC-028)
  - [ ] Update dashboard summary projectors, cards, CSV serializers, student-support/challenging-objective/recommendation paths to use actual LKT-AOA numeric values rather than category reconstruction; retain naive compatibility. (FR-010; AC-029)
  - [ ] Remove every remaining direct naive formula outside `Proficiency.Naive`, except documented descriptive Authoring Insights calculations. (FR-009; AC-027)
  - [ ] Add useful source comments at compatibility seams explaining why legacy shapes remain, why LKT-AOA uses actual numeric oracle fields, and why Authoring Insights is intentionally excluded; do not add comments to straightforward rendering code.
- Testing Tasks:
  - [ ] Add/adjust targeted LiveView/component tests for existing visible label/empty-state behavior under naive and model-aware data under LKT-AOA.
  - [ ] Test oracle payload schemas/versions, cache-key version misses, actual numeric propagation through snapshots/projectors/CSV, and naive category-derived compatibility.
  - [ ] Use repository searches in the test/gate script to prove direct proficiency formulas and model dispatch are absent from consumers.
  - [ ] Verify existing authorization and Section scope tests remain green; no confidence/coverage UI appears.
  - Command(s): `mix test test/oli/instructor_dashboard test/oli_web/live/delivery test/oli/delivery/learning_objectives`
  - Command(s): `mix test test/oli/analytics/summary/metrics_v2_test.exs`
  - Command(s): `rg -n "num_first_attempts_correct|proficiency_range|learning_model_version" lib/oli/instructor_dashboard lib/oli_web lib/oli/scenarios`
  - Command(s): `mix format --check-formatted`
- Definition of Done:
  - All inventoried learner/instructor/dashboard/export consumers receive one Section-selected model result; LKT-AOA numeric values survive downstream projection without label approximation; naive UI/contracts remain stable.
  - Compatibility and exclusion decisions have useful, focused source documentation.
- Gate:
  - Gate E: AC-025 through AC-031 pass, direct formula inventory is clean, and targeted delivery/dashboard regressions pass.
- Dependencies:
  - Gate D; oracle/cache versioning depends on finalized aggregate payloads.
- Parallelizable Work:
  - Student consumer migration, classic instructor migration, and oracle/downstream projection updates can proceed in parallel after the facade contracts stabilize, with final integration tests serialized.

## Phase 6: Scenario Coverage, Operational Verification, and Release Gate

- Goal: Prove complete workflows for both models and finish production-readiness checks without expanding UI scope.
- Tasks:
  - [ ] Refactor `ProficiencyAssertion` to consume canonical direct/class estimates; remove raw naive tuple access and formula reconstruction. (FR-009, FR-012; AC-027, AC-035)
  - [ ] Use the `build_scenario` skill to author focused naive and LKT-AOA scenarios spanning authoring, publication, Section creation, enrollment, evaluated attempts, JIT depot initialization, and proficiency assertions. (FR-012; AC-035)
  - [ ] If current scenario directives cannot create/observe required model state or migration behavior, use `extend_scenario` only for the minimal reusable capability before returning to scenario authoring.
  - [ ] Consolidate query-bound, projection/depot, oracle-version, numeric-export, and telemetry tests into a documented targeted verification set. (FR-012; AC-033, AC-034)
  - [ ] Verify the rollout runbook requires an application restart, explicitly rejects a full SectionResource backfill, and documents JIT retry/failure observation through AppSignal. (FR-011; AC-030, AC-031, AC-032)
  - [ ] Audit all newly introduced or substantially changed modules for useful comments/docs on non-obvious domain math, migration/locking, compatibility, cache, and failure invariants; remove redundant narration comments.
  - [ ] Run required security, performance, Elixir, and requirements reviews and resolve blocking findings.
- Testing Tasks:
  - [ ] Validate each scenario YAML file with `Oli.Scenarios.validate_file/1`, then run its companion ExUnit runner.
  - [ ] Run the consolidated proficiency, SectionResource, delivery consumer, instructor-dashboard, and scenario suites.
  - [ ] Run formatting, compilation with warnings-as-errors where supported, diff hygiene, and requirements validation.
  - [ ] Manually compare representative naive learner/instructor results, inspect LKT-AOA numeric dashboard/CSV output, exercise first depot access for a legacy-version Section, and confirm telemetry contains no sensitive identifiers.
  - Command(s): `mix run -e 'path = "test/scenarios/learning_model/proficiency_usage.scenario.yaml"; case Oli.Scenarios.validate_file(path) do :ok -> IO.puts("schema ok"); {:error, errors} -> IO.inspect(errors, label: "schema_errors"); System.halt(1) end'`
  - Command(s): `mix test test/scenarios/learning_model/proficiency_usage_test.exs`
  - Command(s): `mix test test/oli/delivery/proficiency test/oli/delivery/sections test/oli/instructor_dashboard test/oli_web/live/delivery`
  - Command(s): `mix format --check-formatted`
  - Command(s): `mix compile --warnings-as-errors`
  - Command(s): `git diff --check`
- Definition of Done:
  - Both-model scenarios, targeted regression suites, query/depot/cache/telemetry evidence, rollout checks, and required reviews pass with no unresolved blocking finding.
  - Source comments/docs explain the design's durable non-obvious decisions and do not merely paraphrase implementation.
- Gate:
  - Gate F: AC-030 through AC-036 pass in the consolidated verification record; the work item meets its PRD/FDD definition of done and is ready for release review.
- Dependencies:
  - Gates A through E; `build_scenario` begins after stable provider and assertion contracts.
- Parallelizable Work:
  - Scenario drafting, operational verification documentation, and review preparation can proceed concurrently after Gate E; final runs and finding resolution are serialized.

## Parallelization Notes

- Phase 3 can proceed alongside most of Phase 2 after Phase 1 contracts settle because JIT projection work and provider math touch separate boundaries.
- Within Phase 2, naive extraction and LKT direct reads can proceed concurrently; parent aggregation follows the common provider contract.
- Within Phase 3, migration schema/version work, projection refactoring, and lifecycle inventory can proceed concurrently before transaction/depot integration.
- Within Phase 4, pure membership and pure aggregation implementations can proceed concurrently, then converge on bulk state reads.
- Within Phase 5, learner, classic instructor, and intelligent-dashboard consumer groups can be migrated concurrently against stable APIs.
- Avoid concurrent edits to `lib/oli/delivery/metrics.ex`, `lib/oli/delivery/sections/post_processing.ex`, and `requirements.yml`; assign one owner or sequence changes to prevent conflict.
- Each parallel branch owns its focused tests and useful source comments; integration owners reconcile terminology and remove duplicated commentary before phase gates.

## Phase Gate Summary

- Gate A — Contract baseline: canonical types/dispatch pass (AC-001, AC-002, AC-004, AC-005, AC-006), and the existing Metrics integration suite plus focused threshold/raw-API tests establish the pre-extraction baseline for AC-007 through AC-009; AC-003 is deferred to Gate D.
- Gate B — Providers: shared naive objective primitives and LKT direct/parent reads pass correctness, privacy, telemetry, and query-bound tests (AC-006, AC-007, AC-009–AC-012, AC-024, AC-032); AC-008 adapter closure follows in Gate E.
- Gate C — JIT projections: versioned transactional migration, page/objective projection, lifecycle integration, and depot coherence pass (AC-013–AC-016, AC-036).
- Gate D — Scope aggregation: SRD-only membership and learner/class aggregation pass correctness and scaling checks (AC-003, AC-017–AC-024, AC-032).
- Gate E — Consumers: learner/instructor/oracle/snapshot/export integrations pass naive compatibility and actual-numeric LKT-AOA checks (AC-025–AC-031).
- Gate F — Release: scenarios, observability, rollout, reviews, formatting, and consolidated verification pass (AC-030–AC-036).
