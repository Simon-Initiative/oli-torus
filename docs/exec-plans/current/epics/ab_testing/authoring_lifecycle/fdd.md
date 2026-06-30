# A/B Testing Authoring And Experiment Lifecycle - Functional Design Document

## 1. Executive Summary

Provide A/B testing experiment management backed by `Oli.Experiments`. Authors and permitted administrators can create draft weighted random experiments from alternatives decision points, configure condition weights, transition experiments through `draft`, `active`, `paused`, `completed`, and `archived`, and receive clear validation errors when edits would destabilize learner assignments. Thompson Sampling authoring is intentionally deferred to the dedicated Thompson Sampling slice; this slice may show disabled "Coming soon" UI but must not persist or activate adaptive experiments.

This design satisfies FR-001 through FR-005 by routing creation and lifecycle changes through the A/B testing domain context, avoiding provider-migration terminology and JSON export/import workflow affordances in experiment management, enforcing lifecycle and assignment-aware condition validation in backend code, blocking Thompson Sampling configuration until the follow-up slice, and keeping the UI inside the existing course-author LiveView surface.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001: Authoring must use plain A/B Testing language and avoid provider-migration terminology, prior-provider labels, the term "native", and JSON export/import workflows in the experiment creation and management path.
  - FR-002: Authorized users must create, edit, start, pause, complete, and archive MVP A/B testing experiments using lifecycle state rules.
  - FR-003: Authorized users must configure condition weights for A/B/N weighted random experiments.
  - FR-004: Thompson Sampling must not be selectable, submittable, persisted, or activation-eligible in this slice; any visible affordance must be disabled with clear "Coming soon" copy until the Thompson Sampling slice enables adaptive authoring.
  - FR-005: Authoring must prevent unsafe condition edits after learner assignments exist.
- Acceptance criteria mapping:
  - AC-001: Sections 4 and 5 define A/B Testing LiveView controls that avoid prior-provider labels, "native" terminology, and JSON export/import controls.
  - AC-002: Sections 4, 5, 7, and 13 define permission and state-transition validation with delivery eligibility tied to `:active`.
  - AC-003: Sections 4, 5, 6, and 13 define weighted condition configuration and invalid-weight rejection.
  - AC-004: Sections 4, 5, 6, 10, and 13 define disabled or absent Thompson Sampling controls and backend rejection of adaptive configuration until the follow-up slice.
  - AC-005: Sections 4, 7, 10, and 13 define assigned-condition edit protection and user-facing validation errors.
- Non-functional requirements:
  - Domain validation belongs in `Oli.Experiments`; LiveViews render forms, invoke commands, and display errors.
  - Authoring must respect published content immutability by referencing alternatives resources/revisions rather than mutating published revisions.
  - Authorization must preserve project, institution, author, and administrator boundaries.
  - Lifecycle attempts, validation failures, and successful experiment creation must emit operational telemetry.
- Assumptions:
  - A/B testing domain persistence, assignment, exposure, reward, analytics, and policy boundaries from `domain_contract` and `delivery_runtime` are available before this slice is implemented.
  - MVP authoring is project-level. Sections consume project-authored experiment configuration during delivery and may retain section-level visibility or enablement state derived from the project.
  - Experiments target alternatives decision points whose condition codes correspond to alternatives group option IDs or names.
  - Current authored experiment revisions that were designed for the previous provider-backed workflow remain supported through compatibility behavior. They are not automatically imported into A/B testing records, not used as templates for new experiments, and not exposed through JSON import/export workflows.
  - `has_experiments` may remain as a coarse project visibility gate during transition, but lifecycle state determines delivery eligibility.

## 3. Repository Context Summary

- What we know:
  - `Oli.Experiments` already exists as the A/B testing context with public structs for create, update, lifecycle, assignment, exposure, outcome, reward, and analytics calls.
  - A/B testing tables from `priv/repo/migrations/20260625120000_create_experiment_tables.exs` include experiment definitions, decision points, conditions, assignments, exposures, outcomes, rewards, policy states, and policy updates.
  - Current course-author experiment management still uses `lib/oli_web/live/workspaces/course_author/experiments_live.ex` and `Oli.Authoring.Experiments.get_latest_experiment/1` to locate provider-specific alternatives revisions.
  - `lib/oli_web/live/workspaces/course_author/alternatives_live.ex` still contains provider-specific creation copy for an experiment decision point, while normal alternatives groups filter out provider-specific groups.
  - Delivery runtime now expects A/B testing experiment records and treats only `:active` definitions as assignment-eligible.
  - Existing `Oli.Experiments.CreateExperimentRequest` and `UpdateExperimentRequest` cover definition-level fields, but they do not yet include nested decision point and condition authoring payloads.
