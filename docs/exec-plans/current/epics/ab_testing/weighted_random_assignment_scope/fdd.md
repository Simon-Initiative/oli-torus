# Weighted Random Assignment Scope - Functional Design Document

## 1. Executive Summary

Add a typed `assignment_scope` to experiment definitions with two values: `intervention` and `section_enrollment`. Existing experiments remain `intervention`; new weighted-random experiments default to `section_enrollment`. Thompson Sampling defaults to and requires `intervention`.

`Oli.Experiments` will derive one internal assignment identity from the experiment configuration and delivery scope. Intervention scope continues to persist one assignment for `(experiment_id, intervention_id, enrollment_id)`. Section-and-enrollment scope persists one canonical assignment for `(experiment_id, section_id, enrollment_id)` with no owning intervention. Two partial unique indexes and a row-shape check make both identities concurrency-safe. Existing advisory transaction locks remain an optimization and ordering mechanism; database uniqueness remains the final arbiter.

Assignments and exposures become explicitly separate identities. Assignment evidence carries `assignment_scope` and may omit `intervention_id`. Every exposure request carries the encountered page placement, which `Oli.Experiments` resolves to an intervention belonging to the assignment's experiment before emitting intervention-specific evidence. This satisfies FR-001 through FR-013 and AC-001 through AC-013 without changing page content, section participation, condition mapping, Thompson Sampling rewards, or publication semantics.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001 and AC-001 add author-configurable weighted-random assignment scope with section-and-enrollment as the default for new experiments.
  - FR-002 and AC-002 keep section-and-enrollment scope unavailable to Thompson Sampling at create, update, activation, and runtime validation boundaries.
  - FR-003, FR-004, AC-003, and AC-004 define one canonical experiment assignment reused across all eligible interventions for an enrollment in a participating section.
  - FR-005 and AC-005 preserve independent sticky assignment per intervention as the existing behavior.
  - FR-006 and AC-006 require concurrent first encounters, including encounters at different interventions, to converge and increment assignment counts once.
  - FR-007, FR-012, AC-007, and AC-012 separate assignment identity from intervention-specific exposure and analytics evidence.
  - FR-008 and AC-008 preserve existing assignments and make assignment scope a structural, draft-only setting.
  - FR-009 and AC-009 retain section-participation gating before assignment creation, reuse, or evidence.
  - FR-010 and AC-010 expose accessible authoring controls and read-only details copy.
  - FR-011 and AC-011 require indexed, bounded single-placement and page-batch delivery operations.
  - FR-013 and AC-013 require generated, reversible, dependency-safe PostgreSQL migration work.
- Non-functional requirements:
  - PostgreSQL remains the synchronous source of truth; xAPI and ClickHouse never participate in assignment selection.
  - Runtime queries remain bounded by the number of placements and conditions on the delivered page and never scan event or reward history.
  - Authorization and lookup boundaries retain project, participating section, enrollment, and user checks.
  - Assignment and exposure payloads remain privacy-minimized and contain stable identifiers rather than learner responses.
  - The authoring control follows established accessible LiveView form behavior and WCAG 2.1 AA expectations.
- Assumptions:
  - Enrollment IDs are section-specific, but `section_id` remains part of canonical identity and evidence for explicit scoping and auditability.
  - Experiment condition and option mappings are global to the experiment, so one assigned condition is valid at every compatible intervention.
  - Existing context update behavior already limits structural experiment edits to draft; `assignment_scope` uses that lifecycle boundary and requires no separate assignment-existence query because runtime assignments can be created only after activation.
  - Pausing, completing, or archiving preserves assignments. An inactive experiment does not create or return assignments through learner delivery.
  - Existing experiment rows receive `intervention` through a database default; no assignment rows are rewritten or consolidated.
  - No feature flag is introduced for this work item.

## 3. Repository Context Summary

