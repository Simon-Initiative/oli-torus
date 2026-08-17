# Weighted Random Assignment Scope - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope/requirements.yml`

## Scope

Implement a weighted-random-only assignment-scope configuration with `intervention` as the preserved behavior for existing experiments and `section_enrollment` as the default for new weighted-random experiments and one durable condition assignment per experiment, participating section, and enrollment. The work includes PostgreSQL constraints and reversible migration behavior, public experiment contracts, lifecycle validation, single and batched delivery assignment, intervention-specific exposure evidence, xAPI/ClickHouse compatibility, authoring and details LiveViews, telemetry, scenario coverage, documentation reconciliation, and required review/verification.

Guardrails:

- Thompson Sampling remains intervention-scoped and must reject section-and-enrollment configuration at every domain boundary.
- Assignment creation and reuse remain inside `Oli.Experiments`; LiveViews and delivery strategies do not implement identity rules.
- PostgreSQL remains the runtime source of truth. Assignment paths never query xAPI, ClickHouse, reward history, or event history.
- Existing experiment and assignment rows retain intervention-scoped behavior and existing assignment keys; no assignment consolidation or content migration is performed.
- Assignment and exposure remain distinct: canonical assignments may omit intervention ownership, but every exposure identifies and validates the encountered intervention.
- Section participation, project/tenant authorization, experiment condition mapping, publication pinning, and deterministic fallback semantics remain unchanged.
- No feature flag is introduced.
- Jira writes are outside this plan unless the user separately approves an exact proposed Jira change.

## Clarifications & Default Assumptions

- `assignment_scope` is a new concept rather than a reinterpretation of `assignment_unit`; the assignment unit remains enrollment in both modes.
- Assignment scope is structural: it may be changed only while an experiment remains in draft.
- Experiment definitions and assignment rows both store scope. The assignment value is an immutable snapshot used by row constraints, indexed lookup, telemetry, and evidence.
- Intervention-scoped assignment keys keep their current format. New section-and-enrollment keys use an explicit versioned format containing experiment, section, and enrollment.
- Exposure requests add server-derived page resource and content-element identity. Their idempotency keys include placement identity so two interventions sharing one assignment cannot collide.
- The page-batch reducer carries a transaction-local assignment map keyed by canonical identity; database uniqueness remains authoritative for cross-request and cross-node races.
- Existing analytics evidence without `assignment_scope` is interpreted as intervention-scoped when a default is required.
- The migration `down/0` path must not fabricate intervention ownership. Before implementation closes, migration tests and deployment posture will select and document a safe rollback precondition or an explicitly permitted pre-release cleanup behavior.
- Final UI control choice and copy may use established LiveView form primitives without a new Figma artifact, provided the two PRD choices, scope boundary, and accessibility requirements remain intact.

## Phase 1: Persisted Scope And Domain Configuration Contract

- Goal: Establish typed assignment-scope storage, database integrity, public request/response contracts, and lifecycle validation for FR-001, FR-002, FR-008, FR-013, AC-001, AC-002, AC-008, and AC-013.
- Tasks:
  - [x] Generate the Ecto migration with `mix ecto.gen.migration add_weighted_random_assignment_scope`; do not invent a timestamp or filename.
  - [x] Implement explicit `up/0` and `down/0` for definition and assignment scope columns, definition enum constraint, nullable assignment intervention ownership, assignment row-shape constraint, and the two partial sticky unique indexes.
  - [x] Preserve existing rows through non-null `intervention` defaults without rewriting existing assignment keys or consolidating rows.
  - [x] Decide and document the safe rollback precondition or allowed pre-release cleanup behavior for existing `section_enrollment` assignments; ensure `down/0` fails safely rather than fabricating intervention IDs.
  - [x] Extend `Schemas.ExperimentDefinition`, `Schemas.Assignment`, public `ExperimentDefinition`, `CreateExperimentRequest`, and `UpdateExperimentRequest` with typed scope fields and public API documentation.
  - [x] Add assignment changeset validation and named constraint mappings for both partial unique indexes and the scope/intervention row-shape check.
  - [x] Add context normalization and validation for accepted scope values, defaulting, the weighted-random-only algorithm matrix, and draft-only edits.
  - [x] Revalidate algorithm/scope compatibility during activation under the existing transaction and lock.
  - [x] Ensure public graph reads and configuration DTO construction return the stored scope.
