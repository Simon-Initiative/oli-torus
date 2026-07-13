# A/B Testing QA Review - Slices 1-5

Manual QA notes for completed slices 1-5 of `docs/exec-plans/current/epics/ab_testing/plan.md`.

## Scope

- Native A/B Testing authoring and lifecycle.
- Weighted random experiments.
- Thompson Sampling experiments.
- Delivery assignment, sticky reuse, exposure/reward behavior, and policy inspection evidence.

## Session Notes

Manual QA of a weighted random experiment exposed that native experiments can currently be
created and started against a normal learner-preference alternatives group. Delivery then
uses the learner preference strategy instead of the native A/B assignment strategy, so no
experiment assignments are created.

The tested section and project both had A/B Testing enabled:

- Section `ab_testing`: `sections.has_experiments = true`
- Project `ab_testing_course`: `projects.has_experiments = true`

The active experiment was also correctly started:

- Experiment `3`, `test-experiment-2`, state `active`, algorithm `weighted_random`

## Findings

### [x] Finding 4: Active experiments are pinned to a specific alternatives revision

- Status: Fixed
- Severity: High
- Area: Experiment matching / publishing compatibility
- QA context: After adding a new A/B decision point to pages, publishing, and updating the section, the active experiment still pointed at the old alternatives resource/revision (`12673` / `23390`), while the section delivered a new A/B decision point resource/revision (`12675` / `23402`). No assignments were created.
- Expected: An experiment should remain attached to the intended decision point across normal authoring edits, publication, and section updates, as long as the decision point's condition options remain compatible.
- Actual: Runtime matching requires the exact `alternatives_revision_id`, so a published revision change prevents the active experiment from matching delivery content.
- Evidence:
  - `Oli.Resources.Alternatives.DecisionPointStrategy` sends both `alternatives_resource_id` and `alternatives_revision_id` to `Oli.Experiments.assign_condition/1`.
  - `Oli.Experiments.active_experiment_match/2` filters on `decision_point.alternatives_revision_id == request.alternatives_revision_id`.
  - `experiment_decision_points` stores both `alternatives_resource_id` and `alternatives_revision_id`.
- Proposed change:
  - Treat the alternatives resource ID plus decision point key as the stable decision-point identity for runtime matching.
  - Keep revision IDs for audit, validation, exposure metadata, and option-compatibility checks, but do not require an active experiment to match only one historical alternatives revision.
  - On activation and assignment, validate that the currently delivered revision is an A/B decision point and that active condition option IDs/codes still exist.
  - Add regression coverage proving an active experiment continues assigning after the A/B decision point is edited, republished, and delivered through a new revision with compatible options.
- Resolution:
  - Runtime active experiment matching now uses stable decision-point identity: `alternatives_resource_id` plus `decision_point_key`.
  - The delivered revision ID remains available on assignment requests and telemetry for audit/diagnostics, but no longer prevents matching compatible published revisions of the same decision point resource.
  - Added runtime regression coverage proving an active experiment assigns when delivery sends a newer compatible alternatives revision for the same decision point resource.

### [x] Finding 3: Weighted random QA assigned only Option 2 across initial learner sample

- Status: Fixed
- Severity: Medium
- Area: Delivery assignment / weighted random distribution
- QA context: After creating A/B decision points, adding them to pages, publishing, and updating the section, the learner-facing dropdown no longer appears. However, at least five tested students all saw Option 2 on both an unscored and scored page.
- Expected: A 50/50 weighted random experiment should produce sticky assignments by learner enrollment, with a mix of assigned conditions across enough distinct learners.
- Actual: The initial learner sample all saw Option 2.
- Current interpretation:
  - The missing dropdown indicates delivery is now using experiment-controlled A/B decision-point rendering rather than learner-preference alternatives.
  - Seeing the same option on both pages for the same learner is expected if both pages use the same A/B decision point, because assignment is sticky by experiment, decision point, and enrollment.
  - QA DB check showed no rows in `experiment_assignments` for experiment `3`, so learners are still seeing fallback content rather than assigned content.
  - `experiment_conditions` for experiment `3` are configured 50/50, but the condition codes come from the earlier alternatives options. The active experiment may not match the A/B decision point revision now published to the pages.
  - Because fallback displays the first option in the decision point, and Option 2 appears first in the options list, the visible "all Option 2" behavior is consistent with no active experiment match.
  - QA DB check found the section is now delivering published A/B decision point `AB Test Decision Point`, resource `12675`, revision `23402`.
  - The active experiment inspected earlier points to resource `12673`, revision `23390`, so the active experiment does not match the A/B decision point currently delivered by the section.
  - Follow-up QA after the revision-matching fix still showed no assignment rows. The remaining blocker was a condition-code mismatch: native experiment conditions use alternatives option IDs, but delivery sent available condition codes from option names.
