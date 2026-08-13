# Intervention-Scoped Assignment and Assessment-Driven Thompson Sampling - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/requirements.yml`

## Scope

Extend `Oli.Experiments` so experiments own stable conditions and independently configured decision points, while each placed Alternatives instance is a distinct sticky assignment opportunity. Add assessment-driven, asynchronous Beta-Bernoulli Thompson Sampling rewards; preserve weighted-random behavior; make Alternatives Group strategy canonical and group-owned; preserve authoring, publication, delivery, completion, export/ingest, and legacy-content compatibility; and expose bounded policy reporting, analytics evidence, and operational telemetry.

Guardrails:

- PostgreSQL remains the transactional source of truth. Assignment, reward, and reporting paths must not read ClickHouse, xAPI, or reward history.
- Existing revisions, publications, assignments, rewards, and analytics remain readable without a feature-specific backfill, content rewrite, forced author save, or republication.
- New database migrations are generated with `mix ecto.gen.migration`, implement explicit `up/0` and `down/0`, avoid destructive cascades, and are verified forward and backward against representative existing data.
- Experiment mutation and lifecycle rules belong in `Oli.Experiments`; LiveViews and delivery modules remain interaction and transport adapters with server-derived authorization and identity.
- Both Alternatives strategies may appear inside ordinary containers, but no Alternatives placement may have another Alternatives placement as an ancestor. Delivery pays only one indexed relevance check for sections without an applicable active experiment and resolves all valid positive-path experiment placements in one set-based operation without recursive assignment rounds.
- Preview never creates experiment state or evidence. Learner rendering and completion use the same persisted intervention decisions.
- New UI uses existing components and Tailwind conventions. The current Experiments group editor is the behavioral baseline for the shared component. Produce approved design guidance before implementing the expanded experiment configuration and posterior-reporting UI.
- No feature flag is added. Rollout is gated by migration safety, valid draft activation, and normal deployment.
- All phases form one indivisible unit of work. Each phase receives a focused code review at its gate, but no phase is deployed, released, or treated as independently shippable; production rollout occurs only after Gate I confirms the complete implementation.
- Jira ticket creation or editing is a separate operation: draft exact ticket changes and obtain explicit user approval before any Jira write.

## Clarifications & Default Assumptions

- During Phase 1, confirm the canonical resource-attempt ordering column, the successfully finalized attempt predicate, nested Alternatives element-ID behavior across every copy/duplicate path, and the current ClickHouse event schema. These are implementation facts; if repository behavior differs from the FDD, update the detailed slice design before coding without changing the product requirements silently.
- Use dependency-ordered PostgreSQL migrations rather than one large migration unless inspection proves a combined migration is safer. Preserve legacy nullable rows while requiring complete intervention-scoped state for new writes.
- Replace the existing single-decision-point request and report shapes with the multi-point model in the same unit of work. Migrate every in-repository caller and remove the old shape and any temporary adapter before Gate I; no compatibility layer remains in the completed implementation.
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
  - [x] Refactor `Oli.Experiments` internals around focused configuration operations while preserving it as the public boundary; migrate all in-repository callers to the multi-point request/report contracts and delete the legacy single-point shape without adding an adapter.
  - [x] Add experiment-owned condition and per-decision-point configuration APIs for group binding, algorithm/guardrails, bijective mappings, interventions, distinct scored-page bindings, and inclusive decimal thresholds defaulting to `1.0`.
  - [x] Resolve request-local condition `client_ref` values during atomic graph creation, generate immutable readable codes from labels under the experiment lock with deterministic collision suffixes, and persist mappings by `condition_id`.
  - [x] Enforce `Scope` authorization, compatible project lineage, experiment-controlled group strategy, stable group/option identities, current-binding exclusivity, mapping cardinality, scored-page eligibility, and assessment exclusivity.
  - [x] Lock the experiment and sorted group resources for save/activation; reject invalid transitions and all prohibited non-draft structural mutations.
  - [x] Implement explicit dependency discovery/reconciliation for bound groups, interventions, and assessment pages; never silently cascade or retarget active history.
  - [x] Preserve completed/archived history and allow sequential group reuse only through a new draft decision point with independent state.
