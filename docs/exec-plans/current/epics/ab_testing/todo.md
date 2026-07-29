# A/B Testing Epic Backlog

This document tracks unfinished findings and enhancements spanning the native A/B Testing epic. Items may affect experiment lifecycle, authoring, delivery, adaptive policies, analytics, or shared alternatives behavior.

## Backlog Summary

| ID          | Work item                                                   | Area                          | Priority | Status   |
| ----------- | ----------------------------------------------------------- | ----------------------------- | -------- | -------- |
| AB-TODO-001 | Prevent concurrent active experiments at one decision point | Experiment lifecycle          | High     | Open     |
| AB-TODO-002 | Configurable binary reward rules                            | Adaptive policy and analytics | Medium   | Proposed |
| AB-TODO-003 | Remove option-management actions from page-editor tabs      | Authoring UX                  | Medium   | Proposed |
| AB-TODO-004 | Support reordering alternatives options                     | Authoring and delivery        | Medium   | Proposed |
| AB-TODO-005 | Remove the legacy section experiment gate                   | Delivery runtime and schema   | High     | Proposed |

## AB-TODO-001: Prevent Concurrent Active Experiments At One Decision Point

- **Status:** Open
- **Priority:** High
- **Area:** Experiment lifecycle validation and runtime matching
- **Target slice:** Unscheduled

### Problem

Multiple active experiments can target the same stable A/B decision point within overlapping project and section scopes. Runtime matching currently orders matching experiments by ascending experiment ID and selects the first result. A newer experiment can therefore appear active to an author while an older experiment silently continues receiving assignments and exposures.

This can invalidate both weighted-random and Thompson Sampling experiments and make analytics appear empty or misleading for the newer experiment.

### Desired Outcome

Only one active experiment can target a stable decision point within overlapping delivery scopes. Lifecycle validation prevents conflicts, and runtime matching fails safely if persisted data is unexpectedly ambiguous.

### Requirements

- At most one active experiment may target a stable decision point in any overlapping delivery scope.
- Stable decision-point identity must use `alternatives_resource_id` plus `decision_point_key`.
- Activation must reject a conflicting experiment before changing lifecycle state.
- Conflict detection must account for:
  - two project-scoped experiments;
  - two experiments sharing one or more participating sections;
  - a project-scoped experiment overlapping a section-participating experiment;
  - compatible published revisions of the same stable decision point.
- Runtime matching must not silently choose the oldest experiment if conflicting active records exist.
- Unexpected multiple matches must fail safely and emit diagnostic telemetry with non-sensitive experiment, project, section, and decision-point identifiers.

### Acceptance Criteria

- [ ] Starting a second conflicting experiment returns an actionable lifecycle error.
- [ ] Non-overlapping experiments may run concurrently.
- [ ] Pausing, completing, or archiving the active experiment allows a previously conflicting experiment to start.
- [ ] Runtime matching produces no experimental assignment when persisted state contains an unexpected ambiguity.
- [ ] Regression coverage includes project-scoped, section-overlap, and project-to-section conflict cases.

### Open Decisions

- Determine whether conflict prevention requires a database-level constraint, transactional lifecycle locking, application validation, or a combination.
- Define the exact overlap rule when participating sections change after activation.

### Dependencies

- Stable decision-point identity.
- Experiment section-participation semantics.
- Existing lifecycle transition and runtime matching contracts.

### Relevant Repository Areas

- `lib/oli/experiments.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/schemas/decision_point.ex`
- `lib/oli/experiments/schemas/experiment_section.ex`
- `test/oli/experiments/context_test.exs`
- `test/oli/experiments/runtime_test.exs`

## AB-TODO-002: Configurable Binary Reward Rules

- **Status:** Proposed
- **Priority:** Medium
- **Area:** Adaptive policy, reward handoff, and analytics
- **Target slice:** Future enhancement; excluded from the current Outcome Analytics MVP

### Problem

The existing Thompson Sampling policy consumes a fixed binary full-credit reward. Authors cannot configure what evaluated learner behavior counts as success, even when another binary rule would better represent the experiment outcome.

