# Experiment Section Participation - Functional Design Document

## 1. Executive Summary
Implement explicit per-experiment section participation by completing and tightening the section-scoping support already present in `Oli.Experiments`.

The existing `experiment_sections` join table remains the transactional source of truth. The key semantic change is that an experiment applies to a delivery section only when an `experiment_sections` row exists and the section is still active and currently related to the experiment's project through `sections_projects_publications`. An experiment with no section rows applies nowhere.

The course-author experiment configuration LiveView will reuse an adapted `OliWeb.Common.MultiSelectInput` pattern. A new A/B testing context query supplies eligible and stale selected sections, and a dedicated participation command replaces the selected set transactionally. Assignment reuse, new assignment, exposure, outcome, reward, policy-update, and analytics-scoping paths all use the same participation predicate. Nonparticipation returns the existing `:no_experiment` decision, allowing the alternatives strategy to render its first option without producing experiment evidence.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001 and AC-001: store an independent zero-or-more section selection for each experiment.
  - FR-002 and AC-002: offer only active base-project or current-remix sections within the authorized project scope.
  - FR-003 and AC-003: restore saved selections, support deselection, reject forged IDs, and show selected sections that have become stale.
  - FR-004 and AC-004: create or reuse assignments only for selected, currently eligible sections.
  - FR-005 and AC-005: return first-option fallback for unselected or stale sections.
  - FR-006 and AC-006: prevent assignment, exposure, outcome, reward, and policy-update evidence outside participating sections.
  - FR-007 and AC-007: preserve project-authoring authorization and reject sections outside the experiment project or institution boundary.
- Non-functional requirements:
  - Keep participation checks local to PostgreSQL and suitable for delivery hot paths.
  - Preserve atomic, duplicate-free participation updates.
  - Preserve WCAG 2.1 AA-oriented keyboard, focus, labeling, expanded-state, checkbox, error, and empty-state behavior.
  - Emit operational metadata without learner responses or unnecessary learner identity.
- Assumptions:
  - `Section.status == :active` is the canonical active-section test for this feature.
  - A current row in `sections_projects_publications` establishes that a section was created from or currently contains remixed content from the project.
  - Empty selection means no participating sections.
  - Newly eligible sections are never selected automatically.
  - Existing assignment and analytics history is retained after deselection; only future runtime use and evidence are blocked.
  - The existing course-author workspace authorization remains the outer UI authorization boundary. Context commands still validate project and section scope so forged IDs cannot bypass that boundary.
  - Completed and archived experiments remain read-only. Draft, active, and paused experiments may update participation through the dedicated command.

## 3. Repository Context Summary
- What we know:
  - `Oli.Experiments.CreateExperimentRequest` and `UpdateExperimentRequest` already expose `section_ids`.
  - `experiment_sections` already has foreign keys, a unique `(experiment_id, section_id)` index, and a `section_id` index.
  - `Oli.Experiments` already transactionally replaces experiment-section rows, but validation currently accepts only `Section.base_project_id == project_id` and therefore rejects valid remixed sections.
  - Current experiment queries treat no `experiment_sections` rows as project-wide applicability through `NOT EXISTS ... OR EXISTS ...`. This conflicts with the new empty-means-none requirement.
  - `Oli.Delivery.Sections.get_sections_containing_resources_of_given_project/1` already joins `sections_projects_publications`, filters `Section.status == :active`, and returns distinct base and remixed sections for a project.
  - `OliWeb.Common.MultiSelectInput` and `OliWeb.Common.MultiSelect.Option` already provide a section multi-select pattern on the course-author Insights page.
  - The current `MultiSelectInput` initializes internal selections to an empty map on every update and lacks the full button/listbox semantics needed for persisted edit state and accessible expanded/collapsed behavior.
  - `OliWeb.Workspaces.CourseAuthor.ExperimentsLive` currently supports experiment creation and lifecycle actions but not an experiment edit/configuration action.
  - The alternatives delivery boundary already interprets `AssignmentDecision.status == :no_experiment` as the safe path that ultimately selects the first option.
- Unknowns to confirm:
  - Whether product wants experiment activation to require at least one section. This design allows zero because the PRD defines empty selection as no participation.
