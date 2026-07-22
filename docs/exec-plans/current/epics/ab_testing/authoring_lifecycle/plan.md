# A/B Testing Authoring And Experiment Lifecycle - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/requirements.yml`

## Scope
Implement project-level A/B Testing authoring and lifecycle management through `Oli.Experiments` and the existing course-author LiveView surface. The work covers creation and editing of one-decision-point MVP weighted random experiments, disabled "Coming soon" affordances for Thompson Sampling where the UI needs to acknowledge the future option, lifecycle transitions, assignment-aware edit protection, compatibility handling for existing provider-shaped authored experiments, telemetry, security and performance review evidence, and targeted automated tests.

This plan covers FR-001, FR-002, FR-003, and FR-005 for implementation. FR-004 and AC-004 remain visible as deferred Thompson Sampling scope: this slice must not persist or activate Thompson Sampling experiments, and any UI affordance must be disabled with clear "Coming soon" copy until the Thompson Sampling policy slice is implemented. It satisfies AC-001 by replacing provider-specific authoring language and JSON workflow affordances in the new experiment management path, AC-002 by enforcing lifecycle and authorization rules for permitted collaborators and admins, AC-003 by validating weighted A/B/N configuration, and AC-005 by blocking unsafe condition changes after learner assignments exist.

Guardrails:
- Do not create a new broad React application shell for this slice; use existing LiveView or shared component patterns.
- Do not expose prior-provider labels, provider-migration language, the term "native", or JSON import/export controls in the new A/B Testing authoring path.
- Do not create new tables by default; reuse the A/B testing-owned persistence from the domain contract slice.
- Do not let LiveView, authoring, delivery, or analytics code insert or update private experiment schemas directly.
- Do not add feature flags for this slice; rollout uses normal deployment sequencing and authorization.
- Do not mutate published revisions when configuring experiments.
- Do not implement Thompson Sampling creation, policy configuration, activation, posterior updates, or guardrail validation in this slice.
- Do not allow disabled Thompson Sampling UI to submit, persist, or activate an adaptive experiment.

## Clarifications & Default Assumptions
- This slice depends on the domain contract and native delivery runtime being available before authoring controls broadly enable active weighted random experiments.
- MVP authoring supports exactly one alternatives decision point per experiment.
- New experiments are project-scoped and use existing alternatives groups as decision points; they are not created from current provider-specific alternatives revisions.
- Current provider-shaped authored experiment revisions remain supported through compatibility behavior, but they are not imported, migrated, or offered as templates for new A/B Testing records.
- Accepted project collaborators, content admins, account admins, and system admins can start, pause, complete, and archive experiments.
- Thompson Sampling is deferred until the dedicated policy work is implemented. If shown in the authoring UI, it is disabled and labelled "Coming soon"; it is not selectable, persisted, or activation-eligible.
- Scenario coverage is expected if the implementation spans authoring, publishing, section delivery, enrollment, assignment, and blocked unsafe edits.
- Jira issue tracking is expected for execution tracking; link the issue or ticket in implementation PRs when available.

## Phase 1: Authoring Graph Context APIs
- Goal: Add project-level weighted random experiment graph read/write APIs in `Oli.Experiments` for FR-002, FR-003, AC-002, and AC-003, while explicitly rejecting deferred Thompson Sampling creation.
- Tasks:
  - [x] Add or extend public authoring request structs for experiment definition fields, one decision point, conditions, and policy configuration.
  - [x] Implement `list_project_experiments/1`, `get_experiment_authoring_view/2`, and `list_available_decision_points/1` behind `%Oli.Experiments.Scope{}` validation.
  - [x] Implement create and draft-update graph commands that persist definition, decision point, conditions, and initial policy state in one transaction.
  - [x] Validate project-only authoring scope, alternatives resource/revision existence, unique condition codes, option mapping, active condition count, and slug uniqueness per project.
  - [x] Normalize weighted random configuration by accepting non-negative weights with positive active total weight.
  - [x] Reject Thompson Sampling algorithm requests with a form-safe unavailable error until the dedicated Thompson Sampling policy slice is complete.
  - [x] Return public structs or form-safe view models and `%ExperimentError{}` values, not private Ecto schemas.
  - [x] Emit telemetry for successful creation, successful update, and validation failures with non-sensitive metadata.