- What we know:
  - `Oli.Experiments.CreateExperimentRequest`, `UpdateExperimentRequest`, the public `ExperimentDefinition`, and `Schemas.ExperimentDefinition` currently carry `assignment_unit: :enrollment`; assignment scope is not represented.
  - `Schemas.Assignment` currently requires `intervention_id`, and `experiment_assignments_intervention_sticky_idx` enforces intervention/enrollment stickiness.
  - `Oli.Experiments.assign_condition/1`, `assigned_condition/1`, and `assign_page_conditions/1` are the public delivery boundaries. `RuntimeAssignment` orchestrates validation and delegates persistence work back into `Oli.Experiments`.
  - Single assignment uses `find_assignment/2`, `select_condition/5`, `create_assignment/3`, an experiment advisory transaction lock, and the unique index conflict as the concurrency arbiter.
  - Page assignment bulk-materializes weighted-random interventions, loads experiment/condition/policy/assignment rows, locks experiment IDs in sorted order, and reduces placements inside one transaction.
  - Weighted random is deterministic over `assignment_key`; current intervention keys contain experiment, intervention, and enrollment.
  - `ExperimentControlledStrategy` constructs both assignment and exposure requests. Current exposure requests do not include placement identity, and their keys collide across interventions if one assignment ID is reused.
  - `XAPI.Attributions.assignment_attrs/1` currently obtains `intervention_id` only from the assignment row. ClickHouse projection and uploader paths consume experiment attribution fields.
  - Section participation is checked before learner assignment paths and remains authoritative for applicability.
- Unknowns to confirm:
  - None block the design. Exact UI component selection and final product copy can be resolved during implementation using existing experiment form patterns; they do not change the domain contract.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `Oli.Experiments.Schemas.ExperimentDefinition` owns the persisted enum and default for `assignment_scope`.
- `CreateExperimentRequest`, `UpdateExperimentRequest`, and the public `ExperimentDefinition` carry the typed scope across the context boundary.
- `Oli.Experiments` configuration and activation validation enforce the algorithm/scope matrix and structural immutability. LiveViews submit intent and render returned errors but do not implement domain rules.
- A private assignment-identity helper under `Oli.Experiments` maps an experiment, intervention, and validated delivery `Scope` to one of:
  - `%{scope: :intervention, experiment_id: id, intervention_id: id, section_id: id, enrollment_id: id}`;
  - `%{scope: :section_enrollment, experiment_id: id, intervention_id: nil, section_id: id, enrollment_id: id}`.
- Single and batch assignment code consume that identity for lookup, deterministic policy input, insert attributes, conflict reload, and telemetry. Callers never construct database keys.
- `ExperimentControlledStrategy` continues to provide page resource and content-element identity for every placement. Exposure requests add those fields and generate placement-specific idempotency keys.
- `Oli.Experiments` resolves exposure placement identity to `experiment_interventions`, verifies that it belongs to the assignment's experiment, and passes the resolved intervention to `XAPI.Attributions`.
- xAPI attribution and ClickHouse projection code distinguish the canonical assignment scope from the encountered exposure intervention.
- `ExperimentsLive` and `ExperimentDetailsLive` render the weighted-random selector, help, validation, and saved read-only scope using the established course-author surface.

### 4.2 State & Data Flow

Authoring flow:

1. A new weighted-random experiment form defaults `assignment_scope` to `section_enrollment`; Thompson Sampling resolves to `intervention`.
2. Weighted-random authors may select `section_enrollment`; Thompson Sampling does not offer an editable broader-scope choice.
3. Create/update normalization converts accepted string input to the enum and rejects unknown values.
4. Context validation checks the algorithm/scope matrix. Updates require draft state, which is revalidated under the experiment lock before persistence.
5. Activation revalidates the matrix under the existing experiment transaction/lock so an invalid persisted combination cannot become active.

Single-placement delivery flow:

1. Existing participation, publication, placement, group, active-experiment, intervention, and condition validation runs unchanged.
2. The context derives assignment identity from the active experiment and validated delivery scope.
3. Lookup uses the matching indexed identity. For `section_enrollment`, the supplied intervention still proves applicability but is not part of assignment lookup.
4. If no assignment exists, weighted random receives a deterministic key matching the identity:
   - existing intervention format remains unchanged for backward compatibility;
   - section-and-enrollment format is versioned and explicit, for example `v2:experiment:<id>:section:<id>:enrollment:<id>`.
5. Insert stores the identity and assignment scope. A uniqueness conflict reloads by the same identity and returns the winning condition.
6. Assignment count increments only after a successful insert. Reuse and conflict paths do not increment it.

Page-batch delivery flow:

1. Weighted-random interventions are materialized as today because placement identity is still needed for applicability and exposure.
2. The batch row query left-joins either the intervention assignment or canonical section/enrollment assignment according to `experiment.assignment_scope`.
3. The reducer carries a transaction-local map keyed by derived assignment identity in addition to decisions, condition counts, and deferred telemetry events.
4. A successful canonical insert is placed in that map. Later placements for the same experiment and enrollment reuse it without resampling or intentionally causing another unique conflict.
5. The unique index remains authoritative for cross-request concurrency; conflicts reload the canonical row.
6. Every placement receives a decision containing the same assignment ID and condition in section-and-enrollment mode, but each later produces its own exposure request.

Read-only lookup flow:

1. `assigned_condition/1` resolves active experiment applicability and assignment scope before filtering assignment rows.
2. It does not use an unscoped “latest assignment” query. It selects only the identity appropriate to the matched active experiment.
3. Nonparticipating or ineligible sections retain the existing no-experiment response and emit no evidence.

Exposure flow:

1. `RecordExposureRequest` carries `page_resource_id` and `content_element_id` in addition to assignment and delivered revision identity.
2. The exposure key contains assignment ID plus stable placement identity, preventing two interventions from collapsing to one idempotency key when they share an assignment.
3. Single and page-batch exposure validation resolve `(assignment.experiment_id, page_resource_id, content_element_id)` to an intervention and verify the Alternatives revision belongs to the experiment's group.
4. Attribution merges `assignment_scope` and canonical assignment fields with the resolved exposure `intervention_id` and an `intervention_key` derived from stable placement identity.
5. Assignment evidence for section-and-enrollment scope omits `intervention_id`; exposure evidence always contains it.

### 4.3 Lifecycle & Ownership

- Experiment definition owns the configured assignment scope.
- Assignment owns the durable condition decision for exactly one configured assignment identity and stores an immutable scope snapshot.
- Intervention continues to own logical placement identity and remains required for every applicable placement, even when it does not own the canonical assignment.
- Exposure owns the observation that a canonical assignment was rendered at one particular intervention and delivered revision.
- Policy state owns aggregate assignment counts. A section-and-enrollment assignment contributes once regardless of how many interventions expose it.
- Assignment scope is structural and editable only in draft. Activation, pause, completion, and archival never rewrite it.
- Existing experiment and assignment rows remain intervention-scoped. Publication or page revision changes do not change either assignment identity.

### 4.4 Alternatives Considered

- Use one assignment row per intervention but omit intervention from the weighted-random seed: rejected because later weight changes could make not-yet-visited interventions diverge, assignment counts would represent placements rather than participants, and several rows would claim to represent one product assignment.
- Add an experiment-level parent assignment plus child intervention assignments: rejected because child rows duplicate the condition decision and add synchronization, deletion, and analytics complexity without a requirement for separate child state. Exposure evidence already represents intervention observations.
- Reuse `assignment_unit`: rejected because the unit remains an enrollment in both modes. The new choice controls where that enrollment assignment is scoped, so a separate `assignment_scope` is clearer and avoids changing established semantics.
- Infer section-and-enrollment rows only from nullable `intervention_id`: rejected as the sole discriminator because explicit scope improves validation, evidence, query clarity, and historical auditability. Nullability remains constrained to match the stored scope.
- Trust application locks without database uniqueness: rejected because locks are not a durable integrity boundary and conflict-safe retries must work across nodes and future code paths.

## 5. Interfaces

- `CreateExperimentRequest` adds optional `assignment_scope: :intervention | :section_enrollment`; the context resolves omission to `:section_enrollment` for weighted random and `:intervention` for Thompson Sampling.
- `UpdateExperimentRequest` adds optional `assignment_scope: :intervention | :section_enrollment`.
- Public `ExperimentDefinition` adds `assignment_scope` for forms, details, and approved read clients.
- `assign_condition/1`, `assigned_condition/1`, and `assign_page_conditions/1` retain their public request shapes. Placement identity remains mandatory even for section-and-enrollment scope because it proves intervention applicability and feeds exposure.
- `AssignmentDecision` need not expose assignment scope or intervention identity for rendering. Telemetry obtains scope from the persisted assignment/experiment, keeping delivery selection consumers minimal.
- `RecordExposureRequest` adds required `page_resource_id` and `content_element_id`. These are server-derived values and are validated rather than trusted.
- `record_exposure/1` and `record_page_exposures/1` retain their result shapes but require the enriched placement contract.
- Internal assignment identity helpers expose a single lookup/insert contract used by single, batch, and conflict paths; separate ad hoc key builders are removed.
- Assignment attribution adds `assignment_scope`. Exposure attribution adds `assignment_scope`, resolved `intervention_id`, and stable `intervention_key`.
- ClickHouse `experiment_attributions` adds or projects nullable/low-cardinality `assignment_scope` as appropriate for the existing schema conventions. Existing nullable `intervention_id` handling is retained or corrected so assignment events without an intervention remain valid.