- Testing Tasks:
  - [x] Add persistence tests that inspect the new columns, defaults, constraints, partial indexes, nullable intervention foreign-key behavior, and both valid assignment shapes.
  - [x] Test duplicate intervention identities and duplicate section/enrollment identities independently, including database constraint names surfaced by changesets.
  - [x] Add context tests for default and explicit weighted-random scopes, unknown scope, unauthorized update, non-draft update, and Thompson Sampling rejection on create/update/activation.
  - [x] Verify existing experiment and assignment fixtures read as intervention-scoped with unchanged assignment keys.
  - [x] Apply and roll back the migration in the repository's migration-test workflow, including the selected safe behavior when a canonical assignment exists.
  - Command(s): `mix test test/oli/experiments/persistence_test.exs test/oli/experiments/context_test.exs test/oli/experiments/configuration_test.exs`; `mix format`
- Definition of Done:
  - The database and context represent exactly two valid assignment scopes, preserve existing behavior, reject invalid algorithm combinations, and enforce both assignment identity shapes.
  - AC-001, AC-002, AC-008, and the schema portion of AC-013 have automated proof.
- Gate:
  - Gate A: Migration forward/rollback behavior is explicit and tested; domain contracts compile; invalid Thompson/global combinations and unsafe scope edits cannot persist or activate.
- Dependencies:
  - Existing singular experiment/intervention schema and current section-participation model.
- Parallelizable Work:
  - Public struct/type documentation and context test fixture updates may proceed alongside migration drafting after field names, enum values, and constraint names are fixed.

## Phase 2: Scope-Aware Assignment Identity And Runtime Concurrency

- Goal: Implement one shared assignment-identity contract across single, read-only, and page-batch delivery paths for FR-003, FR-004, FR-005, FR-006, FR-009, FR-011, AC-003, AC-004, AC-005, AC-006, AC-009, and AC-011.
- Tasks:
  - [x] Introduce an internal `Oli.Experiments.AssignmentIdentity` helper that derives scope, lookup predicates, insert fields, and deterministic key input from an experiment, resolved intervention, and validated delivery scope.
  - [x] Preserve the current intervention assignment-key format and add an explicit versioned section-and-enrollment key containing experiment, section, and enrollment.
  - [x] Refactor `find_assignment`, assignment creation, uniqueness-conflict reload, and assignment-count increments to consume the derived identity rather than ad hoc intervention predicates.
  - [x] Update `existing_assignment_decision`/`assigned_condition` so lookup first resolves active experiment applicability and then filters by that experiment's configured identity; remove reliance on a broad latest matching assignment.
  - [x] Add a defensive runtime guard that rejects malformed Thompson Sampling plus `section_enrollment` persisted state before lookup or assignment.
  - [x] Update batch assignment rows to left-join the correct assignment identity for each experiment scope while retaining placement-specific intervention rows.
  - [x] Extend the batch reducer with a transaction-local assignment-identity map so later same-experiment placements reuse a successful insert immediately.
  - [x] Keep sorted experiment advisory locks and partial unique indexes as concurrency boundaries; ensure conflicts reload by exact identity and do not increment counts.
  - [x] Preserve mapping validation: a sticky canonical condition unavailable at a later placement falls back as an invalid mapping and is never resampled.
  - [x] Add bounded `assignment_scope` metadata to assignment creation, reuse, conflict, fallback, and invalid-configuration telemetry.
