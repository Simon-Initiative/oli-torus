# Intervention-Scoped Assignment and Assessment-Driven Thompson Sampling - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/requirements.yml`

## Scope

Extend `Oli.Experiments` so each experiment owns one assignment policy, one reusable Alternatives Group, stable conditions and mappings, and one policy/posterior scope, while each placed Alternatives instance is a distinct sticky assignment opportunity. Add assessment-driven, asynchronous Beta-Bernoulli Thompson Sampling rewards; preserve weighted-random behavior; make Alternatives Group strategy canonical and group-owned; preserve authoring, publication, delivery, completion, export/ingest, and legacy-content compatibility; and expose bounded policy reporting, analytics evidence, and operational telemetry.

Guardrails:

- PostgreSQL remains the transactional source of truth. Assignment, reward, and reporting paths must not read ClickHouse, xAPI, or reward history.
- Existing Alternatives revisions and publications remain readable without content rewrite, forced author save, or republication. Pre-release QA experiment definitions, assignments, rewards, policy state, and experiment analytics are disposable and require no migration or preservation.
- New database migrations are generated with `mix ecto.gen.migration`, implement explicit `up/0` and `down/0`, and are verified forward and backward for PostgreSQL and ClickHouse schema correctness. Rollback restores schema shape, not discarded QA experiment rows.
- Experiment mutation and lifecycle rules belong in `Oli.Experiments`; LiveViews and delivery modules remain interaction and transport adapters with server-derived authorization and identity.
- Both Alternatives strategies may appear inside ordinary containers, but no Alternatives placement may have another Alternatives placement as an ancestor. Delivery pays only one indexed relevance check for sections without an applicable active experiment and resolves all valid positive-path experiment placements in one set-based operation without recursive assignment rounds.
- Preview never creates experiment state or evidence. Learner rendering and completion use the same persisted intervention decisions.
- New UI uses existing components and Tailwind conventions. The current Experiments group editor is the behavioral baseline for the shared component. Produce approved design guidance before implementing the expanded experiment configuration and posterior-reporting UI.
- No feature flag is added. Rollout is gated by migration safety, valid draft activation, and normal deployment.
- The canonical change is a coordinated QA-only schema and code cutover. It requires no expand/backfill stage, mixed-version compatibility window, dual reads/writes, or preservation of existing experiment rows. Only Gate P authorizes the completed canonical implementation.
- Jira ticket creation or editing is a separate operation: draft exact ticket changes and obtain explicit user approval before any Jira write.

## Clarifications & Default Assumptions

- Phases 1 through 12 record completed implementation history. Any multi-point task or gate in those phases is superseded by the canonical single-scope contract and Phases 13 through 16; it is not an active requirement for handoff or release.
- During Phase 1, confirm the canonical resource-attempt ordering column, the successfully finalized attempt predicate, nested Alternatives element-ID behavior across every copy/duplicate path, and the current ClickHouse event schema. These are implementation facts; if repository behavior differs from the FDD, update the detailed slice design before coding without changing the product requirements silently.
- Use dependency-ordered generated PostgreSQL migrations and ordinary ClickHouse migrations. They may delete or recreate QA experiment rows but must leave existing Alternatives content untouched.
- Replace nested decision-point request and report shapes with singular experiment group, mapping, policy, and posterior fields. Migrate every in-repository caller directly; do not introduce temporary compatibility adapters.
- Extend existing policy modules, outbox/evidence infrastructure, and Oban reward handoff rather than introducing parallel runtimes.
- Use deterministic injectable random seams in policy tests; production sampling continues to use the repository's established random source.
- If current `Oli.Scenarios` directives cannot express experiment configuration, assignment visibility, scored-page finalization, posterior assertions, and completion percentage, use `extend_scenario` before `build_scenario` for the minimum reusable DSL additions.
- AppSignal metrics and dashboards use bounded identifiers and reasons. No new numeric latency SLO is introduced.
- Detailed design may split a phase into smaller slices, but it must retain the requirement allocation and gate order below.

## Phase 1: Confirm Runtime Contracts and Detailed Slice Boundaries

- Goal: Resolve the implementation facts that affect schema and workflow design, record executable slice boundaries, and establish baseline behavior before migrations or runtime changes.
- Tasks:
  - [x] Audit current experiment schemas, lifecycle APIs, policy-state encoding, assignment/reward uniqueness, and compatibility callers in `lib/oli/experiments.ex` and `lib/oli/experiments/`.
  - [x] Trace resource-attempt scoring through finalization and post-commit hooks; document the authoritative final-state predicate and persisted attempt ordering used by reward eligibility (FR-013, FR-016).
  - [x] Trace Alternatives insertion, reorder, copy, page duplication, and course movement; confirm which operations retain or regenerate page resource and nested element IDs (FR-005, FR-006, FR-019).
  - [x] Measure the current delivery query path and identify the indexed section relevance query plus positive-path batching boundary (FR-027).
  - [x] Inspect the existing xAPI/ClickHouse attribution schema and outbox/retry path; choose additive evidence fields and migration placement (FR-023, FR-024, FR-026).
  - [x] Produce slice-level designs for persistence/configuration, assignment/rendering/completion, reward/evidence, authoring/reporting UI, and compatibility/interop, including public API inputs, transaction ownership, indexes, and rollback order.
  - [x] Record governed, best-effort design guidance for expanded multi-decision-point configuration and posterior reporting. No feature-level Figma exists or is required; implementation will use minimal conventional Torus patterns and runtime UX refinement.
- Testing Tasks:
  - [x] Add or identify characterization tests for legacy experiment reads, group-strategy resolution, element identity across edits, attempt ordering, and the negative delivery path before changing behavior.
  - [x] Record a representative query-count baseline for delivery with no active experiment and with repeated Alternatives placements.
  - Command(s): `mix test <targeted existing experiment, attempt, editor, and delivery test files>`
- Definition of Done:
  - Implementation facts are recorded in detailed designs; every later phase has concrete code/test targets; baseline tests protect legacy behavior; no unresolved product decision is hidden in implementation work.