- Follow-up QA:
  - Confirm assignment rows are being created. Current result: no rows for experiment `3`.
  - Confirm the tested students have distinct `enrollment_id` values.
  - Create a new experiment against resource `12675`, revision `23402`, then start it.
  - Archive or ignore experiment `3`, since it targets the old resource/revision and cannot assign learners for the current section content.
- Resolution:
  - Delivery now sends available condition codes using alternatives option IDs, falling back to names only when an ID is absent.
  - Delivery condition-to-rendered-option matching now accepts either option ID or option name for compatibility.
  - Regression coverage was updated so native decision-point assignment uses option IDs that differ from display names.
- Reopened evidence:
  - After restarting the server, archiving experiment `3`, creating and starting experiment `5` against delivered A/B decision point resource `12675` / revision `23402`, new learner access still created no rows in `experiment_assignments`.
  - Active experiment check shows experiment `5` is active and points to `AB Test Decision Point`.
- Final blocker:
  - Local DB verification showed experiment `5` is scoped to `institution_id = 1`, while open/free section `8` has `institution_id = NULL`.
  - Delivery assignment validation requires a scoped institution, so open/free delivery fell back before assignment creation even though the section, experiment, decision point, options, enrollments, and publication mapping were otherwise correct.
- Final resolution:
  - A/B decision-point delivery now infers the active experiment institution when the section/render context has no institution.
  - Experiment section validation now allows institutionless sections when the section belongs to the scoped project.
  - Added regression coverage proving an institutionless open/free section can still assign and record exposure for a native A/B decision point.
  - Verified against local `oli_dev` using the real experiment `5`, section `8`, enrollment `40`, and decision point `12675` in a rolled-back transaction. The full `Alternatives.select/2` path inserted an assignment and exposure before rollback.

### [x] Finding 1: Native experiment can target a normal learner-preference alternatives group

- Status: Fixed
- Severity: High
- Area: Authoring validation / alternatives strategy
- QA context: The delivery page shows the alternatives preference dropdown, `experiment_assignments` remains empty, and both project and section `has_experiments` are true.
- Expected: A native A/B Testing experiment should only be creatable/activatable against an alternatives group that delivery will route through the A/B decision-point strategy.
- Actual: The native experiment form appears to list available alternatives revisions without filtering or converting them by strategy. If the selected alternatives group has strategy `user_section_preference`, delivery uses `UserSectionPreferenceStrategy`, renders the selector, and never calls `Oli.Experiments.assign_condition/1`.
- Evidence:
  - `Oli.Rendering.Alternatives.maybe_render_preference_selector/5` renders the dropdown only when the alternatives resource strategy is `user_section_preference`.
  - `Oli.Resources.Alternatives.select/2` dispatches to `DecisionPointStrategy` only when the alternatives group strategy is `upgrade_decision_point`.
  - `Oli.Experiments.list_available_decision_points/1` maps alternatives revisions into decision-point candidates without checking the revision content strategy.
  - QA DB check: active experiment `3` points to alternatives revision `23390`; that revision has `content ->> 'strategy' = 'user_section_preference'`.
- Follow-up QA:
  - Confirmed the experiment alternatives revision content has `"strategy": "user_section_preference"`.
  - Confirmed the native experiment decision point references that same alternatives revision.
- Proposed change:
  - Authoring should either create/use experiment decision-point alternatives groups with strategy `upgrade_decision_point`, convert the selected group safely, or validate/block creation/activation when the selected alternatives group would not route delivery through the A/B assignment strategy.
  - Add regression coverage proving native experiment creation cannot silently target a learner-preference alternatives group that bypasses assignment.
- Resolution:
  - Native experiment candidates are now limited to alternatives revisions with strategy `upgrade_decision_point`.
  - Backend create/update/activation validation now rejects learner-preference alternatives as experiment decision points.
  - Regression coverage was added for both the context validation and LiveView candidate filtering.

### [x] Finding 2: Manage Alternatives does not expose a native path to create A/B decision points

- Status: Fixed
- Severity: High
- Area: Authoring UX / native experiment setup
- QA context: Under Manage Alternatives, only normal alternatives can be created. There is no visible action to create an A/B decision point suitable for native experiment assignment.
- Expected: Authors should have a straightforward native path to create or select an A/B decision point for experiment delivery.
- Actual: The visible course-author alternatives surface creates alternatives groups with `"strategy": "user_section_preference"` only.
- Evidence:
  - `lib/oli_web/live/workspaces/course_author/alternatives_live.ex` filters out existing `"upgrade_decision_point"` alternatives groups when listing Manage Alternatives.
  - The visible create path `create_group` persists `"strategy": "user_section_preference"`.
  - The module still contains legacy `show_create_experiment` copy for "Create Experiment Decision Point" / "Upgrade", but the current visible workflow does not expose a native A/B decision-point creation path.