- Testing Tasks:
  - [x] Add runtime tests for one null-intervention canonical assignment reused across two pages or placements, revisits, and allowed later weight changes.
  - [x] Preserve tests proving two intervention-scoped placements are independent and sticky.
  - [x] Test separate enrollments, the same user enrolled in separate sections, selected versus nonparticipating sections, stale participation, and unrelated projects.
  - [x] Race first encounters at different interventions for one section enrollment and assert one assignment row, one condition returned, and one policy-state assignment-count increment.
  - [x] Exercise `assign_condition/1`, `assigned_condition/1`, and `assign_page_conditions/1`, including multiple same-experiment placements, mixed experiments, conflict reload, and malformed persisted scope.
  - [x] Capture/query-inspect single and batch paths to prove indexed bounded lookups, no analytical-store/history access, and no per-placement assignment N+1.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/context_test.exs test/oli/resources/alternatives`; `mix format`; `mix compile`
- Definition of Done:
  - Section-and-enrollment mode creates one canonical row and returns its condition at every eligible intervention; intervention mode remains unchanged; concurrency and batch behavior converge correctly.
  - AC-003, AC-004, AC-005, AC-006, AC-009, and AC-011 have automated proof.
- Gate:
  - Gate B: All public assignment/read paths use the shared identity contract, partial uniqueness is the final race arbiter, and targeted runtime tests pass without query-shape regressions.
- Dependencies:
  - Gate A.
- Parallelizable Work:
  - Single-path refactoring and batch-query test preparation may proceed concurrently after the identity helper contract is fixed; final integration of the batch reducer waits for the helper.

## Phase 3: Placement-Specific Exposure, xAPI, And ClickHouse Contracts

- Goal: Preserve intervention-specific observation evidence for canonical experiment assignments and keep analytics semantics correct for FR-007, FR-012, AC-007, and AC-012.
- Tasks:
  - [x] Extend `RecordExposureRequest` with documented required `page_resource_id` and `content_element_id` fields derived from resolved delivery content.
  - [x] Update single and page-batch exposure callers in `ExperimentControlledStrategy` to pass placement identity.
  - [x] Change exposure idempotency keys to include stable placement identity plus assignment ID, preventing collisions when one assignment is exposed at several interventions.
  - [x] Resolve and validate exposure intervention by assignment experiment, page resource, and content-element identity inside `Oli.Experiments`; reject cross-experiment, missing, or forged placements.
  - [x] Refactor single and batch exposure validation to share the same placement-resolution contract and remain bounded.
  - [x] Add `assignment_scope` to assignment attribution. For section-and-enrollment assignment evidence, omit `intervention_id` rather than inventing ownership.
  - [x] Merge the resolved encountered `intervention_id` and stable `intervention_key` into every exposure attribution independently of assignment ownership.
  - [x] Update runtime event/outbox state only as required for reliable retry of the enriched exposure contract.
  - [x] Add `assignment_scope` to the existing ClickHouse experiment-attribution schema/uploader/query path using ordinary forward/rollback ClickHouse migration conventions and compatible defaults for old evidence.
  - [x] Audit analytics counts and fixtures so canonical assignment rows represent participants and intervention exposure events represent traffic; do not infer missing attribution from a null assignment intervention.
  - [x] Add exposure-specific telemetry metadata for resolved intervention and assignment scope without learner responses or unnecessary identity.
- Testing Tasks:
  - [x] Test that two placements sharing one canonical assignment generate distinct exposure keys and evidence with distinct intervention IDs.
  - [x] Test assignment evidence with `section_enrollment`, explicit section/enrollment, and no intervention ownership.
  - [x] Test forged, missing, cross-project, and cross-experiment exposure placement rejection for single and batch APIs.
  - [x] Update xAPI attribution, ClickHouse uploader, query-builder, and analytics fixtures for explicit scope and nullable assignment intervention.
  - [x] Assert one canonical participant assignment and multiple intervention exposures are counted correctly.
  - [x] Verify ClickHouse migration forward/rollback behavior and compatibility with evidence that predates `assignment_scope`.
  - Command(s): `mix test test/oli/experiments test/oli/analytics test/oli/resources/alternatives`; `mix format`; `mix compile`
- Definition of Done:
  - Assignment evidence describes canonical scope, exposure evidence always identifies the encountered intervention, placement keys cannot collide, and ClickHouse consumers preserve participant/exposure meaning.
  - AC-007 and AC-012 have automated proof.
- Gate:
  - Gate C: Enriched exposure requests are validated end to end, xAPI and ClickHouse tests pass, and no analytics consumer assumes every assignment owns an intervention.
- Dependencies:
  - Gate B for canonical assignment behavior and assignment-scope snapshots.
- Parallelizable Work:
  - ClickHouse schema/fixture work and xAPI attribution unit tests may proceed concurrently with exposure API changes once the additive field and placement-key contracts are fixed.

## Phase 4: Authoring And Experiment Details UX

- Goal: Expose the weighted-random assignment-scope choice through the existing course-author LiveViews for FR-001, FR-002, FR-008, FR-010, AC-001, AC-002, AC-008, and AC-010.
- Tasks:
  - [ ] Add form state and parameter parsing for `assignment_scope` to experiment creation and draft editing in the existing Experiments/Experiment Details LiveViews.
  - [ ] Use an established accessible radio-group or equivalent form primitive with the two required plain-language choices and help explaining experiment-wide reuse within one participating section.
  - [ ] Default new weighted-random forms to section-and-enrollment scope and preserve saved values on validation errors and edit reload.
  - [ ] Hide or render non-editable intervention scope for Thompson Sampling; never rely on UI behavior as the domain validation boundary.
  - [ ] Display the saved scope on experiment details for every lifecycle state without implying cross-section, cross-enrollment, or guaranteed allocation behavior.
  - [ ] Surface context lifecycle and algorithm/scope errors adjacent to the control using existing error patterns.
  - [ ] Preserve current Tailwind/component conventions and responsive behavior; do not introduce new Bootstrap or dedicated stylesheet styling.
  - [ ] Add `assignment_scope` to any form/configuration serialization helpers and test factories used by these LiveViews.
- Testing Tasks:
  - [ ] Add LiveView tests for selector semantics, labels/help, default, explicit save, edit reload, validation-state preservation, unauthorized mutation, draft-only editability, and details display.
  - [ ] Verify Thompson Sampling cannot submit section-and-enrollment scope through forged parameters and its UI does not offer an enabled invalid choice.
  - [ ] Verify keyboard-operable semantic controls, associated help/error text, visible focus via existing primitives, responsive rendering assumptions, and no color-only distinction.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs test/oli_web/live/workspaces/course_author/experiment_details_live_test.exs`; `mix format`; `mix compile`