- Resolved product decisions:
  - Current authored experiment revisions designed for the previous provider-backed workflow must remain supported without requiring author migration to the A/B testing data model.
  - New experiment creation must not create experiments from provider-specific alternatives revisions.
  - Experiment definitions must not be imported or exported in JSON format.
  - MVP supports exactly one alternatives decision point per experiment.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.Experiments` remains the only A/B testing domain owner. The authoring work adds experiment definition graph commands and a focused LiveView management surface.

- `Oli.Experiments`: owns create/update/lifecycle validation, decision-point and condition persistence, assignment-aware edit rules, policy configuration normalization, and telemetry.
- `Oli.Experiments.Authoring` or internal functions under `Oli.Experiments`: encapsulate authoring graph writes so web code never inserts `experiment_decision_points` or `experiment_conditions` directly.
- `OliWeb.Workspaces.CourseAuthor.ExperimentsLive`: becomes the primary A/B testing management surface for a project. It lists experiments, shows lifecycle status, opens create/edit forms, and invokes `Oli.Experiments`.
- `OliWeb.Live.Experiments.ExperimentsLive`: either delegates to the same shared A/B testing components or is reduced/removed if it is an older non-workspace duplicate.
- `Oli.Authoring.Experiments`: should stop being the source of new A/B testing experiment definitions. It can be narrowed to compatibility detection or read support for current authored provider-specific experiment revisions.
- Alternatives authoring remains responsible for creating ordinary alternatives groups. New A/B testing authoring references those groups as decision points instead of creating provider-specific alternatives revisions.

### 4.2 State & Data Flow

A/B testing creation flow:

1. Author opens the project A/B testing page in the course-author workspace.
2. LiveView loads experiment summaries through a new context read such as `Oli.Experiments.list_project_experiments/1`.
3. Author selects an existing alternatives group and configures name, slug, condition labels, active flags, and weights for a weighted random experiment.
4. LiveView builds an authoring request with `Scope`, experiment definition fields, one decision point identity, and conditions.
5. `Oli.Experiments` validates project scope, alternatives resource/revision existence, unique condition codes, positive weighted-random policy constraints, and rejects Thompson Sampling configuration as unavailable.
6. The context creates the definition, decision point, conditions, and initial policy state in one transaction and returns a public `ExperimentDefinition` or form-safe error.

A/B testing edit flow:

1. Draft weighted random experiments allow full definition, decision-point, and condition edits.
2. Paused experiments allow safe metadata edits and weight changes for active conditions only when no learner assignments would be invalidated.
3. Active experiments allow only limited metadata edits and lifecycle actions; condition identity, option mapping, algorithm changes, and Thompson Sampling enablement are blocked.
4. Completed and archived experiments are read-only except for allowed archival metadata if a later requirement adds it.
5. If assignments exist, condition deletion, condition-code changes, option remapping, and deactivation of assigned conditions are rejected with an explicit validation error.

Lifecycle flow:

1. `activate_experiment/2` validates that the definition has exactly one decision point, at least two active conditions, valid policy config, and alternatives content matching the condition set.
2. `pause_experiment/2` makes the experiment ineligible for new runtime assignment while preserving existing records.
3. `complete_experiment/2` ends enrollment for the experiment and prevents further authoring edits that affect assignments.
4. `archive_experiment/2` hides the experiment from default authoring lists while preserving audit and analytics evidence.

### 4.3 Lifecycle & Ownership

Lifecycle state on `experiment_definitions.state` is authoritative for delivery eligibility. `:active` is the only state that creates or reuses learner assignments during delivery. `:paused`, `:completed`, `:archived`, and `:draft` definitions are not assignment-eligible.

The experiment definition graph belongs to `Oli.Experiments` and is authored at the project level. Alternatives resources and revisions remain content owned by authoring/resources. Experiment records reference alternatives content through `alternatives_resource_id`, `alternatives_revision_id`, and `decision_point_key`; they do not mutate published resources during delivery. Sections use the project-authored experiment configuration when rendering eligible published content rather than defining separate section-authored experiments.

### 4.4 Alternatives Considered

- Continue using provider-specific alternatives revisions as the source for new experiments: rejected because it keeps a provider-specific content strategy as the domain source of truth and cannot represent lifecycle, policy state, or assignment-aware edit validation cleanly. Current authored experiments using that older shape remain supported through compatibility behavior, but they are not the creation path for new A/B testing experiments.
- Build a new React application for experiment authoring: rejected for MVP because the flow is form and lifecycle heavy, and existing course-author LiveView patterns are adequate.
- Make section-scoped authoring the default: rejected because the accepted MVP model follows the existing project-level authoring approach. Sections may carry derived delivery visibility or enablement state, but they do not own separate authored experiment definitions.
- Permit condition deletion after assignments exist by remapping learners: rejected because the PRD requires assignment stability and no reassignment semantics have been approved.
- Add a feature flag for authoring lifecycle: not selected because the PRD states no feature flags for this work item and `harness.yml` defaults feature flags to excluded. Rollout should use normal deployment sequencing and authorization.

## 5. Interfaces

- A/B testing authoring reads:
  - `Oli.Experiments.list_project_experiments(%Scope{}) :: {:ok, [%ExperimentDefinition{}]} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.get_experiment_authoring_view(experiment_id, %Scope{}) :: {:ok, %ExperimentAuthoringView{}} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.list_available_decision_points(%Scope{}) :: {:ok, [%DecisionPointCandidate{}]} | {:error, %ExperimentError{}}`
- A/B testing authoring commands:
  - Extend `CreateExperimentRequest` or add `CreateExperimentGraphRequest` with `scope`, definition fields, one `decision_point`, `conditions`, and weighted random `policy_config`.
  - Extend `UpdateExperimentRequest` or add `UpdateExperimentGraphRequest` with assignment-aware condition operations.
  - Reject Thompson Sampling algorithm or policy payloads with a form-safe unavailable error until the Thompson Sampling slice enables adaptive authoring.
  - Keep `activate_experiment/2`, `pause_experiment/2`, `complete_experiment/2`, and `archive_experiment/2` as lifecycle commands.
- Decision point payload:
  - Required fields: `alternatives_resource_id`, `alternatives_revision_id`, `decision_point_key`, `title`, and `position`.
  - MVP supports exactly one alternatives decision point per experiment.
- Condition payload:
  - Required fields: `condition_code`, `option_id`, `label`, `weight`, `active`, and `position`.
  - Weighted random requires at least two active conditions and a positive total weight.
  - Thompson Sampling payloads are out of scope for this slice and must not be persisted.
- LiveView events:
  - `new_experiment`, `validate_experiment`, `create_experiment`, `edit_experiment`, `update_experiment`, `start_experiment`, `pause_experiment`, `complete_experiment`, and `archive_experiment`.
  - Events must call context functions and translate `%ExperimentError{type, message, details}` into field or form errors.
  - If Thompson Sampling is visible, it must be disabled with "Coming soon" copy and must not submit adaptive params through LiveView events.
- Authorization boundary:
  - LiveViews must check existing project author/admin access before rendering.
  - Lifecycle commands for start, pause, complete, and archive must be allowed only for accepted collaborators of the experiment's project, content admins, account admins, and system admins.
  - Authoring requests should not accept a section scope for MVP create/update flows.

## 6. Data Model & Storage

- Reuse existing A/B testing tables:
  - `experiment_definitions` for name, slug, state, project scope, algorithm, assignment unit, and policy config.
  - `experiment_decision_points` for alternatives resource/revision references and decision point keys.
  - `experiment_conditions` for condition codes, labels, weights, active flags, option mapping, and ordering.
  - `experiment_assignments`, `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, `experiment_policy_states`, and `experiment_policy_updates` for runtime evidence and edit-safety checks.
