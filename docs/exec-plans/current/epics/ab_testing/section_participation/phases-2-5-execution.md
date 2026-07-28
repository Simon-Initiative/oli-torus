# Phases 2-5 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/section_participation`
Phases: `2-5`

## Scope from plan.md
- Add authorized transactional participation read/write APIs and safe telemetry.
- Enforce current participation across assignment, exposure, outcome, reward, and policy updates.
- Add accessible experiment section configuration and preserve Insights selector behavior.
- Prove the authoring-to-delivery workflow with no-fixture scenario coverage and close release gates.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

The experiment form uses a native semantic checkbox fieldset for serialized section IDs while the
shared `MultiSelectInput` was independently made source-controlled and accessible for its existing
Insights consumers. This keeps the initial experiment form keyboard-native and avoids hidden-field
coordination between nested LiveComponents.

The final authoring pass moved experiment creation into a policy-first modal and replaced inline
section configuration with a dedicated experiment details route. That route presents the original
decision point, conditions, policy configuration, and a ten-row paginated table whose checkboxes
persist participation changes immediately. Experiment archiving is exposed only after completion.

Manual `has_experiments` toggles were removed from course-author experiment and overview screens.
Native existence is now derived through `Oli.Experiments.project_has_experiments?/1`, which returns
true for any draft, active, paused, or completed native experiment and false when none exist or all
are archived. The persisted project/section flags remain temporarily for legacy delivery paths only.

## Review Loop
- Round 1 findings: remix create/update validation used the legacy base-project rule; eligibility
  queries could duplicate rows; participation fallbacks lacked a distinct reason; malformed UI IDs
  could crash; the initial eligible-section query blocked rendering; and the shared multi-select had
  controlled-state and accessibility defects.
- Round 1 fixes: unified create/update and configuration validation on the canonical eligibility
  query, added distinct DTO projections and classified fallback telemetry, made UI ID parsing strict,
  moved eligibility loading to explicit async states, and corrected multi-select semantics.
- Round 2 findings: reviewers requested explicit loading/error presentation, table semantics, and
  scenario proof that nonparticipating delivery renders the first alternative.
- Round 2 fixes: added loading/error states, caption/scoped headers, and rendered-output assertions
  for both unselected and post-deselection scenario paths.

The requirements review also questioned the absence of an institution ID in the course-author
workspace scope. No code change was made for that point because the approved FDD explicitly states
that institution filtering applies when the caller carries an institution, while accepted
project-author access and the current project relationship remain mandatory in the workspace.

## Product Follow-ups
- Zero-section activation remains allowed and safely falls back.
- A stale row can reactivate if eligibility returns before it is removed.
- Revisit a searchable modal when real project section counts exceed the checkbox-list usability threshold.

## Scenario Guardrails
- Updated `test/scenarios/delivery/ab_testing_delivery_runtime.scenario.yaml`.
- Uses `Oli.Scenarios.execute_file/2`.
- No fixtures, factories, or mocks were introduced for scenario domain setup.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes

Verification: `mix format`, `mix compile --warnings-as-errors`, and the targeted 160-test suite pass
with zero failures. Requirements FDD, plan, and implementation proof gates pass, as does the full
work-item validator.
