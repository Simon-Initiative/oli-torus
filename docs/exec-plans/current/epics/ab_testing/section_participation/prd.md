# Experiment Section Participation - Product Requirements Document

## 1. Overview
Add explicit section participation controls to experiment configuration. An authorized experiment researcher selects which eligible active sections participate in a project-authored experiment. Learners in every other section receive the first decision-point choice and do not generate experiment assignment, exposure, outcome, reward, or policy-update evidence for that experiment.

## 2. Background & Problem Statement
Project-authored experiments can affect sections created from the project and sections that currently remix its content. Without per-experiment section selection, Torus cannot distinguish intentional research populations from other learners who happen to encounter the same decision points. This risks generating unwanted research data and exposing learners in nonparticipating sections to experimental choices. Participation must therefore be explicit, scoped to each experiment, and enforced by the delivery runtime.

## 3. Goals & Non-Goals
### Goals
- Let authorized experiment researchers select participating sections while configuring an experiment.
- Limit selection to active sections created from or currently remixing content from the experiment's project.
- Persist participation independently for each experiment and section.
- Apply experimental assignment and telemetry only in selected, still-eligible sections.
- Present the first decision-point choice to learners when their section is not participating.

### Non-Goals
- Author experiments independently within sections.
- Automatically enroll newly created or newly remixed sections in existing experiments.
- Let instructors opt their sections into experiments outside the experiment configuration page.
- Add template or product inheritance rules for experiment participation.
- Redesign experiment analytics beyond distinguishing participating from nonparticipating sections.

## 4. Users & Use Cases
- Experiment researchers and authorized authors: choose the active course sections that form an experiment's intended research population.
- Learners in participating sections: receive sticky experiment assignments and contribute experiment evidence under existing runtime rules.
- Learners in nonparticipating sections: receive the default first choice at decision points without entering the experiment.
- Administrators and research reviewers: rely on scoped experiment evidence that excludes nonparticipating sections.

## 5. UX / UI Requirements
- The experiment configuration page must include a multi-select control or equivalent list of eligible active sections.
- Reuse or adapt the existing `OliWeb.Common.MultiSelectInput` interaction pattern from `lib/oli_web/live/common/multi_select.ex`, as used for section filtering in `lib/oli_web/live/workspaces/course_author/insights_live.ex`, unless implementation discovery shows that its dropdown/chip pattern cannot meet this form's accessibility or persisted-selection requirements.
- Each option must identify the section clearly enough for a researcher to distinguish sections with similar titles, using established section identifiers or metadata where available.
- Existing selections must be visible when editing an experiment.
- The control must communicate that unselected sections use the first choice and do not participate in the experiment.
- Empty eligible-section and empty-selection states must be clear and must not imply that all sections participate.
- If a previously selected section is no longer eligible, the configuration page must identify that stale selection and prevent it from being treated as active participation.
- The control and its validation feedback must follow existing LiveView accessibility and interaction patterns.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Eligibility and participation reads and writes must enforce institution, project, experiment, section, and author authorization boundaries.
- Participation checks must be suitable for the learner delivery hot path and must not introduce remote service calls or unbounded section queries.
- Concurrent configuration updates must not create duplicate participation records or allow an ineligible section to remain actively participating.
- The selector must be keyboard operable, expose accessible labels and state, and use existing internationalization conventions for user-facing copy.
- Experiment telemetry must not contain unnecessary learner data and must not be emitted for a nonparticipating section.

## 9. Data, Interfaces & Dependencies
- The A/B testing domain owns the experiment-to-section participation relationship and exposes authoring and delivery APIs for managing and checking it.
- Eligibility depends on active section state and reliable relationships showing that a section was created from, or currently remixes content from, the experiment's project.
- `Oli.Delivery.Sections.get_sections_containing_resources_of_given_project/1`, currently consumed by the course-author Insights section selector, is the preferred eligibility-query starting point. It must be verified or narrowed to return only active, selectable sections under the experiment authorization boundary.
- Delivery depends on the existing experiment scope, assignment, exposure, outcome, reward, policy-update, and first-option fallback contracts.
- Existing experiment analytics and xAPI/ClickHouse projections must treat experiment-section participation as the boundary for valid experiment evidence.
- This work depends on `domain_contract`, `delivery_runtime`, and `authoring_lifecycle`.