- Definition of Done:
  - Authorized authors can understand, select, save, and inspect weighted-random scope; invalid or immutable states are clear and the domain remains authoritative.
  - UI proof completes AC-001, AC-002, AC-008, and AC-010.
- Gate:
  - Gate D: LiveView tests pass for creation, editing, details, authorization, validation, and accessibility-relevant markup with no Thompson Sampling escape path.
- Dependencies:
  - Gate A for public configuration contracts. This phase may begin before Gates B and C, but final integrated verification waits for them.
- Parallelizable Work:
  - UI implementation and LiveView tests may run in parallel with Phases 2 and 3 after the Phase 1 request/DTO contract stabilizes.

## Phase 5: End-To-End Scenarios, Documentation Reconciliation, And Manual QA

- Goal: Prove the real authoring-to-delivery workflow and reconcile the epic's prior universal intervention-scope wording for all requirements, especially AC-003 through AC-012.
- Tasks:
  - [ ] Inspect current `Oli.Scenarios` experiment directives before authoring scenario coverage.
  - [ ] Use the repo-local `build_scenario` workflow to add or update a concise scenario with an experiment-controlled group, two placements, participating and nonparticipating sections, multiple enrollments, publication, delivery, revisits, and both weighted-random scopes.
  - [ ] If the existing DSL cannot configure assignment scope or verify durable assignment/exposure results, use `extend_scenario` to add the smallest reusable directive/assertion support with infrastructure tests before building the scenario.
  - [ ] Verify section-and-enrollment mode returns one condition and assignment ID across interventions while producing separate exposure attribution; verify intervention mode remains independently sticky.
  - [ ] Verify a learner represented by separate enrollments in two sections receives independent canonical assignments.
  - [ ] Update the A/B testing manual QA material with setup, expected persistence/evidence, fallback, concurrency/revisit observations, and cleanup notes for both scopes.
  - [ ] Reconcile `intervention_assignment_thompson_sampling` PRD/FDD/requirements/plan language so intervention-scoped assignment remains mandatory for Thompson Sampling while this work item defines section-and-enrollment as the weighted-random default.
  - [ ] Review other epic artifacts that state assignment is universally intervention-scoped and update only the conflicting durable documentation, preserving completed implementation history.
  - [ ] Record implementation proof references for every AC in the execution record or plan completion updates expected by the harness workflow.
- Testing Tasks:
  - [ ] Validate every new or changed `.scenario.yaml` file with `Oli.Scenarios.validate_file/1`.
  - [ ] Run the targeted ExUnit scenario runner and fail on scenario execution or verification errors.
  - [ ] Execute manual QA for form behavior, two-intervention delivery, revisits, participating/nonparticipating fallback, canonical assignment counts, distinct exposures, and details copy.
  - [ ] Run harness traceability checks after documentation reconciliation.
  - Command(s): `mix test test/scenarios/delivery/ab_testing_runtime_test.exs`; `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope --action master_validate --stage plan_present`
- Definition of Done:
  - A real workflow proves both scopes and tenant/participation isolation, manual QA is reproducible, and the epic no longer contradicts the weighted-random exception.
- Gate:
  - Gate E: Scenario validation/execution passes, manual QA evidence is recorded, and durable A/B testing documents consistently describe assignment scope.
