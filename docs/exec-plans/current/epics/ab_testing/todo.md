# A/B Testing Epic TODO Tracker

This document tracks unfinished findings and enhancements spanning the native A/B Testing epic. Items may affect experiment lifecycle, authoring, delivery, adaptive policies, analytics, or shared alternatives behavior.

## Configurable Binary Reward Rules

### Status

Future enhancement; not part of the current Outcome Analytics MVP.

### Objective

Allow an experiment author to configure how evaluated learner activity becomes the binary reward consumed by the existing Thompson Sampling policy.

The policy must continue to receive exactly:

- `1.0` for success;
- `0.0` for failure.

This enhancement broadens the definition of success without changing the current Beta-Bernoulli Thompson Sampling model.

### Candidate Reward Rules

- Full credit: success when the score is 100%.
- Passing threshold: success when the normalized score meets or exceeds a configured threshold.
- Completion: success when the relevant activity is completed.
- Positive score: success when the normalized score is greater than zero.

### Product Requirements To Define

- Which reward rules authors may select.
- Which experiment types may configure the rule.
- Validation and user-facing explanation for thresholds.
- Whether reward configuration may change after activation.
- How edits affect learners with existing assignments or previously observed rewards.
- What fixed display copy analytics should use for each rule.

### Data And Interface Considerations

- Store a normalized reward-rule definition with the experiment configuration.
- Validate the rule before experiment activation.
- Evaluate the configured rule during reward handoff and continue emitting only `0.0` or `1.0`.
- Include the reward-rule type, parameters, and version in durable experiment attribution evidence so historical rewards remain interpretable.
- Preserve the rule/version associated with previously emitted rewards if experiment configuration later changes.
- Expose the configured rule to experiment details and analytics through public `Oli.Experiments` contracts rather than private schema access.

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

### Analytics Considerations

- Label charts with a fixed description of the configured binary success rule.
- Continue reporting average reward as the observed success proportion.
- Show sample size with condition-level reward summaries.
- Do not describe descriptive differences as statistically significant.
- Ensure filters and exports preserve reward-rule provenance.

### Acceptance Considerations

- A configured threshold deterministically maps evaluated attempts to binary rewards.
- Invalid or incomplete reward configuration blocks activation.
- Thompson Sampling continues rejecting reward values other than `0.0` and `1.0`.
- Historical reward evidence identifies the rule and version used to produce it.
- Analytics can explain the success definition without requiring arbitrary metric metadata.

### Explicitly Separate Follow-Up

Continuous, ordinal, or otherwise non-binary rewards require a different Thompson Sampling reward model and are not part of this enhancement. That work would require an explicit policy design, statistical review, policy versioning, migration strategy, and revised analytics semantics.

### Relevant Repository Areas

- `lib/oli/delivery/experiments/reward_handoff.ex`
- `lib/oli/experiments/policies/thompson_sampling.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/xapi/attributions.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`

## Prevent Concurrent Active Experiments At One Decision Point

### Status

Open, high severity.

### Problem

Multiple active experiments can target the same stable A/B decision point within overlapping project and section scopes. Runtime matching currently orders matching experiments by ascending experiment ID and selects the first result. A newer experiment can therefore appear active to an author while an older experiment silently continues receiving assignments and exposures.

This can invalidate both weighted-random and Thompson Sampling experiments and make analytics appear empty or misleading for the newer experiment.

### Required Behavior

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

### Acceptance Considerations

- Starting a second conflicting experiment returns an actionable lifecycle error.
- Non-overlapping experiments may run concurrently.
- Pausing, completing, or archiving the active experiment allows a previously conflicting experiment to start.
- Runtime matching produces no experimental assignment when persisted state contains an unexpected ambiguity.
- Regression coverage includes project-scoped, section-overlap, and project-to-section conflict cases.

### Relevant Repository Areas

- `lib/oli/experiments.ex`
- `lib/oli/experiments/schemas/experiment_definition.ex`
- `lib/oli/experiments/schemas/decision_point.ex`
- `lib/oli/experiments/schemas/experiment_section.ex`
- `test/oli/experiments/context_test.exs`
- `test/oli/experiments/runtime_test.exs`

## Centralize Alternative Option Management

### Status

Proposed enhancement.

### Objective

Make the page editor responsible for editing branch content, while Manage Alternatives remains the single place for creating, renaming, deleting, and reordering options for both learner-preference alternatives and A/B decision points.

### Page Editor Requirements

- Display every option from the selected alternatives group as a content-editing tab.
- Remove option create, rename, delete, and related action-menu affordances from page-editor tabs.
- Preserve branch content editing and make the selected option clear.
- Handle options added, removed, renamed, or reordered through Manage Alternatives without silently associating content with the wrong stable option ID.
- Provide an actionable stale-content state if an authored page still contains content for an option that no longer exists.

### Manage Alternatives Requirements

- Own option creation, rename, deletion, and ordering.
- Default options to ascending creation order.
- Allow authors to reorder options explicitly.
- Persist order as stable domain data rather than deriving it from labels or client-side array position.
- Apply the same ordering consistently in:
  - Manage Alternatives;
  - page-editor tabs;
  - experiment condition setup;
  - delivery rendering;
  - analytics condition legends and tables.
- Define lifecycle constraints for reordering, renaming, or deleting options used by draft, active, paused, or completed experiments.

### Data And Compatibility Considerations

- Confirm whether the existing condition/option `position` field is the correct source of truth or whether alternatives option content needs an explicit order field.
- Preserve stable option IDs across rename and reorder operations.
- Do not change sticky assignments when display order changes.
- Validate that first-option fallback behavior remains deliberate and predictable after reordering.
- Define how published revisions and section updates receive reordered options.

### Acceptance Considerations

- Page-editor alternatives tabs contain content-editing controls but no option-management actions.
- Newly created options appear after existing options by default.
- Reordered options render consistently across authoring, delivery, and analytics.
- Renaming or reordering an option does not invalidate an existing experiment condition or learner assignment.
- Deleting an option used by an active or historical experiment is blocked or handled by an explicitly approved lifecycle rule.
- Frontend and backend coverage verify stable IDs and ordering across save, publish, section update, and delivery.

### Relevant Repository Areas

- `assets/src/components/resource/editors/AlternativesEditor.tsx`
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `lib/oli/experiments/schemas/condition.ex`
- alternatives resource and revision content handling under `lib/oli/resources/`
- page-editor alternatives tests under `assets/src/`