- Gate:
  - Gate A — detailed slice designs are reviewed, identity and attempt-order contracts are confirmed, query baselines are captured, and the best-effort Torus-native UI approach is recorded. This is an internal review checkpoint, not a release boundary.
- Dependencies:
  - Approved PRD, FDD, and `requirements.yml`.
- Parallelizable Work:
  - Attempt lifecycle, editor identity, delivery-query, analytics-schema, and UI-design audits may proceed concurrently; their conclusions converge before schema work.

## Phase 2: Establish Canonical Strategy and Persistence Foundations

- Goal: Add backward-compatible storage and normalization for experiment-owned conditions, decision-point mappings, interventions, bindings, assignments, rewards, and policy state (FR-001, FR-002, FR-003, FR-006, FR-007, FR-010, FR-011, FR-015, FR-025, FR-026, FR-033).
- Tasks:
  - [x] Generate dependency-ordered Ecto migrations for experiment-owned conditions with preserved IDs and experiment-scoped unique codes, `experiment_decision_point_conditions`, `experiment_interventions`, `experiment_assessment_bindings`, intervention-scoped assignment keys, accepted-reward identity, and decision-point policy configuration/state.
  - [x] Implement explicit `up/0` and `down/0` functions, ID/code-preserving condition normalization without implicit merging, non-cascading foreign keys, bijection/identity uniqueness, delivery/reward indexes, and legacy-row compatibility.
  - [x] Add schemas, changesets, associations, validated policy-state encoding/decoding, and canonical `experiment_controlled` strategy persistence.
  - [x] Implement and document `Oli.Resources.Alternatives.normalize_strategy/1` and the canonical write boundary; normalize `upgrade_decision_point` only at reads and ingest, and fail closed for unsupported strategies.
  - [x] Keep historical and successor revisions of legacy groups untouched while ensuring newly created A/B Test groups write the canonical strategy.
  - [x] Add an ordinary reversible ClickHouse migration or documented map-extension change for the selected evidence fields, keeping old rows compatible.
- Testing Tasks:
  - [x] Test migration forward/rollback with representative legacy decision points, duplicate/conflicting condition codes, preserved condition IDs/codes, assignments, rewards, code-keyed policy JSON, and group revisions; assert row-count and relationship preservation.
  - [x] Test database and changeset constraints for experiment condition uniqueness, mapping bijection, intervention identity, binding identity, assignment uniqueness, reward claims, and `on_delete: :nothing`.
  - [x] Test canonical/legacy/unsupported group strategy reads and canonical-only new A/B Test group writes without legacy mutation or republication.
  - Command(s): `mix test <migration, schema, changeset, alternatives strategy tests>`; `mix ecto.migrate`; `mix ecto.rollback --step <phase migration count>`
- Definition of Done:
  - The additive persistence model supports new intervention-scoped writes and legacy reads; all constraints and indexes match the FDD; PostgreSQL and ClickHouse changes apply and roll back safely.
- Gate:
  - Gate B — migration tests pass in both directions, legacy data remains readable, and focused phase review finds no destructive cascade or unbounded runtime lookup; FR-025/FR-026/FR-033 compatibility proofs pass. This gate does not authorize deployment.
- Dependencies:
  - Gate A.
- Parallelizable Work:
  - Strategy normalization and ClickHouse schema work can proceed alongside PostgreSQL migration implementation after names and compatibility contracts are fixed.

## Phase 3: Implement Draft Configuration, Validation, and Lifecycle Integrity

- Goal: Provide authorized domain APIs for multi-decision-point experiment configuration, activation, immutability, reuse, and explicit dependency reconciliation (FR-001 through FR-004, FR-011, FR-012, FR-017 through FR-020).
- Tasks:
  - [x] Refactor `Oli.Experiments` internals around focused configuration operations while preserving it as the public boundary. This completed multi-point intermediate is superseded by Phase 14's singular contract.
  - [x] Add experiment-owned algorithm/condition configuration and per-decision-point APIs for group binding, guardrails, bijective mappings, interventions, distinct scored-page bindings, and inclusive decimal thresholds defaulting to `1.0`.
  - [x] Resolve request-local condition `client_ref` values during atomic graph creation, generate immutable readable codes from labels under the experiment lock with deterministic collision suffixes, and persist mappings by `condition_id`.
  - [x] Enforce `Scope` authorization, compatible project lineage, experiment-controlled group strategy, stable group/option identities, current-binding exclusivity, mapping cardinality, scored-page eligibility, and assessment exclusivity.
  - [x] Lock the experiment and sorted group resources for save/activation; reject invalid transitions and all prohibited non-draft structural mutations.
  - [x] Implement explicit dependency discovery/reconciliation for bound groups, interventions, and assessment pages; never silently cascade or retarget active history.
  - [x] Preserve completed/archived history and allow sequential group reuse only through a new draft decision point with independent state.
- Testing Tasks:
  - [x] Add context and changeset tests for the then-current graph configuration and structured activation errors. Phase 14 replaces multi-point fixtures with singular configuration coverage.
  - [x] Test duplicate, missing, and unknown request-local condition references, slug normalization, deterministic collision suffixes, label edits preserving codes, and experiment-scoped database uniqueness.
  - [x] Add authorization, transaction-lock, lifecycle-transition, immutable-history, sequential-reuse, and dependency-deletion tests.
  - [x] Test threshold defaults and boundary validation at `0.0` and `1.0`, plus weighted-random configurations without assessment bindings.
  - Command(s): `mix test <experiment configuration, authorization, lifecycle, and dependency tests>`
- Definition of Done:
  - Authorized authors can build and activate only structurally valid draft experiments; invalid or historical structures cannot be mutated; configuration errors identify their decision point, mapping, intervention, or binding.
- Gate:
  - Gate C — context tests prove AC-001 through AC-004, AC-011, AC-012, and AC-017 through AC-020, with focused phase review of transactions, authorization, complete caller migration, and removal of the single-point API shape. This gate does not authorize deployment.