## 6. Data Model & Storage

PostgreSQL migration, generated with `mix ecto.gen.migration`, uses explicit `up/0` and `down/0`:

- Add `experiment_definitions.assignment_scope`, non-null string, default `intervention`.
- Add a check constraint limiting definition values to `intervention` and `section_enrollment`.
- Add `experiment_assignments.assignment_scope`, non-null string, default `intervention`, as an immutable snapshot used for row constraints, evidence, and indexed lookup.
- Make `experiment_assignments.intervention_id` nullable.
- Replace `experiment_assignments_intervention_sticky_idx` with:
  - unique `(experiment_id, intervention_id, enrollment_id)` where `assignment_scope = 'intervention'`;
  - unique `(experiment_id, section_id, enrollment_id)` where `assignment_scope = 'section_enrollment'`.
- Add an assignment row-shape check:
  - intervention scope requires non-null `intervention_id`;
  - section-and-enrollment scope requires null `intervention_id`.
- Retain the global unique `assignment_key` index.
- Retain experiment/condition and experiment/intervention referential constraints; PostgreSQL permits the composite intervention foreign key when the nullable intervention component is absent.
- Add supporting lookup indexes only if query plans show the partial unique indexes do not cover the exact delivery predicates; do not duplicate equivalent indexes speculatively.

The experiment schema changeset casts and validates `assignment_scope`. The assignment changeset validates the enum and conditionally requires `intervention_id` according to scope, maps both unique constraint names, and maps the row-shape constraint to a bounded domain error.

The application enforces `section_enrollment` only with `weighted_random`; a normal row-level check cannot compare assignment rows to the parent experiment algorithm. Create, update, activation, and runtime matching all enforce this invariant. The assignment scope snapshot must equal the parent definition when inserted; assignment construction is private to `Oli.Experiments`.

ClickHouse changes follow the existing ordinary migration mechanism and preserve existing rows with nullable/defaulted `assignment_scope = 'intervention'` semantics. xAPI JSON remains forward-compatible because the new field is additive.

## 7. Consistency & Transactions

- Experiment create/update/activation retains existing context-owned transactions and locks. Scope/algorithm validation occurs inside those boundaries.
- Single assignment retains the experiment advisory transaction lock, but all lookup, insert, conflict reload, and assignment-count behavior uses one derived identity.
- Page batch locks distinct experiment IDs in sorted order, carries newly inserted assignments in transaction-local reducer state, and commits assignment decisions before emitting deferred telemetry.
- Partial unique indexes arbitrate cross-node and cross-request races. Conflict handling reloads by the exact derived identity; it never uses `assignment_key` parsing or a broad latest-row query.
- A successful canonical insert and assignment-count increment occur in the same outer assignment transaction. A uniqueness loser does not increment counts.
- Exposure recording validates assignment scope, learner delivery scope, intervention ownership, and revision compatibility before evidence emission. Exposure failure does not mutate or replace the assignment.
- xAPI/ClickHouse delivery remains post-commit and retryable; analytics sink failure never rolls back a learner assignment or rendered page.

## 8. Caching Strategy

- No process, distributed, or application cache is introduced for assignments or experiment configuration.
- The page-batch reducer's identity map is transaction-local computation, not durable cache, and prevents duplicate work only within one batch.
- Runtime correctness always reads current committed PostgreSQL state. Existing publication-pinned revision loading remains unchanged.

## 9. Performance & Scalability Posture

- Negative/nonparticipating delivery retains the existing bounded relevance and participation gates before assignment work.
- Single lookup is an indexed equality query against one partial unique index.
- Positive page-batch loading remains proportional to valid experiment placements and active conditions on the page. The join adds a scope branch but no history scan.
- Section-and-enrollment mode reduces assignment row growth from one row per enrollment/intervention pair to one row per enrollment/experiment/section tuple; exposure volume remains per render as intended.
- Assignment counts continue to group indexed experiment/condition rows and now correctly represent canonical assignments in either scope.
- Implementation verification must inspect generated SQL/query plans for both scope branches and cover a page containing multiple placements from the same experiment. AC-011 is satisfied only when no N+1 assignment reload or analytics-store access is introduced.
- Existing assignment duration and fallback telemetry remains the latency baseline; `assignment_scope` is added as bounded metadata for comparison in AppSignal.