- Proposed change:
  - Define the intended native authoring flow for decision points.
  - Either add a native "Create A/B decision point" action, have experiment creation create/convert the decision point, or redesign the experiment form to own decision-point setup directly.
  - Remove or replace stale UpGrade terminology in hidden/legacy paths.
- Resolution:
  - Manage Alternatives now shows a `New A/B Decision Point` action.
  - The new action creates alternatives resources with strategy `upgrade_decision_point`.
  - The stale visible UpGrade placeholder copy in that creation path was replaced with native A/B Testing copy.
  - Regression coverage was added for the new creation path.

## Enhancements

### [x] Enhancement 1: Page editor should allow selecting a specific A/B decision point

- Status: Fixed
- Area: Page editor / authoring UX
- Context: After creating a `New A/B Decision Point`, the page editor's normal `Select Alternatives Group` dropdown did not show it. The A/B Test insert path existed separately, but it automatically selected the first A/B decision point and did not let authors choose which one to insert.
- Desired behavior: Authors should be able to select the intended A/B decision point when inserting A/B Testing content into a page.
- Resolution:
  - The normal `Alt` insertion path remains scoped to learner-preference alternatives.
  - The `A/B Test` insertion path now opens a `Select A/B Decision Point` modal listing `upgrade_decision_point` groups.
  - Selecting a decision point inserts it with strategy `upgrade_decision_point` and creates child branches for its options.

### [x] Enhancement 2: Remove stale alternatives links to the old authoring view

- Status: Fixed
- Area: Page editor / authoring routing
- Context: The page editor modals linked to `/authoring/project/<project>/alternatives`, which opened the older alternatives UI instead of the current course-author workspace UI.
- Desired behavior: All alternatives management links should send authors to `/workspaces/course_author/<project>/alternatives`.
- Resolution:
  - Updated page editor modal links for `Manage Alternatives`, `Manage A/B Decision Points`, and A/B option management.
  - Removed the old `/authoring/project/:project_id/alternatives` LiveView route.
  - Removed route-specific tests for the old alternatives LiveView.

### [ ] Enhancement 3: Move A/B decision point creation into the experiments UI

- Status: Proposed
- Area: Authoring UX / native experiment setup
- Context: The immediate QA blocker was fixed by adding `New A/B Decision Point` under Manage Alternatives. That works, but it still splits experiment setup across Manage Alternatives and the A/B Testing experiments page.
- Desired behavior: Authors should be able to create the required A/B decision point directly from the experiments UI while creating or preparing an experiment.
- Rationale: Keeping decision-point setup in the experiments workflow would make the native A/B Testing path more discoverable and reduce the chance that authors create normal learner-preference alternatives when they intend to create experiment-controlled alternatives.
- Follow-up: Design the experiments-page flow for creating a decision point, adding options, and then immediately using it in a weighted random or Thompson Sampling experiment.

### [ ] Enhancement 4: Remove option-management actions from page editor alternatives tabs

- Status: Proposed
- Area: Page editor / alternatives authoring UX
- Context: The page editor currently exposes option-management affordances inside alternatives tabs. This adds complexity for both learner-preference alternatives and A/B Testing alternatives.
- Desired behavior: The page editor should display all alternatives options as tabs for content editing only. Authors should manage alternative option creation, rename, and deletion from Manage Alternatives.
- Rationale: Keeping option management centralized in Manage Alternatives would reduce duplicated workflows and make A/B decision points less error-prone while preserving the page editor as the place to edit branch content.
- Follow-up: Review `assets/src/components/resource/editors/AlternativesEditor.tsx` and remove tab action-menu affordances while ensuring every option from the selected alternatives group remains visible as a tab.

### [ ] Enhancement 5: Support reordering alternatives options with creation-order defaults

- Status: Proposed
- Area: Manage Alternatives / alternatives option ordering
- Context: Alternative options need a predictable order in both Manage Alternatives and page editor tabs.
- Desired behavior: Alternative options should be reorderable by authors. By default, options should appear in ascending order by creation order.
- Rationale: Predictable default ordering makes QA and authoring easier, while explicit reordering gives authors control over tab/order presentation without requiring delete-and-recreate workflows.
- Follow-up: Define where option order is stored, update Manage Alternatives to support reordering, and ensure page editor tabs and delivery rendering respect that order.