- Dependencies:
  - Gate B.
- Parallelizable Work:
  - Validation/error-shape work and dependency/lifecycle enforcement can proceed concurrently against the stable Phase 2 schemas, then converge in activation tests.

## Phase 4: Deliver Intervention-Scoped Assignment, Rendering, and Completion

- Goal: Assign independently and stickily per placement, retain bounded performance, make rendering, preview, fallback, and completion honor the persisted visible alternative, and prohibit Alternatives placements from containing another Alternatives placement while allowing both strategies in ordinary containers (FR-005 through FR-010, FR-019, FR-021, FR-022, FR-027, FR-034).
- Tasks:
  - [x] Add the indexed section-level active-experiment relevance gate; on a negative result perform no experiment binding, assignment, policy, reward, or evidence work.
  - [x] Enforce the structural no-Alternatives-ancestor rule in insertion, drag/drop, schema, and experiment configuration while allowing both strategies inside ordinary containers and preserving a drag-out repair path for invalid legacy content.
  - [x] Resolve pinned group revisions for all rendered Alternatives while classifying placements in one traversal and resolving intervention bindings, policy snapshots, mappings, and existing assignments for valid experiment-controlled placements in one set-based operation.
  - [x] Implement `assign_condition/1` and `assigned_condition/1` using enrollment, decision point, page resource ID, and element ID; retain revision/publication only as event context.
  - [x] Implement weighted-random and Thompson Sampling from one committed decision-point snapshot with deterministic test seams, configured/default priors, and guardrails at decision-point scope.
  - [x] Resolve concurrent inserts through database uniqueness, reload the persisted winner, and increment assignment counts only for the successful insert.
  - [x] Make missing/inactive/incompatible/corrupt experiment state fail safely to the first local alternative with bounded telemetry and no experiment state.
  - [x] Feed the same persisted prepared decisions into rendering and progress/completion traversal so hidden siblings never enter the learner-specific numerator or denominator.
  - [x] Ensure Authoring and Instructor Preview show all local alternatives in accessible tabs without assignments, exposures, rewards, or policy effects.
  - [x] Audit and correct copy boundaries so reorder and whole-page moves preserve intervention identity; same-page element recreation/reinsertion generates a new element ID; and page duplication/future cross-page moves derive new intervention identity from the destination page resource without regenerating unrelated content-element IDs or copying bindings.
- Testing Tasks:
  - [x] Add deterministic policy tests for fixed weights, Beta priors, one-snapshot draws, shared per-point posterior state, point/experiment isolation, sticky revisits, and independent placements.
  - [x] Add concurrent first-encounter tests for same and different interventions and assert compact evidence/count behavior.
  - [x] Add query-count tests proving the one-query negative path and set-based positive placement path without recursive assignment rounds, per-placement N+1 queries, or analytical reads.
  - [x] Add rendering, fallback, preview accessibility, edit identity, and completion tests with alternatives containing different required-activity counts; prove visible-only partial percentages and exact 100% completion for multiple assignment combinations.
  - Command(s): `mix test <policy, page decisions, rendering, progress/completion, editor identity, and preview tests>`
- Definition of Done:
  - Learners receive independent sticky selections per intervention; rendering and completion remain stable and correct; preview and fallback are inert; measured query behavior remains bounded.
- Gate:
  - Gate D — AC-005 through AC-010, AC-019, AC-021, AC-022, AC-027, and AC-034 pass, including concurrency, query-count, accessibility, structural non-nesting, and 100%-completion proofs, and the phase changes complete focused code review. This gate does not authorize deployment.
- Dependencies:
  - Gate C for valid active configurations. Editor identity fixes that do not depend on activation may begin after Gate A.
- Parallelizable Work:
  - Policy/assignment, rendering/completion, preview, and editor-identity streams may proceed concurrently against agreed APIs; final integration and query-budget tests join them.

## Phase 5: Process Assessment Rewards Atomically and Asynchronously

- Goal: Convert the first eligible finalized scored-page attempt into exactly one condition reward without blocking submission or corrupting posterior state (FR-011 through FR-016).
- Tasks:
  - [x] Enqueue `RewardHandoffWorker` only after scored-page evaluation commits, passing only trusted resource-attempt identity and server scope.
  - [x] Resolve relevant bindings, enrollment, normalized overall score, canonical attempt order, and the first eligible finalized attempt server-side; keep an earlier pending attempt as a blocker.
  - [x] Resolve only the persisted assignment for the bound intervention; record a bounded skip when absent and never infer or create a retroactive assignment.
  - [x] In one transaction, lock the decision-point policy row, claim the unique binding/source reward, calculate `normalized_score >= threshold`, update only the assigned condition posterior and accepted counts, and persist compact before/after context.
  - [x] Make duplicate/replayed work return the prior disposition and make concurrent distinct rewards serialize without lost updates.
- Testing Tasks:
  - [x] Cover threshold `0.0`, `1.0`, exact boundary, below boundary, binding-specific values, and proof that existing page scoring—not activity inspection—supplies the score.
  - [x] Cover pending blockers, canonical attempt ordering, eventual first-final acceptance, later attempts, reevaluation, missing assignment, duplicate job, rollback, and retry.
  - [x] Add concurrency tests for one replayed reward and multiple distinct rewards to the same policy row; assert one claim per accepted source and no lost alpha/beta increments.
  - [x] Prove submission completes independently, only committed posterior updates affect later new assignments, and existing assignments never change.
  - Command(s): `mix test <reward handoff, worker, attempt eligibility, policy transaction, and Oban tests>`
- Definition of Done:
  - Reward processing is post-commit, deterministic, atomic, idempotent, retryable, and correctly attributed; failures cannot block assessment submission or partially mutate policy state.
- Gate:
  - Gate E — AC-011 through AC-016 pass under normal, duplicate, failure, and concurrent execution, and the phase changes complete focused code review. This gate does not authorize deployment.
- Dependencies:
  - Gate C for bindings and Gate D for persisted intervention assignments.
