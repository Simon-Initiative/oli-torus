# Experiment Section Participation - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/section_participation/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/section_participation/fdd.md`

## Scope
Deliver explicit per-experiment section participation for native A/B testing. The work reuses `experiment_sections`, makes an empty selected set mean no participation, supports active base-project and currently remixed sections, adds a transactional configuration API, enforces current participation across assignment and evidence paths, adapts the existing LiveView multi-select pattern, and verifies first-option fallback for every nonparticipating case.

Out of scope:
- Production data backfill or migration of native experiment audiences; the feature has not been deployed.
- Automatic enrollment of newly created or newly remixed sections.
- Per-section experiment definitions or instructor self-service participation.
- Template/product inheritance.
- A new analytics dashboard.
- A feature flag or compatibility mode preserving the old empty-means-project-wide behavior.

## Clarifications & Default Assumptions
- Zero selected sections is valid for draft, active, and paused experiments and means the experiment applies nowhere.
- Existing local/test experiment definitions with zero section rows may become nonparticipating; fixtures that expect assignment must select sections explicitly.
- Completed and archived experiments remain read-only.
- A section is eligible only when `status == :active` and a current `sections_projects_publications` row relates it to the experiment project.
- A stale join row remains visible but inert until the researcher saves the configuration; saving replaces the complete set and removes stale rows that are not resubmitted.
- If a stale row becomes eligible again before removal, it participates again. This remains an explicit product follow-up rather than requiring new persistence state in this work.
- Current assignments and analytics history are retained after deselection; no new assignment reuse or experiment evidence is allowed.
- The first UI implementation adapts `OliWeb.Common.MultiSelectInput`. A searchable modal may replace the presentation later without changing the context API.
- Telemetry, code review, and Jira execution tracking follow normal repository workflow. No Jira mutation is part of this document task.

## Phase 1: Eligibility Boundary And Empty-Participation Semantics
- Goal: Establish one project/remix-aware eligibility boundary and change experiment scoping so no `experiment_sections` rows means no participation for FR-002, FR-004, FR-005, FR-007, AC-002, AC-004, AC-005, and AC-007.
- Tasks:
  - [x] Add an A/B testing-facing eligible-section query built from `sections_projects_publications`, `Section.status == :active`, project scope, and distinct section IDs.
  - [x] Return authoring-safe section summaries with stable ID, slug, title, status, and approved disambiguating metadata.
  - [x] Keep participation eligibility separate from the existing base-project-only `validate_section_scope/2`; do not weaken general experiment scope validation.
  - [x] Introduce a private canonical participating-section Ecto predicate/subquery requiring experiment membership, active section status, and a current project relationship.
  - [x] Remove `NOT EXISTS (experiment_sections) OR matching membership` semantics from experiment scope helpers and require a valid matching membership row.
  - [x] Update project-authoring list/read queries so they list experiments by project without treating missing section rows as a special authoring scope.
  - [x] Update existing test factories/helpers that expect runtime assignment to create explicit `experiment_sections` rows.
  - [x] Confirm existing indexes on `experiment_sections` and `sections_projects_publications` support the new query; add a targeted index only if query inspection shows a gap.
- Testing Tasks:
  - [x] Add context tests for active base-project, current-remix, inactive, removed-remix, unrelated, missing, and cross-institution section eligibility.
  - [x] Add regression tests proving an experiment with zero section rows applies nowhere and returns controlled no-experiment behavior.
  - [x] Add tests proving project authoring can still list/read an experiment with zero selected sections.
  - [x] Add query-shape or `EXPLAIN` evidence for the delivery membership predicate if a new index is considered.
  - Command(s): `mix test test/oli/delivery/sections_test.exs test/oli/experiments/context_test.exs test/oli/experiments/runtime_test.exs`
- Definition of Done:
  - One tested eligibility/predicate implementation represents active original and current-remix participation.
  - Empty participation no longer acts as a wildcard in any scoped experiment lookup.
  - Project-authoring reads remain independent of selected section count.