- Dependencies:
  - Gates B, C, and D.
- Parallelizable Work:
  - Scenario DSL capability inspection and manual QA drafting may begin earlier; final scenarios and documentation reconciliation wait for settled runtime/evidence behavior.

## Phase 6: Full Verification, Review, And Release Readiness

- Goal: Close cross-cutting correctness, security, performance, observability, formatting, and requirements traceability before implementation completion.
- Tasks:
  - [ ] Run targeted suites from all prior phases, then the broader experiment, delivery Alternatives, analytics, and LiveView test sets warranted by the final diff.
  - [ ] Run `mix format`, `mix compile`, and `git diff --check` with no unresolved warnings or formatting errors caused by this work.
  - [ ] Verify telemetry/AppSignal metadata for both scopes is bounded, privacy-safe, and sufficient to distinguish creation, reuse, conflict, fallback, invalid configuration, and exposure attribution failures.
  - [ ] Review migration rollout and rollback instructions, including existing-row defaults, ClickHouse compatibility, and the selected precondition for reversing PostgreSQL schema after canonical rows exist.
  - [ ] Perform the repository-required code review workflow: always security and performance; add Elixir/Ecto, UI, and requirements reviews for this change set.
  - [ ] Resolve all correctness, security, performance, accessibility, and traceability findings or document an explicitly approved deferral outside this work item.
  - [ ] Run requirements verification for FDD, plan, and implementation proof, then run the work-item validator.
  - [ ] Confirm no Jira write is needed; if tracking changes are desired, separately draft the exact Jira proposal and obtain explicit user approval before using the CLI.
- Testing Tasks:
  - [ ] Run all affected backend, LiveView, scenario, xAPI, ClickHouse, and migration tests identified by the final diff.
  - [ ] Run the complete `mix test` suite if targeted and subsystem suites pass and environment/runtime permits.
  - [ ] Verify no intentional logs leak into normal test output; use `capture_log` only where repository policy requires it.
  - [ ] Run final harness structure, traceability, and plan validation commands.
  - Command(s): `mix format`; `mix compile`; `mix test`; `git diff --check`; `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope --action master_validate --stage implementation_complete`; `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope --check all`
- Definition of Done:
  - FR-001 through FR-013 and AC-001 through AC-013 have implementation proof; all required reviews and verification gates pass; rollout/rollback and residual risks are explicit.
- Gate:
  - Gate F: The feature is formatted, compiled, tested, reviewed, traceable, observable, migration-safe, and ready for normal deployment without a feature flag.
- Dependencies:
  - Gates A through E.
- Parallelizable Work:
  - Security, performance, Elixir/Ecto, UI, and requirements reviews may run in parallel after the implementation diff stabilizes; findings are consolidated before Gate F.

## Parallelization Notes

- Phase 1 fixes the shared field names, enum values, migration constraints, and public DTO contract; no runtime, evidence, or UI implementation should merge ahead of Gate A.
- After Gate A, Phase 2 runtime work and Phase 4 LiveView work can proceed concurrently because both consume the stable context contract.
- Within Phase 3, xAPI attribution work and ClickHouse schema/fixture work can proceed concurrently after the additive evidence fields and placement-key format are agreed.
- Scenario capability inspection, documentation conflict inventory, and manual QA drafting can begin before implementation, but final scenario assertions and reconciliation must use committed runtime/evidence semantics.
- Avoid simultaneous edits to `lib/oli/experiments.ex` across assignment and exposure work unless ownership is split by non-overlapping functions and coordinated closely; it is the primary merge-conflict hotspot.
- Final review lenses can run concurrently only after the diff is stable. Requirements findings should be reconciled with functional test proof before implementation traceability is marked complete.

## Phase Gate Summary

- Gate A: Typed scope persistence, reversible migration behavior, public contracts, lifecycle rules, and Thompson Sampling rejection are complete.
- Gate B: Single, read-only, and batched assignment paths share one identity contract and pass stickiness, isolation, concurrency, participation, and performance tests.
- Gate C: Exposure placement is independently validated and attributed; xAPI and ClickHouse preserve canonical participant versus intervention-traffic semantics.
- Gate D: Authoring and details LiveViews expose accessible, authorized, lifecycle-safe weighted-random scope configuration.
- Gate E: End-to-end scenarios, manual QA, and epic documentation prove and consistently describe both weighted-random modes.
- Gate F: Full tests, formatting, compilation, migration checks, required reviews, observability checks, and requirements validation pass.