- Add no new table by default for this slice.
- Add context-level changeset validation for:
  - unique experiment slug per project;
  - exactly one decision point;
  - at least two active conditions per decision point before activation;
  - non-negative weights with positive total active weight for weighted random;
  - Thompson Sampling algorithm or guardrail config rejection as unavailable;
  - no condition identity changes that conflict with existing assignments.
- Suggested `policy_config` shapes:
  - Weighted random: `%{"weights_normalized" => true}` or an empty map when weights live only on `experiment_conditions`.
  - Thompson Sampling: no accepted shape in this slice. The follow-up Thompson Sampling work item owns adaptive `policy_config` shape and migration from disabled UI to selectable controls.
- Existing storage:
  - Current authored provider-specific experiment revisions remain supported through compatibility behavior and should not be copied to A/B testing tables automatically.
  - New experiment creation must not use provider-specific alternatives revisions as templates or source records.
  - `has_experiments` may remain during transition as project-level visibility with section-level derived state, but should not be treated as lifecycle state.

## 7. Consistency & Transactions

- Create writes the experiment definition, decision point, conditions, and initial policy state in a single `Repo.transaction/1`.
- Update locks or reloads the experiment definition and checks current lifecycle state before applying changes.
- Condition updates check assignment existence by `experiment_id`, `decision_point_id`, and affected `condition_id` before destructive edits.
- Activation validates the current alternatives revision and condition set in the same transaction as the state transition to `:active`.
- Pause, complete, and archive use existing lifecycle transition rules and must not delete assignments or runtime evidence.
- Section-level delivery visibility or enablement state, if retained, is derived from the project and must not create a second authoring source of truth.
- Analytics and delivery reads must tolerate authoring state changes by relying on committed experiment records and `state`.