- Testing Tasks:
  - [x] Add context and changeset tests for valid multi-point configuration and every structured activation error, including duplicate/missing mappings and incompatible or simultaneously bound groups.
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
  - [x] Add a workflow proving sticky revisits, scored-page finalization, one accepted reward, posterior reuse by a later intervention, and isolation from a separate decision point.
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

## Phase 9: Final Verification, Review, and Rollout Readiness

- Goal: Demonstrate complete requirement coverage, migration safety, performance bounds, security/privacy posture, compatibility, and operational readiness before rollout (FR-001 through FR-034).
- Tasks:
  - [ ] Run the full targeted suite followed by broader experiment, delivery, attempt, publication, interop, analytics, LiveView, and scenario suites warranted by changed files.
  - [ ] Apply `mix format`, compile with warnings treated according to repository CI, and run frontend lint/format/tests for touched assets.
  - [ ] Repeat PostgreSQL and ClickHouse forward/rollback verification in dependency order against representative already-running QA state and confirm no content backfill or forced republication is required.
  - [ ] Re-measure negative and positive delivery query counts, assignment/reward boundedness, concurrency behavior, and policy snapshot queries against Phase 1 baselines.
  - [ ] Review changes using `.review/security.md` and `.review/performance.md` always, plus `.review/elixir.md`, `.review/ui.md`, `.review/typescript.md`, and `.review/requirements.md` when applicable; resolve all blocking findings.
  - [ ] Verify AppSignal event names/dimensions and prepare dashboard/alert and deployment-order notes, including worker compatibility during rolling deployment and rollback.
  - [ ] Reconcile PRD/FDD/plan/requirements proof artifacts if implementation drift occurred, then run harness requirement and work-item validation.
  - [ ] Search for and remove the legacy single-decision-point request/report shape, adapters, transitional branches, dead tests, and stale documentation; prove all callers use the multi-point contract.
  - [ ] If Jira updates are desired, draft the exact tickets/comments for separate user approval before running any `jira` write command; read back and verify formatting after approved writes.
- Testing Tasks:
  - [ ] Run targeted and relevant aggregate backend/LiveView/scenario tests, schema fixtures, migration verification, and frontend tests.
  - [ ] Confirm tests that intentionally emit logs use `@tag capture_log: true` or `capture_log/1` and that normal output is clean.
  - [ ] Produce a traceability report showing implementation and test evidence for every FR/AC pair.
  - Command(s): `mix format`; `mix compile`; `mix test <all affected suites>`; `cd assets && yarn test <affected suites>`; `cd assets && yarn lint`; `cd assets && yarn format`; `python3 <skills_root>/requirements/scripts/requirements_trace.py <work_item_dir> --action master_validate --stage implementation_complete`; `python3 <skills_root>/validate/scripts/validate_work_item.py <work_item_dir> --check all`
- Definition of Done:
  - All FR-001 through FR-034 and AC-001 through AC-034 have passing proof; every phase has completed focused code review; the integrated implementation passes final review; no legacy single-point compatibility layer remains; migrations and rollback are safe; performance and privacy guardrails hold; operational and deployment notes are ready.
- Gate:
  - Gate I — the entire work item validates at implementation-complete stage and is approved as one deployable unit without a feature flag, historical rewrite, legacy single-point compatibility layer, or unapproved external-system mutation. This is the only release boundary.
- Dependencies:
  - Gates B through H.
- Parallelizable Work:
  - Review lenses, documentation reconciliation, telemetry/deployment notes, and broad suite execution can run concurrently after all feature slices are integrated; final sign-off and any deployment wait for all results.

## Parallelization Notes