### Desired Outcome

An experiment author can configure how evaluated learner activity becomes the binary reward consumed by the existing Beta-Bernoulli Thompson Sampling policy.

The policy continues to receive exactly:

- `1.0` for success;
- `0.0` for failure.

This enhancement broadens the definition of success without changing the current Thompson Sampling reward model.

### Candidate Reward Rules

- Full credit: success when the score is 100%.
- Passing threshold: success when the normalized score meets or exceeds a configured threshold.
- Completion: success when the relevant activity is completed.
- Positive score: success when the normalized score is greater than zero.

### Requirements

- Store a normalized reward-rule definition with the experiment configuration.
- Validate the rule before experiment activation.
- Evaluate the configured rule during reward handoff and continue emitting only `0.0` or `1.0`.
- Include the reward-rule type, parameters, and version in durable experiment attribution evidence so historical rewards remain interpretable.
- Preserve the rule and version associated with previously emitted rewards if experiment configuration later changes.
- Expose the configured rule to experiment details and analytics through public `Oli.Experiments` contracts rather than private schema access.
- Label analytics charts with a fixed description of the configured binary success rule.
- Continue reporting average reward as the observed success proportion and show sample size.
- Do not describe descriptive differences as statistically significant.
- Ensure filters and exports preserve reward-rule provenance.

Example conceptual configuration:

```elixir
%{
  "reward" => %{
    "source" => "activity_attempt_score",
    "rule" => "score_at_least",
    "threshold" => 0.8,
    "version" => 1
  }
}
```

### Acceptance Criteria

- [ ] A configured threshold deterministically maps evaluated attempts to binary rewards.
- [ ] Invalid or incomplete reward configuration blocks activation.
- [ ] Thompson Sampling continues rejecting reward values other than `0.0` and `1.0`.
- [ ] Historical reward evidence identifies the rule and version used to produce it.
- [ ] Analytics can explain the success definition without requiring arbitrary metric metadata.

### Open Decisions

- Which reward rules authors may select.
- Which experiment types may configure the rule.
- Validation and user-facing explanation for thresholds.
- Whether reward configuration may change after activation.
- How edits affect learners with existing assignments or previously observed rewards.
- What fixed display copy analytics should use for each rule.

### Dependencies

- Experiment policy configuration and lifecycle validation.
- Reward handoff and experiment attribution contracts.
- Analytics reward summaries and dataset exports.

### Explicitly Separate Follow-Up

Continuous, ordinal, or otherwise non-binary rewards require a different Thompson Sampling reward model and are not part of this enhancement. That work would require an explicit policy design, statistical review, policy versioning, migration strategy, and revised analytics semantics.

### Relevant Repository Areas

- `lib/oli/delivery/experiments/reward_handoff.ex`
- `lib/oli/experiments/policies/thompson_sampling.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/xapi/attributions.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`

## AB-TODO-003: Remove Option-Management Actions From Page-Editor Tabs

- **Status:** Proposed
- **Priority:** Medium
- **Area:** Page editor and alternatives authoring UX
- **Target slice:** Unscheduled

### Problem

The page editor exposes option-management affordances inside alternatives tabs. This duplicates Manage Alternatives behavior and adds complexity for both learner-preference alternatives and A/B decision points.

### Desired Outcome

The page editor is responsible for editing branch content, while Manage Alternatives is the single place for creating, renaming, and deleting options.

### Requirements

- Display every option from the selected alternatives group as a content-editing tab.
- Remove option create, rename, delete, and related action-menu affordances from page-editor tabs.
- Preserve branch content editing and make the selected option clear.
- Handle options added, removed, renamed, or reordered through Manage Alternatives without silently associating content with the wrong stable option ID.
- Provide an actionable stale-content state if an authored page still contains content for an option that no longer exists.
- Preserve stable option IDs when an option is renamed.
- Define lifecycle constraints for renaming or deleting options used by draft, active, paused, or completed experiments.
- Deleting or renaming an option must not silently associate existing page content, experiment conditions, or learner assignments with another option.

### Acceptance Criteria