## 10. Failure Modes & Resilience

- Unknown assignment scope: create/update/activation returns an invalid-condition error; delivery fails safely to established deterministic first-option fallback and emits bounded telemetry.
- Thompson Sampling with section-and-enrollment scope: rejected before activation and guarded again at runtime so malformed persisted state cannot create a global adaptive assignment.
- Missing intervention for intervention scope: assignment changeset and row-shape constraint reject insertion.
- Unexpected intervention on section-and-enrollment assignment: row-shape constraint rejects insertion.
- Cross-intervention first-encounter race: partial uniqueness chooses one canonical row; all losers reload and return its condition.
- Stale batch snapshot after a concurrent insert: insert conflict reloads by derived identity and updates the transaction-local identity map.
- Assignment exists but selected condition is unavailable in a placement: retain current mapping-compatibility failure and deterministic fallback; never resample a different condition.
- Exposure placement does not belong to the assignment's experiment: reject exposure with bounded invalid-condition telemetry; do not emit incorrectly attributed evidence.
- Exposure sink failure: log/telemetry and existing retry behavior apply without changing the assignment or learner-visible selection.
- Rollback with section-and-enrollment rows present: the `down/0` migration must either fail explicitly until such rows are absent or remove only pre-release feature rows under an explicitly documented deployment policy; it must never fabricate intervention ownership. Migration tests establish the selected safe behavior before release.

## 11. Observability

- Add `assignment_scope` to assignment-created, assignment-reused, concurrency-resolved, fallback, and invalid-configuration telemetry metadata.
- Add encountered `intervention_id` to exposure-recorded telemetry independently from assignment ownership.
- Preserve bounded identifiers: experiment, section, condition, algorithm, assignment scope, intervention where applicable, policy version, fallback reason, and duration.
- Do not log full requests, learner names, LMS identifiers, content bodies, responses, or raw xAPI payloads.
- AppSignal views should make assignment latency, conflicts, invalid scope combinations, missing canonical assignments, and exposure-attribution failures distinguishable by scope.
- Assignment evidence records one canonical assignment event. Reuse at later interventions is represented through intervention-specific exposure evidence rather than duplicate assignment rows or misleading participant counts.

## 12. Security & Privacy

- Authoring uses the existing accepted-author and administrative authorization enforced by experiment context APIs. The LiveView cannot bypass scope/algorithm validation.
- Delivery derives project, section, user, enrollment, publication, page, and placement values from server-resolved context. Client-provided IDs are not accepted as authority.
- Canonical lookup includes experiment, section, enrollment, and the already validated delivery user. Existing assignment ownership validation remains in evidence paths.
- Participation eligibility is checked before both new assignment and sticky reuse, preventing assignment leakage into unrelated or stale sections.
- Partial indexes and identity helpers prevent a user enrolled in two sections from sharing an assignment across those enrollments.
- xAPI and ClickHouse additions contain scope and stable IDs only. They add no learner response, name, email, LMS subject, or assessment content.
- Security review must verify cross-project, cross-section, cross-institution, forged-placement, and forged-assignment exposure requests for both scopes.

## 13. Testing Strategy

- Schema and migration tests:
  - Apply and roll back the generated migration and inspect constraints/indexes for AC-013.
  - Accept one valid row shape for each scope; reject mismatched nullability and duplicate identities.
  - Prove existing definitions and assignments read as intervention-scoped without data rewrite.
- Context/configuration tests:
  - Create weighted-random experiments with default and explicit scopes, update draft scope, reject unauthorized updates, reject unknown values, and display the public DTO for AC-001.
  - Reject Thompson Sampling plus section-and-enrollment on create, update, activation, and malformed runtime state for AC-002.
  - Reject scope changes outside draft for AC-008.
- Runtime assignment tests:
  - Create one canonical null-intervention assignment and reuse it across two placements for AC-003 and AC-004.
  - Preserve independent intervention rows and possible different conditions for AC-005.
  - Verify isolation between enrollments and between two sections for the same user.
  - Race first encounters at different interventions and assert one row, one policy-state count increment, one returned condition, and conflict telemetry for AC-006.
  - Exercise single, read-only, and page-batch paths, including multiple same-experiment placements and mixed experiments.
  - Verify participating, deselected, stale, and unrelated sections preserve fallback/evidence behavior for AC-009.