- Gate:
  - Phase 1 is complete only when AC-002, the empty portion of AC-004/AC-005, and scope rejection in AC-007 pass without an unbounded or N+1 query.
- Dependencies:
  - Existing `experiment_sections`, `sections_projects_publications`, `Oli.Experiments`, and section status conventions.
- Parallelizable Work:
  - The controlled-input API and accessibility changes for `MultiSelectInput` may be prototyped in parallel, but experiment integration must wait for the Phase 2 DTO/command contract.

## Phase 2: Participation Read/Write APIs And Transactional State
- Goal: Expose authorized, lifecycle-safe participation configuration with atomic replacement, stale-state visibility, and telemetry for FR-001, FR-003, FR-007, AC-001, AC-003, and AC-007.
- Tasks:
  - [x] Add public authoring DTOs such as `EligibleExperimentSection` and `ExperimentSectionParticipation` without leaking Ecto schemas.
  - [x] Add `Oli.Experiments.list_eligible_sections/1` or the agreed equivalent using the Phase 1 query.
  - [x] Add `get_section_participation/2` to return eligible selected/unselected summaries and stale selected summaries for a scoped experiment.
  - [x] Add a dedicated `update_section_participation/3` command for draft, active, and paused experiments; reject completed and archived experiments.
  - [x] Normalize duplicate IDs and reject the whole request when any submitted ID is missing, inactive, unrelated, cross-tenant, or otherwise inaccessible.
  - [x] Lock the experiment definition, revalidate eligibility in the transaction, replace the complete join set, reload the association, and preserve the prior set on any failure.
  - [x] Keep `CreateExperimentRequest.section_ids` and draft graph updates compatible with explicit selected lists while making `nil`/`[]` mean none for project-authoring requests.
  - [x] Emit participation update and validation-failure telemetry using IDs, state, and counts without section titles, learner identity, or raw payloads.
- Testing Tasks:
  - [x] Add tests for empty/non-empty independent selection sets across multiple experiments.
  - [x] Add tests for duplicate normalization, deselection, stale presentation, stale removal on save, forged IDs, completed/archived rejection, and rollback on invalid input.
  - [x] Add a concurrency test proving experiment-row serialization and duplicate-free last-committed selection.
  - [x] Add telemetry handler tests for safe update and validation-failure metadata.
  - Command(s): `mix test test/oli/experiments/context_test.exs`
- Definition of Done:
  - Authorized callers can read and atomically replace an experiment's selected section set.
  - Stale rows are visible but cannot count as active participation.
  - Invalid or concurrent updates cannot create partial or duplicate state.
- Gate:
  - Phase 2 is complete only when AC-001, AC-003, and authoring-command coverage for AC-007 pass, including concurrency and rollback tests.
- Dependencies:
  - Phase 1 eligibility query and canonical predicate.
- Parallelizable Work:
  - Generic `MultiSelectInput` accessibility/unit work may proceed after the DTO fields and selected-ID contract are agreed.

## Phase 3: Runtime And Evidence Enforcement
- Goal: Enforce current participation consistently across assignment, sticky reuse, fallback, exposure, outcome, reward, policy updates, and scoped analytics reads for FR-004, FR-005, FR-006, AC-004, AC-005, and AC-006.
- Tasks:
  - [x] Apply the canonical participating-section predicate to active experiment matching.
  - [x] Apply the predicate to sticky assignment lookup so an existing assignment is not reused after deselection or eligibility loss.
  - [x] Audit and update exposure recording to reject or skip nonparticipating delivery before xAPI evidence is emitted.
  - [x] Audit and update outcome/reward eligibility queries to require current participation before reward or policy-state mutation.
  - [x] Ensure Thompson Sampling policy updates cannot occur from a reward received after section deselection or eligibility loss.
  - [x] Apply participation scope to experiment analytics/read helpers without excluding project-authoring management reads.
  - [x] Preserve historical assignment records and previously emitted analytics evidence after participation ends.
  - [x] Return the existing `AssignmentDecision{status: :no_experiment}` path for nonparticipation so decision points render the first option.
  - [x] Add distinct operational fallback/rejection reasons such as `:section_not_participating` and `:section_no_longer_eligible`, without emitting learner experiment events.