## 8. Caching Strategy

- No new cross-request cache is required for authoring lifecycle.
- LiveView state may hold form data and loaded summaries for the current socket only.
- If active experiment lookup is cached by runtime work, lifecycle transitions and condition edits must invalidate that cache through `Oli.Experiments` rather than through web code.

## 9. Performance & Scalability Posture

- Authoring lists should query by indexed `institution_id`, `project_id`, and `state`; they are not delivery hot paths.
- Activation validation should load only the selected alternatives group and its conditions, not the full project content tree.
- Assignment-existence checks must use indexed runtime tables and condition IDs; avoid broad scans over all project assignments.
- Thompson Sampling guardrail validation is deferred to the Thompson Sampling slice; this slice only verifies that adaptive configuration is not accepted.
- Performance review should inspect experiment list queries, activation validation query count, and assignment-aware edit checks for projects with many experiments.

## 10. Failure Modes & Resilience

- Unauthorized lifecycle attempt: return an authorization-safe error and emit validation telemetry without changing state.
- Invalid lifecycle transition: return `:invalid_state` with current and target state details.
- Missing or changed alternatives group: block activation and display a message that the selected alternatives content no longer matches the experiment.
- Invalid weights: reject create/update with field-level errors and preserve form input.
- Unsafe assigned condition edit: reject the edit and explain that learner assignments already exist for the condition.
- Thompson Sampling selected or submitted: reject create/update with an unavailable error and preserve any form input without creating or activating an adaptive experiment.
- Concurrent lifecycle updates: rely on transaction/reload semantics; the losing request receives an invalid-state or stale-state error.
- Current authored provider-specific experiment revision encountered: support the existing authored experiment through compatibility behavior, but do not offer migration, JSON import/export, or creation of a new A/B testing experiment from that revision.

## 11. Observability

- Emit telemetry from `Oli.Experiments` for:
  - `[:oli, :experiments, :authoring, :create]`
  - `[:oli, :experiments, :authoring, :update]`
  - `[:oli, :experiments, :authoring, :validation_failed]`
  - `[:oli, :experiments, :lifecycle, :transition]`
  - `[:oli, :experiments, :lifecycle, :transition_failed]`
- Metadata should include non-sensitive IDs: experiment_id, project_id, publication_id when present, section_id when present, algorithm, previous_state, target_state, actor_author_id or actor_user_id, and error type.
- Logs must not include learner names, LMS identifiers, raw activity responses, API tokens, or full experiment payloads.
- AppSignal can consume telemetry and exceptions according to `docs/OPERATIONS.md`.

## 12. Security & Privacy

- LiveViews must require existing project author/admin access before listing or mutating experiments.
- Lifecycle transition authorization must be explicit and tested for accepted project collaborators, content admins, account admins, system admins, and unauthorized authors.
- Context functions must validate institution/project/scope and must not trust IDs posted from the browser.
- Authoring responses must expose public structs or form view models, not private Ecto schemas.
- Runtime evidence and learner assignment counts may be used for validation, but authoring error messages must not expose learner identities.
- Removing JSON export/import affordances avoids leaking experiment configuration through download routes in the A/B testing workflow.

## 13. Testing Strategy

- ExUnit context tests:
  - create weighted random experiment graph with valid alternatives decision point and conditions.
  - reject MVP create/update requests that attempt to author an experiment for a section instead of the project.
  - reject duplicate condition codes, fewer than two active conditions, negative weights, and zero total active weight.
  - reject Thompson Sampling create/update requests as unavailable and prove no adaptive policy config is persisted.
  - update draft experiment graph and persist condition ordering, labels, active flags, and weights.
  - reject algorithm, condition-code, option mapping, and assigned-condition deletion after assignments exist.
  - enforce lifecycle transition rules for draft, active, paused, completed, and archived states.
  - enforce strict project/institution scope for reads and writes.