- The critical path is Phase 1 contract confirmation → Phase 2 persistence → Phase 3 configuration → Phase 4 assignment → Phase 5 reward processing → Phase 8 integrated scenarios → Phase 9 final verification.
- Phase 6 UI slices may begin after stable Phase 3 APIs and approved design guidance; posterior reporting waits for Phase 5's final state/count contract.
- Phase 7 interop and analytics can begin after Phase 2 canonical schemas/events are fixed and can run alongside most Phase 6 UI work.
- Assign one owner to each shared boundary (`Oli.Experiments` public APIs, policy-state codec, Alternatives strategy normalization, and evidence schema) to prevent parallel slices from introducing competing contracts.
- Merge migration-owning work in dependency order. Rebase later schema consumers on the finalized generated migration names rather than duplicating migrations.
- Treat Gates A through H as focused code-review checkpoints within one branch/unit of work. Only Gate I permits the complete feature to ship; intermediate phases must not be independently deployed or released.
- Keep exhaustive concurrency and boundary cases in targeted tests; use scenarios only for the two high-value cross-domain workflows described in Phase 8.

## Acceptance-Criteria Traceability

- Phase 3 proves AC-001, AC-002, AC-003, AC-004, AC-011, AC-012, AC-017, AC-018, AC-019, and AC-020 through configuration, constraint, lifecycle, authorization, and history tests.
- Phase 4 proves AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-019, AC-021, AC-022, AC-027, and AC-034 through identity, policy, concurrency, delivery-query, rendering, preview, completion, and Alternatives non-nesting tests.
- Phase 5 proves AC-011, AC-012, AC-013, AC-014, AC-015, and AC-016 through attempt-order, threshold, attribution, transaction, concurrency, replay, and asynchronous handoff tests.
- Phase 6 proves AC-004, AC-017, AC-021, AC-028, AC-029, AC-030, AC-032, and the UI portions of AC-033 through context, LiveView, component, accessibility, and JSON Schema tests.
- Phase 7 proves AC-023, AC-024, AC-025, AC-026, AC-031, and the interop/evidence portions of AC-033 through migration, compatibility, export/ingest, analytics, privacy, and telemetry tests.
- Phase 8 supplies workflow-level proof for AC-005, AC-007, AC-009, AC-010, AC-013, AC-014, AC-016, AC-021, AC-022, and AC-023.
- Phase 9 confirms that AC-001 through AC-034 each has linked implementation and passing test evidence before rollout.

## Phase Gate Summary

- Gate A: Runtime identity, attempt lifecycle, query baseline, analytics schema, detailed slice boundaries, and the best-effort Torus-native UI approach are confirmed.
- Gate B: Backward-compatible PostgreSQL/ClickHouse persistence and canonical strategy normalization apply and roll back safely.
- Gate C: Authorized draft configuration, activation validation, lifecycle immutability, dependency protection, and sequential reuse are proven.
- Gate D: Intervention-scoped assignment, bounded delivery, rendering, preview, edit identity, and visible-only completion are proven.
- Gate E: Assessment-driven reward processing is asynchronous, deterministic, atomic, idempotent, and concurrency-safe.
- Gate F: Strategy-specific authoring, experiment configuration/reporting, accessibility, and the versioned Alternatives schema meet the final contract.
- Gate G: Export/ingest, evidence, telemetry, privacy, legacy compatibility, and analytics migration behavior are proven.
- Gate H: Real multi-learner authoring-to-delivery scenarios prove completion and posterior reuse across repeated interventions.
- Gate I: Full traceability, formatting, compile/tests, per-phase and integrated reviews, legacy adapter removal, migration rollback, performance, security, and rollout readiness pass for the single complete release unit.

## Decision Log

### 2026-08-11 - Retain readable condition codes

- Change: Phase 2 retains condition codes and adds locked, deterministic generation plus experiment-scoped uniqueness.
- Reason: Full removal would expand the work across established policy, delivery, reward, analytics, and test contracts.
- Evidence: The persistence design documents the current code usage and the bounded generation algorithm.
- Impact: Phase 2 preserves legacy IDs/codes, tests collision handling and immutability, and keeps policy/evidence keyed by code while mappings continue to use condition IDs.