- Testing Tasks:
  - [x] Prove selected eligible sections receive new assignments and reuse sticky assignments.
  - [x] Prove zero-row, unselected, inactive, removed-remix, and deselected sections return first-option fallback.
  - [x] Prove a preexisting assignment is not reused after participation ends.
  - [x] Prove no new assignment, exposure, outcome, reward, policy update, or experiment xAPI evidence is created outside current participation.
  - [x] Cover deselection between assignment/exposure and later reward processing while retaining prior history.
  - [x] Add telemetry assertions for participation-related fallback/rejection reasons and privacy-safe metadata.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/context_test.exs test/oli/delivery/experiments/reward_handoff_test.exs`
- Definition of Done:
  - Every experiment evidence path uses current selected-and-eligible participation.
  - Nonparticipating learners consistently receive the first option.
  - Historical evidence remains intact while future evidence and policy mutation stop.
- Gate:
  - Phase 3 is complete only when AC-004, AC-005, and AC-006 pass across weighted-random and Thompson Sampling paths.
- Dependencies:
  - Phase 1 canonical predicate and Phase 2 persisted selection semantics.
- Parallelizable Work:
  - Phase 4 component work can continue in parallel, but the experiment configuration submit flow should not be enabled until Phase 2 is stable.

## Phase 4: Accessible Experiment Configuration UI
- Goal: Let authorized researchers create and edit section participation through the course-author experiment page using a reusable, accessible selection control for FR-001, FR-002, FR-003, FR-007, AC-001, AC-002, AC-003, and AC-007.
- Tasks:
  - [x] Extend `OliWeb.Common.MultiSelectInput` to accept source-controlled initial selected IDs/options and preserve them across LiveView updates and validation rerenders.
  - [x] Preserve existing `on_select_message` behavior for Insights consumers and add form serialization or parent-owned hidden fields for experiment `section_ids`.
  - [x] Add semantic trigger behavior, labels, `aria-expanded`, `aria-controls`, deterministic option IDs, keyboard operation, visible focus, and accessible checkbox/error states.
  - [x] Add selected-section chips or equivalent summary and clear empty-selection copy stating that learners receive the first choice.
  - [x] Load eligible section summaries when mounting or opening experiment configuration, sorted deterministically and disambiguated by approved metadata.
  - [x] Add section selection to the experiment creation modal and link each experiment title to
    a dedicated configuration page with details and a paginated participating-sections table.
  - [x] Render selected stale sections separately with an explanation that they no longer participate and can be removed on save.
  - [x] Hide or disable mutation controls for completed/archived experiments and preserve the course-author workspace authorization boundary.
  - [x] Submit IDs to context APIs, retain server-owned selections after validation failures, and render normalized field-safe errors.
  - [x] Verify the existing course-author Insights section/template selectors remain functional after generic component changes.
- Testing Tasks:
  - [x] Add component/LiveView tests for initial selection restoration, selection toggles, removal, rerender stability, empty options, empty selection, stale selections, and validation errors.
  - [x] Add LiveView tests for create/configure submits, active/paused editing, completed/archived read-only state, unauthorized access, and forged IDs.
  - [x] Add accessibility-focused assertions for labels, trigger semantics, expanded state, controls relationships, checkbox state, focusable controls, and error associations.
  - [x] Add regression coverage for both existing Insights consumers of `MultiSelectInput`.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs test/oli_web/live/workspaces/course_author/insights_live_test.exs`
- Definition of Done:
  - Researchers can clearly select, inspect, and update participating sections without ambiguous all-section behavior.
  - Persisted and stale state survives normal LiveView interaction.
  - The reused selector meets repository accessibility expectations and existing consumers do not regress.
- Gate:
  - Phase 4 is complete only when the authoring workflow satisfies AC-001 through AC-003 and AC-007 with component, LiveView, and accessibility coverage.
- Dependencies:
  - Phase 2 DTO and command contracts; Phase 1 eligibility semantics.