- Testing Tasks:
  - [x] Add ExUnit context tests for creating weighted random experiments with one valid alternatives decision point and condition weights.
  - [x] Add ExUnit context tests for rejecting section-scoped create/update requests, invalid alternatives references, duplicate condition codes, fewer than two active conditions, negative weights, and zero total active weight.
  - [x] Add ExUnit context tests proving Thompson Sampling create/update requests are rejected as unavailable and do not persist adaptive policy config.
  - [x] Add tests proving public authoring APIs do not return private schema structs.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Project-scoped authoring commands can create and update draft experiment graphs through `Oli.Experiments`.
  - Weighted random authoring validations cover FR-003.
  - Deferred Thompson Sampling requests are blocked with clear errors and no persisted adaptive config.
  - Telemetry is emitted for create/update success and validation failure without sensitive payloads.
- Gate:
  - Context API tests and formatting pass before LiveView create/edit wiring starts.
- Dependencies:
  - A/B testing persistence, public scope structs, weighted random policy support, and lifecycle functions from prior A/B testing slices.
- Parallelizable Work:
  - Read-model work and request-struct validation can proceed in parallel once the public payload shape is agreed.

## Phase 2: Lifecycle And Assignment-Aware Edit Rules
- Goal: Enforce lifecycle transitions, authorization, and assignment-stability rules for FR-002, FR-005, AC-002, and AC-005.
- Tasks:
  - [x] Harden `activate_experiment/2`, `pause_experiment/2`, `complete_experiment/2`, and `archive_experiment/2` for the authoring surface state machine.
  - [x] Add explicit authorization checks for accepted project collaborators, content admins, account admins, system admins, and unauthorized authors.
  - [x] Validate activation prerequisites: one decision point, at least two active conditions, valid policy config, alternatives content match, and valid condition-to-option mapping.
  - [x] Define edit allowances by state: full draft edits, limited paused metadata and safe weight edits, active metadata-only edits, and read-only completed or archived experiments.
  - [x] Block assigned-condition deletion, condition-code changes, option remapping, algorithm changes, Thompson Sampling activation, and deactivation of assigned conditions after assignments exist.
  - [x] Ensure pause, complete, and archive preserve assignments, exposures, rewards, policy state, and analytics evidence.
  - [x] Emit telemetry for lifecycle transition success and failure with previous state, target state, actor, project, and experiment IDs.
- Testing Tasks:
  - [x] Add ExUnit lifecycle tests for draft, active, paused, completed, and archived state transitions.
  - [x] Add authorization tests covering accepted collaborators, content admins, account admins, system admins, pending collaborators, unrelated authors, and cross-institution users.
  - [x] Add assignment-aware edit tests for rejecting algorithm changes, condition-code changes, option remapping, deletion, and assigned-condition deactivation after assignments exist.
  - [x] Add activation validation tests for alternatives drift, invalid weighted random policy state, and unavailable Thompson Sampling algorithm state.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Lifecycle commands enforce state and role rules required by AC-002.
  - Unsafe edits after learner assignments produce safe, explicit errors required by AC-005.
  - Runtime evidence remains intact across lifecycle transitions.
- Gate:
  - Lifecycle, authorization, and assignment-aware edit tests pass before UI lifecycle controls are enabled.
- Dependencies:
  - Phase 1 authoring graph APIs.
  - Native delivery assignment records from the delivery runtime slice.
- Parallelizable Work:
  - Authorization tests and assignment-aware edit tests can be implemented independently once lifecycle command boundaries are stable.

## Phase 3: Course-Author LiveView Management Surface
- Goal: Deliver the weighted random A/B Testing authoring UI for FR-001, FR-002, FR-003, FR-005, AC-001, AC-002, AC-003, and AC-005 inside the existing course-author workspace, with disabled deferred UI for FR-004/AC-004 where useful.
- Tasks:
  - [x] Update `OliWeb.Workspaces.CourseAuthor.ExperimentsLive` to list project experiments, lifecycle status, algorithm, active condition count, and archived visibility using `Oli.Experiments` read models.
  - [x] Add create/edit forms for selecting an existing alternatives group, naming the experiment, configuring slug, condition labels, active flags, weights, and algorithm choice.
  - [x] Add disabled Thompson Sampling affordance only if product/design wants the future option visible; label it "Coming soon" and prevent selection or submission.
  - [x] Add lifecycle actions for start, pause, complete, and archive with state-aware visibility and authorization-aware button rendering.
  - [x] Translate `%ExperimentError{}` values into field-level or form-level LiveView validation errors with clear assignment-stability language.
  - [x] Remove or hide prior-provider labels, provider-migration language, the term "native", and JSON import/export/download affordances from the new A/B Testing management path.
  - [x] Ensure `OliWeb.Live.Experiments.ExperimentsLive` delegates to shared A/B Testing behavior or is narrowed so it cannot reintroduce obsolete workflows.
  - [x] Keep ordinary alternatives authoring responsible for alternatives groups and stop using provider-specific alternatives revisions for new experiment creation.