- LiveView tests:
  - project experiment page lists experiments and lifecycle statuses.
  - new creation path does not render prior-provider labels, provider-migration terminology, the term "native", or JSON export/import controls.
  - form validation displays weight, lifecycle, assigned-condition, and disabled/unavailable Thompson Sampling errors where applicable.
  - Thompson Sampling controls are absent or disabled with "Coming soon" copy and cannot submit adaptive configuration.
  - lifecycle buttons appear only for permitted roles and valid states.
  - current authored provider-specific experiments remain supported through the compatibility behavior and have no migration, new-experiment-from-legacy, or JSON import/export controls.
- Scenario tests:
  - Add `Oli.Scenarios` coverage if implementation spans authoring, publishing, section delivery, enrollment, and runtime assignment in one workflow.
  - A useful scenario would create alternatives, create an experiment, activate it, publish, deliver to a learner, and verify assignment stability after a blocked unsafe edit.
- Static/security/performance checks:
  - Search for visible prior-provider labels, provider-migration terminology, the term "native", and JSON download controls in A/B testing authoring paths.
  - Confirm web code does not insert or update private experiment schemas directly.
  - Review query shape for assignment-aware edit checks.
- Validation gates:
  - Run targeted `mix test test/oli/experiments/context_test.exs`.
  - Run targeted LiveView tests for experiment authoring surfaces.
  - Run targeted scenario tests if scenario coverage is added.
  - Run `mix format`.
  - Run harness requirements trace and FDD validation commands.

## 14. Backwards Compatibility

- New experiments start from current A/B testing records and do not import older external definitions, assignments, or analytics.
- Current authored experiment revisions that were designed for the previous provider-backed workflow remain supported through compatibility behavior and are not automatically migrated to A/B testing experiment definitions.
- Existing provider-specific alternatives revisions may remain in resource history and working publications, but new A/B testing authoring must not create experiments from those revisions.
- Existing learner-facing fallback behavior remains governed by delivery runtime: no active experiment means first-option fallback.
- Existing `has_experiments` fields can remain temporarily for navigation or coarse visibility, but lifecycle state is authoritative.
- Removing JSON export/import controls is an intentional workflow change for A/B testing authoring.

## 15. Risks & Mitigations

- Risk: Authors expect current provider-specific authored experiments to become editable as new A/B testing records. Mitigation: support those existing experiments through compatibility behavior, but provide no migration, JSON import/export, or new-experiment-from-legacy affordance.
- Risk: Condition edits destabilize existing assignments. Mitigation: check assignment existence before destructive condition changes and block unsafe operations.
- Risk: Pending collaborators or unrelated authors mutate experiment lifecycle state. Mitigation: require accepted project collaboration or content/account/system admin role checks for lifecycle commands.
- Risk: Users expect Thompson Sampling to be enabled from the first authoring slice. Mitigation: keep any adaptive affordance disabled with "Coming soon" copy, reject adaptive payloads in the context, and move real selection, priors, guardrails, and activation to the Thompson Sampling slice.
- Risk: Authoring UI duplicates logic across old and workspace LiveViews. Mitigation: use shared components or retire/delegate the older surface.
- Risk: Authoring activates experiments whose alternatives content has drifted. Mitigation: validate alternatives resource/revision and condition mapping at activation.

## 16. Open Questions & Follow-ups

- Follow up with analytics/reporting work for instructor-facing visibility into active experiments in sections.
- Follow up with the Thompson Sampling slice to replace disabled adaptive UI with selectable adaptive configuration, validate priors and guardrails, and permit adaptive activation.

## 17. References

- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/PRODUCT_SENSE.md`
- `docs/STACK.md`
- `docs/TESTING.md`
- `docs/TOOLING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `docs/exec-plans/current/epics/ab_testing/informal.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/requirements.yml`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/create_experiment_request.ex`
- `lib/oli/experiments/update_experiment_request.ex`
- `lib/oli/experiments/lifecycle_request.ex`
- `lib/oli/authoring/experiments.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `priv/repo/migrations/20260625120000_create_experiment_tables.exs`

## 18. Decision Log
### 2026-06-30 - Move Adaptive Authoring To Thompson Sampling Slice
- Change: Revised this FDD so authoring lifecycle implements weighted random experiments and rejects Thompson Sampling configuration as unavailable.
- Reason: The parent epic now sequences Thompson Sampling after weighted random authoring lifecycle.
- Evidence: `docs/exec-plans/current/epics/ab_testing/plan.md`; `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/requirements.yml`.
- Impact: Adaptive selection, prior/guardrail validation, and activation are owned by `docs/exec-plans/current/epics/ab_testing/thompson_sampling/`.