- Parallelizable Work:
  - Component-internal work can run alongside Phase 3 runtime enforcement after Phase 2 contracts stabilize.

## Phase 5: Workflow Verification, Review, And Release Hardening
- Goal: Prove the complete authoring-to-delivery workflow and close security, performance, telemetry, and traceability gates for FR-001 through FR-007 and AC-001 through AC-007.
- Tasks:
  - [x] Use `build_scenario` to add or update `Oli.Scenarios` coverage for project publication, base and remixed sections, experiment configuration, enrollment, participating delivery, nonparticipating fallback, and deselection.
  - [x] Use `extend_scenario` only if current directives cannot configure participation or assert experiment evidence without fixtures/factories/mocks.
  - [x] Verify the scenario covers selected base/remix eligibility, an unselected eligible section, an unrelated section, sticky assignment, first-option fallback, evidence presence/absence, and retained history after deselection.
  - [x] Run all targeted context, runtime, reward handoff, LiveView, component, and scenario tests.
  - [x] Run `mix format`.
  - [x] Inspect delivery membership and reward queries for N+1 behavior, missing indexes, unnecessary preloads, and avoidable repeated checks.
  - [x] Review authorization, tenant/project/remix scoping, forged IDs, stale-state handling, telemetry privacy, and absence of learner evidence on fallback.
  - [x] Perform requirements review and attach implementation proof references for AC-001 through AC-007.
  - [x] Record the remaining product follow-ups—zero-section activation policy, stale reactivation behavior, and searchable modal threshold—in the PR or execution record without blocking the documented defaults.
- Testing Tasks:
  - [x] Validate the scenario YAML with `Oli.Scenarios.validate_file/1`.
  - [x] Run the targeted scenario runner or companion ExUnit module.
  - [x] Run the complete targeted ExUnit set for all changed boundaries.
  - Command(s): `mix test test/oli/delivery/sections_test.exs test/oli/experiments/context_test.exs test/oli/experiments/runtime_test.exs test/oli/delivery/experiments/reward_handoff_test.exs test/oli_web/live/workspaces/course_author/experiments_live_test.exs test/oli_web/live/workspaces/course_author/insights_live_test.exs`
  - Command(s): `mix format`
- Definition of Done:
  - A real workflow proves selected sections participate, unselected/stale sections fall back, and nonparticipating paths emit no experiment evidence.
  - All AC-001 through AC-007 have implementation proof.
  - Security, performance, UI/accessibility, Elixir, requirements, and telemetry concerns have been reviewed.
- Gate:
  - Phase 5 is complete only when targeted tests, scenario validation/execution, formatting, focused reviews, traceability validation, and manual selected-versus-unselected verification pass.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Review preparation and manual QA setup may begin while the final targeted suite runs, but release readiness waits for every gate.

## Parallelization Notes
- Phase 1 backend eligibility work and Phase 4 generic component prototyping can begin concurrently, but experiment UI integration waits for Phase 2 contracts.
- Phase 2 participation APIs and component-internal accessibility changes can proceed concurrently once the selected-ID/DTO shape is agreed.
- Phase 3 runtime enforcement and Phase 4 experiment configuration integration can proceed concurrently after Phase 2, with shared review around section scope semantics.
- Scenario authoring may begin after Phase 3 runtime behavior and Phase 4 submit behavior are stable; avoid encoding temporary interfaces.
- Security, privacy, telemetry, and performance checks are distributed across phases and consolidated in Phase 5.

## Phase Gate Summary
- Gate A: Eligibility and runtime-scope tests prove active base/remix membership, empty-means-none, and project-authoring visibility.
- Gate B: Participation API tests prove authorized atomic replacement, stale visibility, rollback, and concurrency safety.
- Gate C: Runtime tests prove assignment/reuse/evidence enforcement and first-option fallback for every nonparticipating state.
- Gate D: LiveView/component tests prove reusable accessible selection, persisted/stale state, authorization, and no regression to Insights consumers.
- Gate E: Scenario, targeted ExUnit, formatting, focused review, manual QA, and requirements traceability prove FR-001 through FR-007 and AC-001 through AC-007.