- Release context:
  - Native A/B experiments have not been deployed, so there is no production experiment audience to preserve.
  - Existing local and test experiments with no section rows may intentionally change from project-wide applicability to no participation.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.Experiments`:
  - Own the public participation query and command.
  - Validate experiment/project scope, lifecycle state, submitted section IDs, active status, current project relationship, and duplicate normalization.
  - Centralize the runtime participation predicate used by all experiment-scoped delivery and evidence operations.
- `Oli.Delivery.Sections`:
  - Continue to own section/project/publication relationship queries.
  - Expose or reuse a queryable eligibility function that returns active sections associated with a project through `sections_projects_publications`.
  - Do not own experiment participation persistence.
- `OliWeb.Workspaces.CourseAuthor.ExperimentsLive`:
  - Load eligible and stale selection data from `Oli.Experiments`.
  - Render a "Configure sections" action for draft, active, and paused experiments.
  - Open an in-page configuration panel or existing `FormModal` containing the adapted multi-select.
  - Submit only IDs and display normalized `ExperimentError` feedback; do not perform domain validation in the LiveView.
- `OliWeb.Common.MultiSelectInput`:
  - Accept initial selected IDs/options and preserve them across normal LiveView updates.
  - Expose selected IDs to the parent form or emit a stable selection-change message.
  - Add semantic button behavior, `aria-expanded`, `aria-controls`, keyboard operation, labels, visible focus, and deterministic option IDs.
  - Remain generic; experiment-specific stale-selection copy and eligibility rules stay outside the component.

### 4.2 State & Data Flow
Authoring read flow:

1. `ExperimentsLive` requests `Oli.Experiments.get_section_participation(experiment_id, scope)`.
2. The context loads the scoped experiment and its selected section rows.
3. The context loads active eligible sections for the experiment's project through `sections_projects_publications`.
4. It returns an `ExperimentSectionParticipation` DTO containing:
   - `eligible_sections`: active selectable section summaries, each with `selected?`;
   - `stale_selected_sections`: selected section summaries that are inactive or no longer related to the project;
   - `selected_section_ids`: all currently selected IDs for display/audit.
5. The LiveView maps eligible summaries to `MultiSelect.Option` values and renders stale selections separately as disabled warning rows with a remove action.

Authoring write flow:

1. The researcher submits the selected eligible IDs plus any explicit stale IDs to remove.
2. `Oli.Experiments.update_section_participation/3` locks the experiment definition, confirms it is draft, active, or paused, and validates every submitted selected ID against the active eligible-section query.
3. In one transaction, it deletes the experiment's existing join rows and inserts the normalized selected IDs. Stale IDs not resubmitted are therefore removed when the researcher saves.
4. The command reloads the experiment definition, emits participation-change telemetry, and returns the updated DTO or definition.
5. A concurrent update is last-committed-write-wins at the locked experiment boundary; the unique index remains a database safeguard.

Delivery flow:

1. Delivery resolves project, section, enrollment, decision point, and publication scope as it does today.
2. Active experiment lookup requires an `experiment_sections` membership row joined to an active section and a current `sections_projects_publications` row for the experiment's project.
3. When the predicate fails, the context returns `AssignmentDecision{status: :no_experiment}` with an internal fallback reason such as `:section_not_participating`.
4. The alternatives strategy renders the first option.
5. No assignment or exposure command runs. Outcome/reward processing also rechecks current participation before accepting evidence, so a deselection between exposure and outcome blocks new evidence and policy changes.

### 4.3 Lifecycle & Ownership
- `experiment_sections` is owned by `Oli.Experiments`; web and delivery modules never access it directly.
- Participation may be configured in draft, active, or paused states so a researcher can stop or expand participation without editing conditions or algorithms.
- Completed and archived experiments are immutable.
- A selected section becomes stale immediately when it is archived/inactive or its last current project relationship is removed.
- Staleness does not mutate `experiment_sections` asynchronously. Runtime checks treat the row as inert, while authoring reads surface it. The next explicit participation save removes stale rows that are not resubmitted.
- Deselecting a section does not delete historical assignments, xAPI statements, ClickHouse rows, or current aggregate history. Those remain auditable as events that occurred while the section participated.
- If a section becomes eligible again before the stale row is removed, the existing selection becomes active again. This behavior must be called out in UI copy and can be revisited if product requires irreversible automatic deselection.

### 4.4 Alternatives Considered
- Continue interpreting no join rows as "all sections":
  - Rejected because it directly contradicts empty-means-none and can enroll newly eligible sections without researcher consent.
- Add a new participation table:
  - Rejected because `experiment_sections` already has the correct ownership, keys, constraints, and public DTO support.
- Put a coarse participation toggle on each section or source project:
  - Rejected because participation is intentionally scoped to each experiment and research population.
- Reuse `UpdateExperimentRequest` for active participation changes:
  - Rejected because general experiment updates intentionally restrict active-state edits. A narrow command makes lifecycle and authorization rules explicit without weakening condition/algorithm safety.
- Copy `MultiSelectInput` into an experiment-only component:
  - Rejected initially. Adapt the generic component and keep stale-selection presentation in the experiment configuration wrapper. Split only if accessibility or form-submission needs would make the generic API incoherent.
- Automatically delete stale rows:
  - Rejected for the first implementation because it hides configuration drift and requires background/event coupling to section and remix lifecycle changes. Runtime validation plus visible stale state is simpler and safer.

## 5. Interfaces
- `Oli.Experiments.list_eligible_sections(scope :: Scope.t())`
  - Returns `{:ok, [EligibleExperimentSection.t()]}` or `{:error, ExperimentError.t()}`.
  - Each DTO contains only authoring-safe fields: `id`, `slug`, `title`, `status`, and optional disambiguating metadata such as start/end dates.
  - Uses current `sections_projects_publications` membership and `status == :active`.
- `Oli.Experiments.get_section_participation(experiment_id, scope)`
  - Returns eligible options, selected IDs, and stale selected summaries after enforcing experiment/project scope.
- `Oli.Experiments.update_section_participation(experiment_id, scope, section_ids)`
  - Accepts a list of integer IDs; normalizes duplicates.
  - Allows draft, active, and paused experiments; rejects completed and archived experiments.
  - Rejects the whole command if any ID is missing, inactive, unrelated to the project, or outside tenant/author scope.
  - Replaces the selected set transactionally and returns the updated participation DTO.
- `Oli.Experiments.participating_section?/2` is an internal query helper, not a cross-context public API.
  - It represents one canonical predicate: membership row exists, section is active, and a current project relationship exists.
  - Query-building variants may be private subqueries/fragments reused by assignment, reuse, exposure, outcome, reward, policy, lifecycle validation, and analytics scoping.
- Existing request interfaces:
  - `CreateExperimentRequest.section_ids` becomes explicit: `nil` and `[]` both create no participating sections for project-authoring requests. The LiveView sends the selected list explicitly.
  - `UpdateExperimentRequest.section_ids` may continue to support draft graph creation/update, but interactive participation changes use the dedicated command.
- LiveView component contract:
  - Extend `MultiSelectInput` with `selected_ids` or selected option state as a required source-controlled input.
  - Preserve `on_select_message` for existing consumers.
  - The experiment wrapper owns hidden/form fields if direct form serialization is chosen.

## 6. Data Model & Storage
- Reuse `experiment_sections`:
  - `experiment_id` references `experiment_definitions` with `on_delete: :delete_all`.
  - `section_id` references `sections` with `on_delete: :delete_all`.
  - Unique `(experiment_id, section_id)` prevents duplicates.
  - Existing indexes support membership checks by experiment and section.
- No new participation-history table is introduced. History remains in emitted experiment events and existing assignments.
- Migration posture:
  - No data backfill is required because native A/B experiments have not been deployed.
  - Change application semantics directly so zero `experiment_sections` rows means zero participating sections.
  - Existing local or test definitions with zero rows are allowed to become nonparticipating and should be updated explicitly in tests or development data when participation is required.
- Query semantic change:
  - Remove every `NOT EXISTS (experiment_sections) OR EXISTS (matching section)` branch.
  - Require only an eligible matching membership row.
  - Update project-authoring list queries that currently intentionally select unscoped experiments; project authoring must list experiments by `project_id` regardless of participation rows.

## 7. Consistency & Transactions
- Create and draft graph update continue to persist experiment definition and participation rows in the existing transaction.
- The dedicated participation update:
  - validates scope before mutation;
  - starts a transaction;
  - locks the experiment definition `FOR UPDATE`;
  - re-runs eligibility validation inside the transaction to reduce status/remix races;
  - deletes current rows and inserts the normalized selected set;
  - reloads the association before commit.
- The unique index protects against duplicate inserts.
- Runtime eligibility is checked in the same database query that locates the applicable experiment or evidence target, avoiding time-of-check/time-of-use gaps between a Boolean precheck and assignment/evidence mutation.
- Existing assignment rows are immutable historical state. Current participation gates their reuse.
- A section status or remix relationship can change immediately after a runtime query. Existing transaction boundaries remain authoritative for the operation in flight; subsequent operations observe the new state.

## 8. Caching Strategy
- Do not add application caching initially.
- Authoring eligibility lists are configuration-page reads, not high-frequency traffic.
- Delivery participation checks should use indexed `EXISTS`/join predicates in the existing experiment query.
- If AppSignal or query telemetry later shows a material hot-path regression, consider request-local/preloaded scope reuse before cross-request caching. Any cross-request cache would require invalidation on participation, section status, and remix relationship changes and is therefore intentionally deferred.

## 9. Performance & Scalability Posture
- Keep delivery to one scoped query for experiment lookup/reuse rather than loading all section IDs into Elixir.
- Use the existing unique `(experiment_id, section_id)` index for membership and the `section_id` index for reverse lookups.
- Verify that `sections_projects_publications` has an index beginning with `project_id` and/or supporting `(section_id, project_id)` membership; add a targeted index only if query plans show it is missing.
- Use distinct eligible-section queries to avoid duplicate options when multiple publication relationships exist.
- Sort authoring options deterministically by normalized section title and ID.
- Paginate or add server-side search only if real projects can produce option counts that make the current dropdown impractical; do not introduce pagination speculatively.
- Review `EXPLAIN` plans or equivalent query evidence for active experiment lookup and participation update validation during implementation.

## 10. Failure Modes & Resilience
- Submitted section does not exist:
  - Reject the full update with `ExperimentError{type: :invalid_scope}` and no mutation.
- Submitted section is inactive, unrelated, removed-remix, or cross-project:
  - Reject the full update with a normalized validation error; include safe section IDs in details for form feedback.
- Experiment is completed or archived:
  - Reject participation mutation as read-only.
- Selected section becomes stale after configuration:
  - Treat it as nonparticipating at runtime, show it as stale in authoring, and remove it on the next save unless re-eligible.
- Empty selection:
  - Commit zero rows; delivery consistently returns `:no_experiment`.
- Concurrent saves:
  - Serialize through the experiment row lock; last committed complete selection wins.
- Database error:
  - Roll back the complete replacement and preserve the prior selection.
- Component event/reset failure:
  - Keep server-owned selected IDs as the source of truth and rerender validation feedback without silently clearing them.
- Existing local/test experiment has no participation rows:
  - Treat it as nonparticipating by design; update the fixture or test to select sections explicitly when assignment behavior is expected.

## 11. Observability
- Emit `[:oli, :experiments, :participation, :updated]` with:
  - experiment ID;
  - project ID;
  - previous/new selected counts;
  - added/removed counts;
  - stale count at save;
  - experiment state.
- Emit `[:oli, :experiments, :participation, :validation_failed]` with safe error type/reason and requested count; do not emit learner data or raw form payloads.
- Extend assignment fallback telemetry with `reason: :section_not_participating` or `:section_no_longer_eligible`, preserving the current count measurement.
- Reward/outcome rejection should use existing telemetry families with a participation-related reason rather than creating duplicate learner-level logs.
- AppSignal should expose latency/error changes for experiment lookup and configuration commands through existing Phoenix/Ecto instrumentation.
- Do not emit a learner event merely because first-option fallback occurred. Operational fallback counts are sufficient; experiment xAPI evidence must remain absent.

## 12. Security & Privacy
- Course-author workspace authorization remains required before rendering configuration.
- Context APIs validate the experiment belongs to `scope.project_id`.
- Eligibility is derived from server-side project/section relations; submitted IDs never establish eligibility.
- Remix eligibility replaces the current base-project-only validation only for this participation use case. It must not weaken unrelated scope validation.
- Institution checks apply where the scope carries an institution. Project relationship validation remains mandatory even when institution is absent from authoring scope.
- Return only section metadata already appropriate for accepted project collaborators and administrators.
- Use parameterized Ecto queries for all IDs.
- Configuration telemetry excludes learner identity, responses, and section titles; IDs and counts are sufficient.
- Runtime must not emit experiment xAPI, reward, or policy evidence after participation fails.

## 13. Testing Strategy
- Context and schema tests:
  - AC-001: create/update independent section sets for two experiments; verify empty and non-empty sets and duplicate normalization.
  - AC-002: cover active base-project, active current-remix, inactive, removed-remix, unrelated-project, missing, inaccessible, and cross-institution sections.
  - AC-003: cover persisted selections, explicit deselection, forged IDs, stale DTO presentation, stale removal on save, and concurrent last-write behavior.
  - AC-004: cover new assignment and sticky reuse in a participating section; prove an existing assignment is not reused after deselection or eligibility loss.
  - AC-005: cover `:no_experiment` and first-option fallback for empty, unselected, inactive, removed-remix, and deselected cases.
  - AC-006: assert no assignment/exposure/outcome/reward/policy-update evidence is emitted outside current participation, including deselection between exposure and reward.
  - AC-007: cover unauthorized project scope and forged section IDs without partial writes.
- LiveView/component tests:
  - Render eligible options with stable IDs and distinguishing metadata.
  - Restore selected values while editing and preserve them across validation rerenders.
  - Render explicit no-eligible-sections, no-selection, and stale-selection states.
  - Exercise keyboard-triggerable control semantics, labels, `aria-expanded`, `aria-controls`, checkbox state, focus behavior, and accessible errors.
  - Verify completed/archived experiments do not expose mutation controls.
- Semantic-cutover tests:
  - Seed an experiment with no section rows and verify it applies nowhere.
  - Verify explicitly scoped experiments retain their selected sections and future/newly eligible sections are not automatically inserted.
  - Verify project-authoring lists still include experiments after empty semantics change.
- Scenario coverage:
  - Extend the scenario DSL only if existing directives cannot express experiment participation.
  - Build a project, publication, base section, remixed section, unrelated section, enrollments, and a decision point.
  - Select one eligible section, activate the experiment, and verify sticky assignment/evidence there.
  - Verify an unselected eligible section and unrelated section both render the first option with no experiment evidence.
  - Deselect the participating section and verify immediate fallback while historical evidence remains.
- Required implementation gates:
  - Targeted `mix test` for `Oli.Experiments`, delivery alternatives, and `ExperimentsLive`.
  - Targeted scenario validation and ExUnit runner.
  - `mix format`.
  - Security, performance, Elixir, UI, and requirements reviews under `.review/`.

## 14. Backwards Compatibility
- Public request structs retain `section_ids`, and the existing join table remains in place.
- The meaning of an empty join set changes from unrestricted to no participation.
- This is an accepted breaking change for existing local and test experiment records because the native feature has not been deployed.
- No production audience migration or data backfill is performed.
- Existing explicitly scoped experiments remain unchanged.
- Existing assignments and analytics history are retained.
- Newly eligible sections after cutover do not participate until explicitly selected.
- Project-authoring list/read queries must not use absence of section rows as an authoring-scope discriminator.
- No feature flag or staged compatibility deployment is required.

## 15. Risks & Mitigations
- Hidden unrestricted semantics exist in multiple queries:
  - Mitigation: inventory every `experiment_sections` `NOT EXISTS` branch and every assignment/evidence query; centralize the new predicate and add regression tests.
- Current section validation rejects remixed sections:
  - Mitigation: introduce a participation-specific eligibility query based on `sections_projects_publications`; do not broadly weaken `validate_section_scope/2`.
- Stale selection reactivates if eligibility returns:
  - Mitigation: surface stale state prominently and document this initial behavior; product can choose explicit irreversible deselection later.
- Existing `MultiSelectInput` resets state and has accessibility gaps:
  - Mitigation: make it source-controlled, add semantic behavior, and test existing Insights consumers for regressions.
- Existing tests assume empty means project-wide:
  - Mitigation: update those tests and fixtures to select sections explicitly, and add a regression test that empty means no participation.
- Participation changes during an active experiment alter the research population:
  - Mitigation: emit audit-oriented telemetry and show clear confirmation copy; retain historical evidence and timestamps.
- Reward arrives after deselection:
  - Mitigation: recheck current participation before outcome/reward/policy mutation and record only an operational rejection reason.

## 16. Open Questions & Follow-ups
- Confirm whether active experiments may intentionally have zero participating sections. The design permits it and safely falls back.
- Confirm whether stale rows should reactivate automatically if a section becomes eligible again. The initial design does; an explicit permanent-removal model would require additional state.
- Product/design should confirm whether the adapted dropdown/chip control remains usable for projects with many similarly named sections or whether the same data contract should drive a searchable modal.
- A later implementation plan should assign ownership for the xAPI/ClickHouse regression proof that nonparticipating delivery creates no experiment evidence.

## 17. References
- `docs/exec-plans/current/epics/ab_testing/section_participation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/section_participation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/create_experiment_request.ex`
- `lib/oli/experiments/update_experiment_request.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/schemas/experiment_section.ex`
- `lib/oli/delivery/sections.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `lib/oli_web/live/workspaces/course_author/insights_live.ex`
- `lib/oli_web/live/common/multi_select.ex`
- `priv/repo/migrations/20260625120000_create_experiment_tables.exs`
- `docs/design-docs/publication-model.md`
- `docs/TESTING.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