- Parallelizable Work:
  - Eligibility-query tests and transaction/idempotency work may proceed concurrently after the Phase 1 attempt contract and Phase 2 schema are stable.

## Phase 6: Complete Authoring Surfaces, Policy Reporting, and Content Contract

- Goal: Deliver consistent strategy-specific group management, full draft configuration, bounded non-draft policy reporting, and the final Alternatives placement schema (FR-004, FR-017, FR-021, FR-028 through FR-030, FR-032, FR-033).
- Tasks:
  - [x] Extract the existing Experiments group editor into a shared LiveComponent retaining cards, option management, reorder behavior, validation, deletion safeguards, permissions, and accessible controls.
  - [x] Configure `AlternativesLive` for `user_section_preference` with Learner Choice labels and filtering; configure `ExperimentsLive` for canonical `experiment_controlled`, rename the section to `Experiment-Controlled Alternatives`, and retain experiment listing/configuration.
  - [x] Make each creation surface assign strategy implicitly, remove type selectors and inline placement-content editing, and prohibit strategy/option-identity mutation.
  - [x] Implement multi-decision-point draft forms for mappings, policies, priors/weights, guardrails, interventions, scored pages, thresholds, validation errors, and lifecycle read-only states using approved design guidance.
  - [x] Implement `policy_snapshot/2` as bounded PostgreSQL reads and render non-draft Thompson metrics: estimated success probability, accepted success/failure counts, observed assignment count/share, update time, expandable alpha/beta, effective guardrail mode/progress/affected conditions, imbalance warning, and lifecycle pause/end state.
  - [x] Omit posterior metrics for draft and weighted-random experiments, never calculate next-assignment probability, and preserve frozen completed/archived snapshots.
  - [x] Update `priv/schemas/v0-1-0/content-alternatives.schema.json` to require valid `alternatives_id`, stop requiring or trusting element strategy, and remain permissive for ignored legacy strategy strings; ensure new insertion omits strategy.
- Testing Tasks:
  - [x] Add LiveView/component tests for both retained routes, strict list/create filtering, implicit strategy writes, shared behavior, permissions, lifecycle restrictions, validation, no selector, and no inline content editing.
  - [x] Add keyboard interaction tests for shared group controls and preview tabs.
  - [x] Add reporting context/LiveView tests for every lifecycle, algorithm, posterior formula/count/share, refresh, effective mode, thresholds/progress, affected conditions, imbalance warning, expandable details, and omission rules; assert no reward-history or analytics reads.
  - [x] Add JSON Schema fixtures for new placements, legacy matching/conflicting/unknown strategy, invalid/missing `alternatives_id`, and the parent schema reference.
  - [x] Run targeted Jest tests if shared frontend components are touched; otherwise keep interaction coverage in LiveView tests.
  - Command(s): `mix test <ExperimentsLive, ExperimentDetailsLive, AlternativesLive, component, and schema tests>`; `cd assets && yarn test <targeted tests>`; `cd assets && yarn lint`; `cd assets && yarn format`
- Definition of Done:
  - Authors see two consistent but strategy-isolated management surfaces, can configure valid draft experiments, and can inspect accurate bounded policy snapshots; new and legacy placement JSON validates under the intended contract.
- Gate:
  - Gate F — AC-004, AC-017, AC-021, AC-028 through AC-030, AC-032, and UI-relevant AC-033 pass, with focused code, accessibility, and design review complete. This gate does not authorize deployment.
- Dependencies:
  - Gates C, D, and approved UI design guidance; reporting additionally depends on Gate E counts/state.
- Parallelizable Work:
  - Shared group management, experiment configuration, reporting, and JSON Schema/insertion work can proceed as separate slices after their domain contracts stabilize.

## Phase 7: Preserve Export/Ingest and Emit Detailed Evidence

- Goal: Round-trip group-owned strategy and repeated placements while exporting privacy-safe, retryable experiment evidence and telemetry (FR-023, FR-024, FR-025, FR-031, FR-033).
- Tasks:
  - [x] Extend project export to include every referenced Alternatives Group's canonical strategy, stable option identities/labels, and required content exactly once while preserving repeated placement-local content.
  - [x] Update ingest to create/normalize groups before rewiring every `alternatives_id`; ignore placement strategy, default strategy-less legacy groups to `user_section_preference`, and canonicalize imported `upgrade_decision_point` groups.
  - [x] Extend assignment, exposure, assessment, reward, disposition, and policy-update evidence with intervention, binding, attempt, threshold/score where permitted, revision snapshot, and before/after policy context. Exact attempt-time publication attribution is deferred until required; the host statement uses current deployment context.
  - [x] Dispatch detailed reward evidence and latency telemetry only after the PostgreSQL reward transaction commits; retry evidence delivery independently without reapplying posterior mutation.
  - [x] Add bounded telemetry for relevance, binding resolution, assignment creation/reuse/conflict/fallback, sampling mode, reward outcomes, posterior updates, queue/transaction latency, evidence dispatch, and migration anomalies.
  - [x] Verify that logs, telemetry, xAPI, ClickHouse, and retry/outbox payloads exclude raw responses, free-form content, email/name, and unnecessary learner identity.
  - [x] Define AppSignal dashboard/alert follow-up for fallback/error rate, queue-to-update latency, skip/duplicate reasons, update failure, imbalance, and migration anomalies; keep environment changes outside this code plan unless separately authorized.
- Testing Tasks:
  - [x] Add end-to-end export/ingest tests for both strategies, repeated placements, local content, ID rewiring, strategy-less legacy groups, alias canonicalization, and ignored missing/matching/conflicting/unknown element strategies.
  - [x] Test evidence completeness, after-commit ordering, retry behavior, runtime-source separation, bounded telemetry cardinality, and privacy exclusions.
  - [x] Test that legacy revisions/publications remain byte-for-byte untouched and usable while new exports emit canonical strategy.
  - Command(s): `mix test <interop, xAPI, ClickHouse adapter, telemetry, and compatibility tests>`