- Testing Tasks:
  - [x] Add LiveView tests for listing experiments and lifecycle statuses.
  - [x] Add LiveView tests for successful weighted random creation and invalid-weight validation.
  - [x] Add LiveView tests proving Thompson Sampling is disabled or absent, and cannot be selected, submitted, persisted, or activated.
  - [x] Add LiveView tests for lifecycle button visibility by state and role.
  - [x] Add LiveView tests proving the new creation and management path does not render prior-provider labels, provider-migration language, the term "native", or JSON import/export/download controls.
  - [x] Add accessibility-oriented assertions for labels, form errors, disabled controls, and status text where supported by existing test patterns.
  - Command(s): `mix test <targeted course-author experiments LiveView test file>`
  - Command(s): `mix format`
- Definition of Done:
  - Authors can create, edit, validate, start, pause, complete, and archive MVP experiments from the course-author workspace.
  - Implemented authoring supports weighted random experiments only; Thompson Sampling remains clearly deferred and non-submittable.
  - The UI language and controls satisfy AC-001 without obsolete workflow affordances.
  - UI orchestration remains in LiveView while domain rules remain in `Oli.Experiments`.
- Gate:
  - LiveView tests and targeted context tests pass before compatibility and workflow coverage are finalized.
- Dependencies:
  - Phases 1 and 2.
  - Existing course-author project access and collaboration authorization patterns.
- Parallelizable Work:
  - Form rendering, lifecycle action rendering, and terminology/static-text tests can be split after the context view model is stable.

## Phase 4: Compatibility, Coupling, And Static Guardrails
- Goal: Preserve supported current authored experiment behavior while preventing new provider-shaped workflows from leaking into A/B Testing authoring for FR-001 and AC-001.
- Tasks:
  - [x] Narrow `Oli.Authoring.Experiments` to compatibility detection or read support for current provider-shaped authored experiment revisions.
  - [x] Ensure new A/B Testing creation cannot use provider-specific alternatives revisions as source records or templates.
  - [x] Preserve current provider-shaped authored experiments through read/display compatibility without offering migration, new-experiment-from-legacy, or JSON import/export actions.
  - [x] Search authoring paths for prior-provider terminology, provider-migration language, the term "native", and JSON workflow affordances that would appear in the new management path.
  - [x] Add or update static coupling checks proving `lib/oli_web/`, `lib/oli/authoring/`, and delivery modules do not write private experiment schemas directly.
  - [x] Search for enabled Thompson Sampling controls or adaptive policy persistence in this slice and confirm they are absent.
  - [x] Review query shapes for project experiment lists, activation validation, and assignment-aware edit checks for indexed access and bounded scans.
- Testing Tasks:
  - [x] Add tests for compatibility display or read behavior for current provider-shaped authored experiment revisions.
  - [x] Add tests proving legacy records cannot be used as templates for new A/B Testing records.
  - [x] Add static or LiveView assertions proving deferred Thompson Sampling UI is either absent or disabled with "Coming soon" copy.
  - [x] Add static or unit checks for prohibited terminology and direct private-schema writes where practical.
  - [x] Add performance-focused query review notes to PR evidence.
  - Command(s): `mix test <targeted compatibility test file>`
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Current provider-shaped authored experiment revisions remain supported according to the FDD compatibility rule.
  - New experiment authoring is A/B Testing record-based and free of JSON workflow and prior-provider creation paths.
  - Thompson Sampling implementation is not accidentally introduced through UI, context commands, or policy config persistence.
  - Security and performance review evidence is ready for PR review.
- Gate:
  - Compatibility tests, static terminology review, coupling guardrails, and query review pass before end-to-end scenario work closes the slice.
- Dependencies:
  - Phase 3 UI paths and existing compatibility entry points.
- Parallelizable Work:
  - Static terminology review and coupling checks can run alongside compatibility tests.