## 10. Repository & Platform Considerations
- Put eligibility, authorization, persistence, and runtime gating rules in the relevant Elixir contexts; keep LiveView focused on interaction and rendering.
- Respect publication immutability: participation changes delivery selection behavior but do not mutate published revisions.
- Use established section/project/publication relationships, including remix relationships, rather than inferring eligibility solely from a section's base project.
- Prefer adapting `OliWeb.Common.MultiSelectInput` and its `OliWeb.Common.MultiSelect.Option` model over introducing a new section-selection control. The adaptation must support initial selected values when editing, stable selection state across LiveView updates, an explicit empty state, stale selected-section presentation, accessible expanded/collapsed and checkbox semantics, and form submission compatible with experiment `section_ids`.
- Add targeted ExUnit and LiveView coverage, plus an `Oli.Scenarios` workflow because the behavior spans project authoring, publication/remix, section configuration, enrollment, and learner delivery.
- Changes require review under repository requirements, UI, Elixir, security, and performance guidance.
- Jira remains the implementation tracking system of record; this PRD does not create or update a Jira issue.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track successful participation configuration changes, rejected ineligible selections, stale selected sections, and delivery fallback caused by nonparticipation.
- Do not include raw learner responses or unnecessary learner identity in configuration telemetry.
- Success means experiment evidence is generated only for selected eligible sections, while nonparticipating sections consistently render the first choice.

## 13. Risks & Mitigations
- Risk: Remix relationships become stale or are resolved against the wrong source project. Mitigation: centralize eligibility resolution and test base-project, current-remix, removed-remix, and unrelated-section cases.
- Risk: A section is deactivated or stops remixing the project after selection. Mitigation: require eligibility at delivery time and treat stale participation as nonparticipation with first-option fallback.
- Risk: Participation checks slow learner rendering. Mitigation: expose a scoped domain query suitable for the hot path and review query shape for indexes and N+1 behavior.
- Risk: Researchers assume unselected sections are implicitly enrolled. Mitigation: use explicit copy and make empty selection mean no participating sections.
- Risk: Existing assignments leak into a section after it is deselected. Mitigation: gate assignment reuse and all subsequent experiment evidence on current participation, while retaining historical evidence for auditability.

## 14. Open Questions & Assumptions
### Open Questions
- Should a stale participation record be retained as inactive history or removed when a section becomes ineligible?
- Should experiment activation require at least one participating section, or may an active experiment intentionally have none?

### Assumptions
- "Active section" uses the repository's canonical section availability/status rules.
- "Currently remixed from the project" means the section currently has a valid source-project/publication relationship to content from the experiment's project; a removed remix no longer establishes eligibility.
- Empty selection means no sections participate; it never means all eligible sections participate.
- Newly eligible sections are not selected automatically.
- Deselecting a section stops new assignment reuse and experiment evidence in that section but does not delete historical assignments or analytics.
- Experiment researchers have the same accepted project collaboration or administrative permissions used to configure the experiment.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for eligibility across base-project, current-remix, removed-remix, inactive, unrelated, cross-institution, and unauthorized section cases.
  - Context tests for idempotent selection updates, deselection, stale selections, concurrent writes, and per-experiment isolation.
  - LiveView tests for option filtering, selected state, empty states, validation messages, authorization, and accessibility-relevant markup.
  - Scenario coverage proving a participating section receives sticky assignment and emits experiment evidence while an otherwise eligible but unselected section receives the first choice and emits none.
  - Regression tests proving deselection or loss of eligibility immediately restores first-option fallback without deleting historical evidence.
- Manual validation:
  - Configure an experiment with sections created from and remixing the source project, verify unrelated and inactive sections are unavailable, and confirm saved selections persist.
  - Visit the same decision point as learners in selected and unselected sections and verify experimental versus first-choice behavior and analytics evidence.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