- [ ] Page-editor alternatives tabs contain content-editing controls but no option-management actions.
- [ ] Every current option remains visible as a tab for branch-content editing.
- [ ] Renaming an option does not invalidate an existing experiment condition or learner assignment.
- [ ] Deleting an option used by an active or historical experiment is blocked or handled by an explicitly approved lifecycle rule.
- [ ] Frontend coverage verifies content editing, tab selection, stale-option handling, and the absence of option-management actions.

### Open Decisions

- Define the UX for page content associated with an option that was deleted before publication.
- Determine whether deletion should ever be allowed when historical experiments reference an option.

### Dependencies

- Stable alternatives option identifiers.
- Manage Alternatives option-management workflows.
- Experiment lifecycle rules for referenced options.

### Relevant Repository Areas

- `assets/src/components/resource/editors/AlternativesEditor.tsx`
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `lib/oli/experiments/schemas/condition.ex`
- alternatives resource and revision content handling under `lib/oli/resources/`
- page-editor alternatives tests under `assets/src/`

## AB-TODO-004: Support Reordering Alternatives Options

- **Status:** Proposed
- **Priority:** Medium
- **Area:** Manage Alternatives, page editor, delivery, and analytics
- **Target slice:** Unscheduled

### Problem

Alternative options need a predictable order in Manage Alternatives, page-editor tabs, delivery, experiment configuration, and analytics. Authors currently lack an explicit, stable reordering workflow.

### Desired Outcome

Authors can control alternative option order while newly created options default to ascending creation order. The selected order is represented consistently without changing stable option identity or existing learner assignments.

### Requirements

- Default options to ascending creation order.
- Allow authors to reorder options in Manage Alternatives.
- Keep page-editor tabs read-only with respect to option order.
- Persist order as stable domain data rather than deriving it from labels or transient client-side array position.
- Apply the same ordering consistently in:
  - Manage Alternatives;
  - page-editor tabs;
  - experiment condition setup;
  - delivery rendering;
  - analytics condition legends and tables.
- Preserve stable option IDs across reorder operations.
- Do not change sticky assignments when display order changes.
- Validate that first-option fallback behavior remains deliberate and predictable after reordering.
- Define how published revisions and section updates receive reordered options.
- Define lifecycle constraints for reordering options used by draft, active, paused, or completed experiments.

### Acceptance Criteria

- [ ] Newly created options appear after existing options by default.
- [ ] Authors can reorder options without deleting and recreating them.
- [ ] Reordered options render consistently across authoring, delivery, and analytics.
- [ ] Reordering does not invalidate an existing experiment condition or learner assignment.
- [ ] Frontend and backend coverage verify stable IDs and ordering across save, publish, section update, and delivery.

### Open Decisions

- Confirm whether the existing condition/option `position` field is the correct source of truth or whether alternatives option content needs an explicit order field.
- Define whether active experiments permit display-order changes.

### Dependencies

- Stable alternatives option identifiers.
- Alternatives resource/revision publishing behavior.
- Page-editor and delivery ordering contracts.
- Analytics condition-label ordering.

### Relevant Repository Areas

- `assets/src/components/resource/editors/AlternativesEditor.tsx`
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `lib/oli/experiments/schemas/condition.ex`
- alternatives resource and revision content handling under `lib/oli/resources/`
- page-editor alternatives tests under `assets/src/`

## AB-TODO-005: Remove The Legacy Section Experiment Gate

- **Status:** Proposed
- **Priority:** High
- **Area:** Delivery runtime, experiment attribution, section creation, and schema cleanup
- **Target slice:** Focused native-runtime cleanup

### Problem

`sections.has_experiments` remains as a legacy coarse gate even though native experiment section participation is represented by `experiment_sections` and runtime assignment records.

The project Overview `experiments_enabled` toggle is an authoring capability switch. It must not bulk-update live sections or implicitly enroll every section in experiments. Section participation is configured per experiment and must remain authoritative.

The legacy section flag currently affects:

- traditional page delivery, where it controls whether the base project slug and enrollment are added to the rendering context;
- student onboarding delivery, where it controls the same rendering-context values;
- evaluated-attempt attribution, where it short-circuits attribution processing before assignment records are inspected;
- section creation and publication-update code that copies or synchronizes a project-level boolean into sections.

These gates are redundant or too coarse for native experiments and can suppress valid behavior for a participating section when the boolean is stale.

### Desired Outcome

Native experiment behavior depends only on explicit experiment lifecycle, `experiment_sections` participation, enrollments, assignments, and durable attribution records. The project authoring toggle controls authoring UI availability only. Delivery sections are not mutated when that toggle changes, and `sections.has_experiments` is removed.

### Requirements

- Do not synchronize section state when `projects.experiments_enabled` changes.
- Traditional page delivery and student onboarding must provide the project and enrollment context required by native decision handling without consulting `sections.has_experiments`.
- Evaluated-attempt attribution must use actual assignments or native section participation rather than the legacy boolean.
- Preserve the fast empty-result path when an attempt has no experiment assignments or attribution evidence.
- Remove all section creation, blueprint creation, open-and-free creation, and publication-update logic that copies or synchronizes `has_experiments`.
- Remove `has_experiments` from the section schema and changesets.
- Generate a standard Ecto migration that:
  - defines explicit `up/0` and `down/0`;
  - removes `sections.has_experiments` in `up/0`;
  - restores it with the compatible boolean default in `down/0`.
- Update factories, fixtures, scenarios, and tests that set or assert the legacy field.
- Do not replace the section field with `experiments_enabled`; authoring enablement and experiment participation are separate concepts.
- Evaluate the now-unused `projects.has_experiments` column separately and remove it in the same migration only if no remaining compatibility contract requires it.

### Acceptance Criteria

- [ ] Changing the project Overview experiment toggle does not mutate existing sections.
- [ ] A section selected through native experiment participation receives decisions and attribution without a legacy section boolean.
- [ ] A section not selected for an experiment receives no assignment, exposure, outcome, or reward records.
- [ ] Traditional page delivery and student onboarding continue rendering successfully with the required project and enrollment context.
- [ ] Attempt attribution returns an empty result when no relevant assignments exist.
- [ ] No production code reads, writes, copies, or synchronizes `sections.has_experiments`.
- [ ] Migration up and down behavior is verified.
- [ ] Targeted delivery, attribution, section creation/update, and native A/B runtime scenario tests pass.

### Open Decisions

- Confirm whether traditional controller-based page delivery and student onboarding still require both project slug and enrollment for non-experiment alternatives behavior; avoid adding unnecessary queries if a narrower native-participation lookup is appropriate.
- Decide whether `projects.has_experiments` can be removed in the same schema migration or needs a short compatibility window.
- Decide whether the attribution fast path should check assignments, experiment participation, or both based on the cheapest indexed query.

### Dependencies

- Native `experiment_sections` participation.
- Native assignment and attribution persistence.
- Delivery rendering context contracts.
- Existing A/B delivery runtime scenario coverage.

### Relevant Repository Areas

- `lib/oli_web/controllers/page_delivery_controller.ex`
- `lib/oli_web/live/delivery/student_onboarding/survey.ex`
- `lib/oli/delivery/experiments/attempt_attributions.ex`
- `lib/oli/delivery/experiments/page_decisions.ex`
- `lib/oli/delivery.ex`
- `lib/oli/delivery/sections.ex`
- `lib/oli/delivery/sections/updates.ex`
- `lib/oli/delivery/sections/section.ex`
- `lib/oli_web/controllers/open_and_free_controller.ex`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/schemas/experiment_section.ex`
- `test/oli/delivery/experiments/attempt_attributions_test.exs`
- `test/oli/resources/alternatives_test.exs`
- `test/scenarios/delivery/ab_testing_delivery_runtime.scenario.yaml`

---

OTHER

- [ ] Alternatives and A/B Test content elements should only be available to insert into a page when the features are enabled for a project. Otherwise these icons should not be visisble in the insert content menu.
- [ ] When in the Manage Alternatives view, the Create > Alternatives sidebar link should be