- Definition of Done:
  - Interop preserves group semantics and repeated placements across round trips; operational signals and detailed evidence are complete, bounded, private, and never become runtime read dependencies.
- Gate:
  - Gate G — AC-023 through AC-026, AC-031, and evidence/interop AC-033 pass; focused phase review plus privacy, security, and rollback review find no blocking issue. This gate does not authorize deployment.
- Dependencies:
  - Gates B, D, E, and F.
- Parallelizable Work:
  - Interop and evidence/telemetry streams may proceed concurrently once the canonical strategy and event contracts are stable.

## Phase 8: Add Workflow-Level Scenario Coverage

- Goal: Prove the integrated authoring-to-delivery workflows with real Torus infrastructure and persistence rather than fixtures or browser automation (FR-005 through FR-016, FR-021 through FR-023, FR-027).
- Tasks:
  - [x] Audit existing `Oli.Scenarios` directives for experiment creation/configuration, repeated Alternatives placement, publication, section participation, learner assignment visibility, scored-page evaluation, posterior assertion, and completion percentage.
  - [x] If required, use `extend_scenario` to add the smallest reusable directive/parser/handler/assertion support with infrastructure tests.
  - [x] Use `build_scenario` to author a workflow with two learners assigned to different alternatives across repeated interventions; complete only each learner's visible required activities plus the shared assessment and assert both reach 100%.
  - [x] Add a workflow proving sticky revisits, scored-page finalization, one accepted reward, posterior reuse by a later intervention, and isolation from a separate experiment.
  - [x] Keep scenarios concise; retain concurrency, exhaustive boundary, migration, and detailed UI assertions in targeted ExUnit/LiveView tests.
- Testing Tasks:
  - [x] Validate each scenario YAML with `Oli.Scenarios.validate_file/1`.
  - [x] Run scenario-infrastructure tests if the DSL changes, then targeted companion ExUnit runners and fail on any scenario execution or verification error.
  - Command(s): `mix test <scenario infrastructure tests>`; `mix test <intervention assignment Thompson Sampling scenario runners>`
- Definition of Done:
  - Real authoring, publishing, delivery, assignment, completion, assessment, reward, and later sampling behavior succeeds end to end for multiple learners and interventions.
- Gate:
  - Gate H — scenario validation and runners pass with no fixtures, factories, mocks, browser automation, or visible intentional logs, and the scenario phase completes focused code review. This gate does not authorize deployment.
- Dependencies:
  - Gates D, E, F, and G. Scenario DSL work may start earlier once public domain APIs stabilize.
- Parallelizable Work:
  - DSL capability work and scenario drafting may overlap, but final scenarios wait for the relevant integrated behavior.

## Phase 9: Historical Integrated Verification Checkpoint (Superseded)

- Goal: Record the earlier FR-001 through FR-034 integrated checkpoint. This phase no longer establishes release readiness; Phase 16 and Gate P supersede it.
- Tasks:
  - [ ] Run the full targeted suite followed by broader experiment, delivery, attempt, publication, interop, analytics, LiveView, and scenario suites warranted by changed files.
  - [ ] Apply `mix format`, compile with warnings treated according to repository CI, and run frontend lint/format/tests for touched assets.
  - [ ] Repeat PostgreSQL and ClickHouse forward/rollback schema verification in dependency order and confirm no Alternatives content backfill or forced republication is required; experiment-row preservation is excluded.
  - [ ] Re-measure negative and positive delivery query counts, assignment/reward boundedness, concurrency behavior, and policy snapshot queries against Phase 1 baselines.
  - [ ] Review changes using `.review/security.md` and `.review/performance.md` always, plus `.review/elixir.md`, `.review/ui.md`, `.review/typescript.md`, and `.review/requirements.md` when applicable; resolve all blocking findings.
  - [ ] Verify AppSignal event names/dimensions and prepare dashboard/alert and coordinated QA deployment/rollback notes.
  - [ ] Reconcile PRD/FDD/plan/requirements proof artifacts if implementation drift occurred, then run harness requirement and work-item validation.
  - [ ] Superseded by Phase 14: remove nested point request/report shapes and prove all callers use the singular experiment contract.
  - [ ] If Jira updates are desired, draft the exact tickets/comments for separate user approval before running any `jira` write command; read back and verify formatting after approved writes.
- Testing Tasks:
  - [ ] Run targeted and relevant aggregate backend/LiveView/scenario tests, schema fixtures, migration verification, and frontend tests.
  - [ ] Confirm tests that intentionally emit logs use `@tag capture_log: true` or `capture_log/1` and that normal output is clean.
  - [ ] Produce a traceability report showing implementation and test evidence for every FR/AC pair.
  - Command(s): `mix format`; `mix compile`; `mix test <all affected suites>`; `cd assets && yarn test <affected suites>`; `cd assets && yarn lint`; `cd assets && yarn format`; `python3 <skills_root>/requirements/scripts/requirements_trace.py <work_item_dir> --action master_validate --stage implementation_complete`; `python3 <skills_root>/validate/scripts/validate_work_item.py <work_item_dir> --check all`
- Definition of Done:
  - Historical FR-001 through FR-034 verification is recorded; canonical completion remains pending through Phase 16.
- Gate:
  - Gate I — superseded historical checkpoint; it does not authorize release of the canonical single-scope implementation.
- Dependencies:
  - Gates B through H.
- Parallelizable Work:
  - Review lenses, documentation reconciliation, telemetry/deployment notes, and broad suite execution can run concurrently after all feature slices are integrated; final sign-off and any deployment wait for all results.

## Phase 10: Discover Weighted-Random Interventions During Delivery

- Goal: Remove author-managed weighted-random intervention configuration while retaining durable per-placement assignment identity (FR-006 through FR-009).
- Tasks:
  - [x] Allow weighted-random experiments to activate without persisted interventions while retaining Thompson Sampling intervention and assessment validation.
  - [x] Bulk-discover active weighted-random decision points from delivered group placements and lazily insert missing intervention identities with uniqueness-conflict safety.
  - [x] Keep Thompson Sampling limited to explicitly configured interventions and bindings.
  - [x] Remove weighted-random intervention and assessment controls from the experiment details form and ignore stale submitted intervention fields when the selected policy is weighted random.