- Exposure and analytics tests:
  - Assert placement-specific keys do not collide for a shared assignment.
  - Assert assignment attribution carries `section_enrollment` and no intervention while two exposure attributions carry their distinct resolved interventions for AC-007.
  - Update ClickHouse uploader/query fixtures to count one participant assignment and multiple exposures for AC-012.
  - Reject exposure placement from another experiment or project.
- LiveView tests:
  - Verify default, selector labels/help, saved value, details display, field-level errors, draft editability, and Thompson visibility/disabled behavior for AC-010.
- Performance verification:
  - Capture queries for single and batch paths and assert bounded assignment query shape with no ClickHouse, xAPI-history, reward-history, or per-placement assignment N+1 for AC-011.
- Scenario coverage:
  - Use `Oli.Scenarios` for real authoring, publication, section participation, enrollment, and learner delivery across two interventions and multiple learners. Extend the scenario DSL only if current experiment directives cannot express scope or inspect the resulting assignments.
- Required review lenses:
  - Security and performance always; Elixir/Ecto, UI/accessibility, and requirements traceability apply to this implementation.

## 14. Backwards Compatibility

- Existing experiment definitions receive the non-null `intervention` default and preserve current behavior.
- Existing assignment rows receive the `intervention` snapshot and keep their intervention foreign keys and assignment keys unchanged.
- No historical assignment, exposure, xAPI, ClickHouse, page content, revision, or publication row is consolidated or rewritten.
- Public request callers that omit `assignment_scope` create section-and-enrollment-scoped weighted-random experiments and intervention-scoped Thompson Sampling experiments. Existing persisted rows remain intervention-scoped through the database default.
- Exposure callers inside the repository must adopt required placement fields atomically with the context contract change. This is an internal API without an external compatibility window.
- Existing xAPI rows without `assignment_scope` are interpreted as intervention-scoped where reporting needs a default; new evidence emits the explicit field.
- Rollback does not promise conversion of canonical experiment-level assignments to intervention-level assignments. The release procedure must validate the documented rollback precondition before reversing the schema.

## 15. Risks & Mitigations

- Shared assignment but colliding exposure keys: include stable page/element placement identity in every exposure key and validate it against the assignment's experiment.
- Batch path samples more than once before seeing its own insert: carry canonical assignments in transaction-local reducer state and retain uniqueness conflict reload for external races.
- Scope and nullable intervention drift apart: store an immutable assignment scope snapshot and enforce the row shape with a database check.
- Analytics counts exposures as participants: model assignment scope explicitly, count canonical assignment rows for participants, and use exposure events for intervention traffic.
- Algorithm changes create invalid scope combinations: preserve existing structural algorithm immutability and validate the matrix on create, update, activation, and runtime.
- Broad lookup returns another intervention's assignment in intervention mode: route every lookup and conflict reload through the derived identity helper.
- Rollback loses the meaning of canonical assignments: use an explicit rollback precondition or pre-release cleanup policy rather than inventing intervention ownership.
- UI wording implies course-wide identity beyond the section: name the boundary explicitly and show the saved scope on details.

## 16. Open Questions & Follow-ups

- No unresolved question blocks planning or implementation.
- During implementation, choose the exact existing form-control primitive and final reviewed copy for the two radio choices; preserve the PRD semantics and accessibility requirements.
- Before production rollout, choose and document the safe `down/0` precondition for environments containing section-and-enrollment assignments. This is an operational migration decision, not a product-semantics question.
- The earlier `intervention_assignment_thompson_sampling` documentation names course-wide sticky assignment as a non-goal and independent intervention assignment as universal behavior. A documentation-reconciliation task must update that wording to describe intervention scope as mandatory for Thompson Sampling and optional for weighted random, whose new default is section-and-enrollment scope.

## 17. References

- `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope/prd.md`
- `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/prd.md`
- `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/section_participation/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/fdd.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/runtime_assignment.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/schemas/assignment.ex`
- `lib/oli/experiments/xapi/attributions.ex`
- `lib/oli/resources/alternatives/experiment_controlled_strategy.ex`
- `docs/design-docs/publication-model.md`
- `docs/TESTING.md`
- `docs/OPERATIONS.md`