## Phase 5: Scenario Coverage And Final Validation
- Goal: Prove the weighted random authoring lifecycle workflow and close implemented FR-001, FR-002, FR-003, and FR-005 with traceability, tests, and harness validation while documenting FR-004/AC-004 as deferred.
- Tasks:
  - [x] Use the repo-local `build_scenario` skill if authoring new `Oli.Scenarios` files for this phase.
  - [x] Add scenario coverage that creates alternatives, creates an A/B Testing experiment, activates it, publishes, delivers to a learner, records assignment, and verifies a later unsafe condition edit is blocked.
  - [x] Add fallback or inactive-state coverage if not already proven by delivery runtime scenarios and targeted tests.
  - [x] Confirm telemetry events exist for lifecycle transition attempts, validation failures, and successful creation.
  - [x] Confirm the PR notes call out Thompson Sampling as intentionally deferred, with disabled/coming-soon UI only and no activation path.
  - [x] Prepare PR notes covering requirement mapping, security review points, performance review points, telemetry events, test evidence, and linked Jira issue.
  - [x] Update PRD, FDD, requirements, or plan only if implementation materially differs from this plan.
- Testing Tasks:
  - [x] Validate any new scenario file with `Oli.Scenarios.validate_file/1`.
  - [x] Run the targeted scenario ExUnit test or scenario runner.
  - [x] Run targeted context and LiveView tests from earlier phases.
  - [x] Run formatting.
  - [x] Run harness traceability and work-item validation.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix test <targeted course-author experiments LiveView test file>`
  - Command(s): `mix test <targeted scenario test file>`
  - Command(s): `mix format`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/authoring_lifecycle --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/authoring_lifecycle --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/authoring_lifecycle --check plan`
- Definition of Done:
  - Targeted context, LiveView, compatibility, and scenario tests pass.
  - Thompson Sampling is documented as deferred and blocked in implemented paths.
  - Telemetry, security, performance, and issue-tracking evidence is captured for review.
  - Requirements traceability and plan validation pass.
- Gate:
  - The work item is implementation-ready only after targeted tests, `mix format`, scenario validation where applicable, and harness validation commands pass.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - PR evidence collection, telemetry review, and harness validation can proceed while final targeted test issues are resolved.

## Parallelization Notes
- Phase 1 should start first because LiveView forms and lifecycle buttons depend on stable context request and view-model shapes.
- Phase 2 can overlap with late Phase 1 work after experiment graph persistence and scope validation are available.
- Phase 3 can split into listing/status, create/edit forms, lifecycle actions, and terminology tests once context APIs are stable.
- Phase 4 static reviews can run continuously, but compatibility assertions should use the final UI and context creation paths.
- Phase 5 scenarios can be drafted early, but final assertions depend on lifecycle UI, delivery assignment records, and assignment-aware edit validation.
- Thompson Sampling follow-up work can proceed independently after the dedicated policy implementation is ready; this slice should leave only disabled UI affordances and explicit rejection tests.
- No Gleam or frontend React work is planned unless implementation discovers an existing client-side surface that already owns part of this authoring workflow.

## Phase Gate Summary
- Gate A: Authoring graph context APIs create and update project-scoped weighted random experiment records and explicitly reject Thompson Sampling creation until the policy slice is ready.
- Gate B: Lifecycle transitions, role authorization, and assignment-aware edit protection pass targeted context tests.
- Gate C: Course-author LiveView tests prove weighted random create/edit/lifecycle behavior, removal of obsolete terminology and JSON workflow controls, and disabled or absent Thompson Sampling controls.
- Gate D: Compatibility behavior preserves current provider-shaped authored experiments without creating new provider-shaped A/B Testing workflows.
- Gate E: Scenario coverage where applicable, telemetry review, security and performance evidence, formatting, targeted tests, and harness validation pass.

## Decision Log
### 2026-06-30 - Defer Thompson Sampling Implementation
- Change: Updated the plan so this slice implements weighted random authoring lifecycle and blocks Thompson Sampling creation, persistence, and activation.
- Reason: The parent epic now places Thompson Sampling after the weighted random authoring lifecycle slice.
- Evidence: `docs/exec-plans/current/epics/ab_testing/plan.md`; `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`; `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/fdd.md`.
- Impact: Thompson Sampling UI enablement, priors, guardrails, and adaptive activation move to `docs/exec-plans/current/epics/ab_testing/thompson_sampling/`.