- Testing Tasks:
  - [x] Prove weighted-random activation without interventions, lazy assignment/materialization, sticky reuse, bounded page batching, and policy-specific authoring controls.
  - [x] Run focused context, runtime, and LiveView tests plus formatting, compilation, and work-item validation.
- Definition of Done:
  - Weighted-random authors configure mappings and weights only; all valid delivered placements participate automatically and retain durable sticky assignment identities.
- Gate:
  - Gate J — focused domain/runtime/UI tests and review confirm lazy materialization is secure, conflict-safe, bounded, and isolated from Thompson Sampling configuration.

## Phase 11: Make Assignment Policy Experiment-Scoped

- Goal: Make one experiment-level algorithm authoritative across the then-current point hierarchy; Phase 13 onward removes that hierarchy.
- Tasks:
  - [x] Keep assignment-policy selection in experiment creation and display it read-only afterward.
  - [x] Apply the immutable creation-time policy to all existing and newly added decision points.
  - [x] Remove decision-point policy selection from the supported authoring graph and apply the experiment policy to every point.
  - [x] Preserve decision-point-specific mappings, weights, guardrails, policy state, interventions, and assessment bindings.
- Testing Tasks:
  - [x] Verify the details surface has no assignment-policy control and structural saves retain the creation-time policy.
  - [x] Verify assignment-policy updates fail and focused context/LiveView suites pass.
- Definition of Done:
  - Authors select assignment policy once during experiment creation and cannot later change it or create a mixed-policy graph.
- Gate:
  - Gate K — domain and LiveView tests confirm experiment-level authority and coherent decision-point persistence.

## Phase 12: Remove Decision-Point Algorithm Persistence

- Goal: Make the experiment definition the sole persisted source of assignment policy.
- Tasks:
  - [x] Generate a reversible migration that removes the decision-point algorithm column and restores it from experiment definitions on rollback.
  - [x] Make the decision-point schema algorithm virtual and exclude it from changesets and persistence attributes.
  - [x] Derive policy dispatch, authoring payloads, activation validation, runtime joins, rewards, and policy-state creation from the owning experiment.
- Testing Tasks:
  - [x] Run focused configuration and runtime suites against the migrated schema.
  - [x] Run formatting, compilation, work-item validation, and relevant review lenses.
- Definition of Done:
  - Experiment definitions are the only persisted assignment-policy owner and every decision-point consumer derives that value consistently.
- Gate:
  - Gate L — migration, domain, runtime, documentation, and review checks confirm the duplicate persistence invariant is gone.

## Phase 13: Replace Experiment Persistence with the Singular Schema

- Goal: Replace the pre-release decision-point persistence hierarchy with the final experiment-owned PostgreSQL and ClickHouse schemas without migrating or preserving QA experiment data (FR-001, FR-002, FR-003, FR-026, FR-035).
- Tasks:
  - [ ] Generate dependency-ordered PostgreSQL migrations that place the Alternatives resource, mapping, policy parameters/state, interventions, assignments, bindings, and rewards directly under the experiment and remove decision-point tables, columns, foreign keys, and indexes.
  - [ ] Use explicit `up/0` and `down/0`. Forward migration may delete or recreate pre-release QA experiment rows in dependency-safe order; rollback restores the prior schema shape but need not reconstruct discarded rows.
  - [ ] Add the final experiment-scoped unique constraints, foreign keys, and composite indexes required by configuration, assignment, reward, and reporting paths.
  - [ ] Add an ordinary reversible ClickHouse migration to remove decision-point attribution and retain experiment, intervention, condition, assignment, and assessment identity where the analytical schema changes.
  - [ ] Keep Alternatives Groups, page content, revisions, and publications outside the destructive experiment-data boundary.
- Testing Tasks:
  - [ ] Add PostgreSQL migration tests that assert the exact forward and rollback tables, columns, foreign keys, indexes, and constraints without asserting experiment-row preservation.
  - [ ] Apply and roll back the ClickHouse migration and verify the final attribution schema in both directions.
  - [ ] Prove representative existing Alternatives content remains readable and publishable without conversion or republication after the experiment schema replacement.
  - Command(s): `mix test test/oli/experiments/persistence_test.exs`
- Definition of Done:
  - PostgreSQL and ClickHouse expose the final singular schema with correct constraints and indexes; the legacy decision-point persistence hierarchy is absent; no experiment-data backfill or compatibility storage remains.
- Gate:
  - Gate M — forward/rollback schema verification passes, existing Alternatives content remains compatible, and review confirms that destructive scope is limited to disposable QA experiment data.
- Dependencies:
  - Phase 12 and the canonical single-scope PRD/FDD/requirements.
- Parallelizable Work:
  - Singular request/view design and test-fixture updates may proceed while migrations are authored; code integration waits for the final schema contract at Gate M.

## Phase 14: Simplify Domain and Runtime Contracts

- Goal: Remove decision-point concepts from configuration, assignment, policy, reward, and reporting code while preserving repeated-intervention semantics (FR-006 through FR-017, FR-021 through FR-024).
- Tasks:
  - [ ] Replace nested `decision_points` create/update payloads and authoring views with singular experiment group, mapping, and policy fields; remove compatibility adapters and point candidates that no longer carry distinct meaning.
  - [ ] Replace point-specific validation, graph reconciliation, ordering, grouping, hydration, ambiguity, and conflict helpers directly with singular experiment operations; do not add dual-compatible reads or writes.
  - [ ] Resolve active experiments directly by project, section participation, state, and Alternatives resource; keep weighted-random lazy intervention materialization bounded and server-validated.
  - [ ] Key policy-state lookup/locking, assignment counts, guardrails, Thompson snapshots, and posterior rewards directly by experiment and condition.
  - [ ] Remove decision-point identity from transactional telemetry and new xAPI/ClickHouse attribution contracts while preserving experiment, intervention, condition, group, assignment, and assessment identities.
- Testing Tasks:
  - [ ] Rewrite context, configuration, runtime, concurrency, reward-handoff, telemetry, analytics, and attribution tests around one experiment policy scope and many interventions.
  - [ ] Retain query-count proofs for negative delivery, lazy materialization, page batching, sticky reuse, and reward processing.
  - [ ] Add deny-by-default cross-project, cross-tenant, and cross-section tests for flattened create/update group references, lazy materialization, assignment access, reward resolution, and reporting.
  - [ ] Run representative-data `EXPLAIN (ANALYZE, BUFFERS)` checks for active-experiment resolution, intervention/sticky assignment lookup, reward lookup, and policy snapshot using replacement indexes.
  - Command(s): `mix test test/oli/experiments test/oli/delivery/experiments test/oli/analytics/xapi`
- Definition of Done:
  - All domain, runtime, worker, analytics, and public-interface paths use singular experiment ownership against the final schema, with no compatibility adapters or old storage dependencies.
- Gate:
  - Gate N — domain/runtime/analytics/security review confirms singular ownership, concurrency safety, correct index use, and complete caller migration.
- Dependencies:
  - Gate M.
- Parallelizable Work:
  - Analytics contract cleanup and pure request/view refactors can proceed in parallel after migration field names are fixed; shared `Oli.Experiments` query work must have one owner.

## Phase 15: Simplify Authoring and Reporting UI

- Goal: Present one experiment-owned Alternatives Group and policy configuration without repeatable decision-point cards (FR-001 through FR-003, FR-017, FR-028, FR-032).
- Tasks:
  - [ ] Flatten LiveView draft state and form parsing to singular group, mappings, weights, priors, and guardrails.
  - [ ] Keep assignment policy creation-only and read-only afterward; retain weighted-random automatic-placement information and Thompson intervention/assessment controls.
  - [ ] Flatten non-draft reporting to one condition table and one policy snapshot while retaining posterior labels, evidence counts, observed shares, guardrail mode, lifecycle state, and refresh behavior.
  - [ ] Remove point add/remove/reorder controls, point titles/positions, point-scoped error copy, and point IDs from DOM/test contracts.
- Testing Tasks:
  - [ ] Update LiveView tests for singular creation/edit/save/reload, validation, lifecycle freezing, direct archive, weighted-random helper copy, Thompson bindings, and non-draft reporting.
  - [ ] Perform manual responsive, keyboard, focus, and screen-reader checks on the simplified configuration card.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs`
- Definition of Done:
  - Authors configure and understand one group/policy scope per experiment with no decision-point terminology or controls.
- Gate:
  - Gate O — UI and accessibility review confirms the simplified surface preserves all supported authoring and reporting workflows.
- Dependencies:
  - Gate N's singular public authoring/reporting contracts.
- Parallelizable Work:
  - Copy and accessibility review can proceed alongside test updates once the singular component structure is stable.

## Phase 16: Integrated Reconciliation and Final Verification

- Goal: Remove remaining multi-point assumptions and prove the complete authoring-to-delivery workflow under the final model (FR-001 through FR-035).
- Tasks:
  - [ ] Update scenario hooks/YAML, export/ingest, Alternatives strategy integration, completion, analytics projections, runbooks, and work-item designs to use experiment/intervention terminology.
  - [ ] Remove obsolete decision-point schemas, helpers, fixtures, and references left after the Phase 13 schema replacement and Phase 14 caller migration.
  - [ ] Re-run requirements traceability and record exact implementation/test proof for the changed FR-001, FR-002, FR-003, FR-007, FR-009, FR-010, FR-018, FR-021, FR-032, and new FR-035 contracts.
  - [ ] Run required Elixir, UI, security, performance, and requirements reviews and resolve all blocking findings.
- Testing Tasks:
  - [ ] Run focused suites, repeated-intervention Thompson scenario, PostgreSQL and ClickHouse up/down schema verification, formatting, compilation, and broader experiment-adjacent regression suites.
  - Command(s): `mix format`, `mix compile`, `mix test test/oli/experiments test/oli/delivery/experiments test/oli_web/live/workspaces/course_author/experiments_live_test.exs`
- Definition of Done:
  - Canonical docs, schemas, code, UI, evidence, scenarios, and tests consistently model one experiment policy scope with many interventions and contain no unsupported multi-point behavior.
- Gate:
  - Gate P — full traceability and review sign-off approve handoff/release readiness.
- Dependencies:
  - Gates M, N, and O.
- Parallelizable Work:
  - Documentation reconciliation, scenario updates, analytics verification, and review lenses may run concurrently after the implementation contracts stabilize.

## Parallelization Notes

- The current critical path is Gate M singular schema replacement → Gate N singular domain/runtime implementation → Gate O UI/reporting simplification → Gate P integrated final verification.
- Phase 6 UI slices may begin after stable Phase 3 APIs and approved design guidance; posterior reporting waits for Phase 5's final state/count contract.
- Phase 7 interop and analytics can begin after Phase 2 canonical schemas/events are fixed and can run alongside most Phase 6 UI work.
- Assign one owner to each shared boundary (`Oli.Experiments` public APIs, policy-state codec, Alternatives strategy normalization, and evidence schema) to prevent parallel slices from introducing competing contracts.
- Merge migration-owning work in dependency order. Rebase later schema consumers on the finalized generated migration names rather than duplicating migrations.
- Gates A through L record earlier feature checkpoints. Gate P is the sole release-ready boundary for the canonical single-scope model; Gates M through O are implementation checkpoints within the coordinated QA cutover.
- Keep exhaustive concurrency and boundary cases in targeted tests; use scenarios only for the two high-value cross-domain workflows described in Phase 8.

## Acceptance-Criteria Traceability

- Phase 13 proves AC-026 and AC-035 through PostgreSQL and ClickHouse forward/rollback schema tests, final constraint/index assertions, and existing Alternatives content compatibility checks.
- Phase 3 proves AC-001, AC-002, AC-003, AC-004, AC-011, AC-012, AC-017, AC-018, AC-019, and AC-020 through configuration, constraint, lifecycle, authorization, and history tests.
- Phase 4 proves AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-019, AC-021, AC-022, AC-027, and AC-034 through identity, policy, concurrency, delivery-query, rendering, preview, completion, and Alternatives non-nesting tests.
- Phase 5 proves AC-011, AC-012, AC-013, AC-014, AC-015, and AC-016 through attempt-order, threshold, attribution, transaction, concurrency, replay, and asynchronous handoff tests.
- Phase 6 proves AC-004, AC-017, AC-021, AC-028, AC-029, AC-030, AC-032, and the UI portions of AC-033 through context, LiveView, component, accessibility, and JSON Schema tests.
- Phase 7 proves AC-023, AC-024, AC-025, AC-026, AC-031, and the interop/evidence portions of AC-033 through migration, compatibility, export/ingest, analytics, privacy, and telemetry tests.
- Phase 8 supplies workflow-level proof for AC-005, AC-007, AC-009, AC-010, AC-013, AC-014, AC-016, AC-021, AC-022, and AC-023.
- Phase 16 confirms that AC-001 through AC-035 each has linked implementation and passing test evidence before release readiness.

## Phase Gate Summary

- Gate A: Runtime identity, attempt lifecycle, query baseline, analytics schema, detailed slice boundaries, and the best-effort Torus-native UI approach are confirmed.
- Gate B: Backward-compatible PostgreSQL/ClickHouse persistence and canonical strategy normalization apply and roll back safely.
- Gate C: Authorized draft configuration, activation validation, lifecycle immutability, dependency protection, and sequential reuse are proven.
- Gate D: Intervention-scoped assignment, bounded delivery, rendering, preview, edit identity, and visible-only completion are proven.
- Gate E: Assessment-driven reward processing is asynchronous, deterministic, atomic, idempotent, and concurrency-safe.
- Gate F: Strategy-specific authoring, experiment configuration/reporting, accessibility, and the versioned Alternatives schema meet the final contract.
- Gate G: Export/ingest, evidence, telemetry, privacy, legacy compatibility, and analytics migration behavior are proven.
- Gate H: Real multi-learner authoring-to-delivery scenarios prove completion and posterior reuse across repeated interventions.
- Gate I: Superseded historical checkpoint; Gate P is required for release readiness.
- Gate M: The singular PostgreSQL and ClickHouse schemas apply and roll back correctly, are indexed and constrained, and limit destructive behavior to disposable QA experiment data.
- Gate N: Singular domain/runtime contracts are authorized, concurrency-safe, index-backed, and free of decision-point compatibility paths.
- Gate O: Singular authoring and reporting UI is accessible, understandable, and complete.
- Gate P: Singular storage, code, UI, workflows, reviews, migrations, and regression suites pass; this is the sole release-ready gate.

## Decision Log

### 2026-08-13 - Replace QA experiment storage without backfill

- Change: Replaced the expand/backfill, dual-compatible cutover, and later contraction sequence with a direct singular schema replacement followed by direct caller migration and final reconciliation.
- Reason: The epic is deployed only in QA, and preservation of existing experiment rows is a non-goal.
- Evidence: Explicit deployment-scope clarification for Phase 13.
- Impact: PostgreSQL and ClickHouse migrations remain mandatory and reversible at the schema level, but no data transformation, mixed-version verification, or historical experiment-row preservation work is planned.

### 2026-08-13 - Plan the single-scope schema collapse

- Change: Added Phases 13 through 16 for persistence collapse, domain/runtime simplification, UI flattening, and integrated reconciliation.
- Reason: The canonical model now treats interventions—not independently optimized decision points—as the useful multiple exposure locations within one experiment.
- Evidence: `design/single_decision_point_analysis.md`, updated PRD/FDD/requirements, and code/schema waypointing.
- Impact: Implementation handoff begins at Gate M and must complete the phases in dependency order before the feature is considered done.

### 2026-08-13 - Remove duplicated decision-point algorithms

- Change: Added Phase 12 to remove the decision-point algorithm column and derive policy exclusively from the experiment definition.
- Reason: Copying an immutable experiment-level value to every decision point adds storage and a consistency invariant without adding information.
- Evidence: Generated reversible migration, schema/query refactor, and focused configuration/runtime verification.
- Impact: Decision points retain policy parameters, while policy state retains an algorithm identity for state-version dispatch.

### 2026-08-13 - Move assignment policy to experiment scope

- Change: Added the follow-up implementation task to enforce one immutable creation-time experiment assignment policy.
- Reason: Per-decision-point algorithm selection conflicts with the intended experiment-wide assignment strategy.
- Evidence: Updated PRD, FDD, requirements, form contract, validation, persistence, and tests.
- Impact: Decision points no longer expose policy selection and continue to own policy-specific parameters and state, with redundant policy persistence removed in Phase 12.

### 2026-08-11 - Retain readable condition codes

- Change: Phase 2 retains condition codes and adds locked, deterministic generation plus experiment-scoped uniqueness.
- Reason: Full removal would expand the work across established policy, delivery, reward, analytics, and test contracts.
- Evidence: The persistence design documents the current code usage and the bounded generation algorithm.
- Impact: Phase 2 preserves legacy IDs/codes, tests collision handling and immutability, and keeps policy/evidence keyed by code while mappings continue to use condition IDs.

### 2026-08-13 - Add weighted-random delivery discovery follow-up

- Change: Added Phase 10 to remove author-managed weighted-random interventions and lazily materialize valid delivered placements.
- Reason: Assessment binding is the reason to configure adaptive interventions in advance; weighted random has no corresponding authoring requirement.
- Evidence: Updated PRD/FDD/requirements and implementation tasks in this plan.
- Impact: Phase 10 changes activation, delivery assignment, authoring UI, and focused verification without changing Thompson Sampling reward behavior or the intervention persistence schema.
