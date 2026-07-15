# MER-5486 follow-up implementation plan

This plan captures instructor dashboard scenario coverage gaps discovered during PR review. The current MER-5486 branch covers the minimum Jira acceptance criteria, but these follow-up cases would improve confidence around user-configurable dashboard states and hierarchical objective rendering.

Each phase is intended to be implementable in a separate commit or a small follow-up PR slice.

## Current coverage baseline

Already covered by the MER-5486 scenario suite:

- Summary cards:
  - `average_student_progress`
  - `average_class_proficiency`
  - `average_assessment_score`
- Progress at course scope with the default completion threshold.
- Progress at container scope.
- Student Support bucket distribution and bucket student names for default parameters.
- Student Support active/inactive totals in the all-active case.
- Assessments rows, completion counts, score metrics, and histogram bins.
- Challenging Objectives for flat low-proficiency objectives.
- Initial no-activity state for Progress and Student Support.

Known follow-up gaps:

- Progress with a completion threshold below 100.
- Student Support active/inactive filtered lists with at least one inactive learner.
- Student Support custom progress/proficiency parameter settings.
- Challenging Objectives with nested subobjectives.
- Optional: empty/no-submission Assessments and Summary assertions.

## Phase 1 - Progress custom completion threshold

Goal:

- Cover the Progress tile behavior when the instructor selects a completion threshold below 100, for example 50.

Why:

- The LiveView supports `tile_progress.threshold` values from 10 to 100.
- Current scenario coverage only validates the default threshold of 100.
- The assertion schema already accepts `completion_threshold`, but the scenario assertion currently reprojects progress with default tile state.

Work:

- Extend `instructor_dashboard_progress` assertions to accept an instructor-facing completion threshold, for example:
  - `completion_threshold: 50`
- Pass that threshold into `Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector.reproject/2`.
- Add a scenario that uses existing progress data where some learners are partially complete and validates different counts at threshold 50 vs threshold 100.

Candidate scenario:

- Add `progress_custom_threshold.scenario.yaml`, or extend `course_summary_and_support.scenario.yaml` if the expected values remain readable.
- Assert:
  - `completion_threshold: 50`
  - `axis_label`
  - `class_size`
  - item counts/percents for the selected threshold.

Implementation notes:

- Keep the YAML field product-facing. Avoid UI internals such as `tile_progress`.
- The assertion should probably default to 100 when `completion_threshold` is omitted.
- If useful later, also support `y_axis_mode: "percent"`, but this is not required for the threshold test.

Suggested verification:

- `mix test test/scenarios/instructor_dashboard/instructor_dashboard_test.exs`
- `mix test test/scenarios/validation/schema_validation_test.exs`

Commit target:

- "[MER-5486] Cover instructor dashboard progress custom threshold"

## Phase 2 - Student Support active/inactive filtered lists

Goal:

- Validate that Student Support can distinguish active and inactive learners in bucket lists, not only in totals.

Why:

- Current tests assert `active_students: 4` and `inactive_students: 0`.
- They do not prove the list shown for a selected active/inactive filter is correct when a bucket contains both active and inactive learners.

Feasibility:

- This is likely testable, but the first step must be research.
- Do not assume that "inactive" only means "the learner's last interaction is older than N days" until the code path that feeds Student Support has been confirmed.
- Scenario state already supports `time`, and dashboard assertions pass `state.scenario_time` into the Student Support projection, but this only helps if the relevant inactive/active signal is actually derived from timestamp comparisons.
- The harder part is confirming which persisted field or analytics row determines learner activity status, and then creating that state deterministically.

Work:

- Investigate the code path for Student Support activity status:
  - where `last_interaction_at` comes from
  - whether it is updated by `view_practice_page`, `answer_question`, `visit_page`, `finalize_attempt`, or another analytics process
  - whether the LiveView filters active/inactive using the same projection payload exposed to scenario assertions
- Create a scenario with at least two learners in the same Student Support bucket:
  - one learner with recent interaction
  - one learner whose last interaction is older than the inactivity threshold
- Use the existing `time` directive to control the dashboard assertion time only if the research confirms activity status is time-window based.
- Assert both totals and bucket-level active/inactive counts.
- If the projection payload includes all students in the bucket with `activity_status`, assert the exact student names grouped by active/inactive status.

Implementation options:

- Preferred: extend `instructor_dashboard_student_support` assertion normalization to expose helper fields such as:
  - `active_student_names`
  - `inactive_student_names`
  either per bucket or as filtered bucket views.
- Alternative: assert each bucket student's `activity_status` directly if the current nested payload is stable enough.

Candidate YAML shape:

```yaml
- assert:
    instructor_dashboard_student_support:
      section: "instructor_dashboard_section"
      buckets:
        struggling:
          count: 2
          active_count: 1
          inactive_count: 1
          active_student_names: ["Recent Struggling"]
          inactive_student_names: ["Inactive Struggling"]
```

Questions/challenges:

- Confirm which scenario actions update `last_interaction_at` for Student Support.
- Confirm whether "inactive" is specifically based on `last_interaction_at` and `inactivity_days`, or whether another section/student activity concept is involved.
- If regular learner actions always use real current time instead of scenario time, or if active/inactive is based on a different signal, the scenario may need either:
  - a small directive to set learner last interaction timestamps, or
  - a documented helper directive that advances test data deterministically.

Suggested verification:

- A targeted scenario test that would fail if active/inactive filtering regresses.

Commit target:

- "[MER-5486] Cover instructor dashboard support activity filters"

## Phase 3 - Student Support custom progress/proficiency parameters

Goal:

- Validate that custom Student Support parameters change learner classification as the UI promises.

Why:

- The current assertion always passes `StudentSupportParameters.default_settings()`.
- The UI supports persisted/custom settings for:
  - inactivity days
  - struggling progress low threshold
  - struggling progress high threshold
  - struggling proficiency threshold
  - excelling progress threshold
  - excelling proficiency threshold
- The original testing plan marked this as later-phase TC-10.

Feasibility:

- This is reasonable follow-up work, but it requires adding an explicit scenario surface for custom settings.
- It is more involved than the Progress threshold case because settings affect projection options and may also be persisted by section in production.

Work:

- Choose one of two implementation paths:
  - Assertion-local parameters:
    - Add `parameters:` to `instructor_dashboard_student_support`.
    - Convert those parameters to `StudentSupportParameters.to_projector_opts/1`.
    - Use them only for the assertion projection.
  - Scenario directive:
    - Add a directive such as `instructor_dashboard_student_support_parameters`.
    - Persist settings with `StudentSupportParameters.save_for_section/3`.
    - Let the dashboard projection load active settings the same way the LiveView does.
- Add a scenario with a learner near a threshold.
- Assert default classification first, then custom classification after parameter changes.

Candidate YAML shape:

```yaml
- assert:
    instructor_dashboard_student_support:
      section: "instructor_dashboard_section"
      parameters:
        excelling_progress_gte: 60
        excelling_proficiency_gte: 60
      buckets:
        excelling:
          student_names: ["Threshold Learner"]
```

Recommendation:

- Prefer assertion-local `parameters:` for the first follow-up because it keeps the scenario focused on projection correctness.
- Add a persisted-settings directive only if the goal is to cover the LiveView's save/settings workflow through scenario infrastructure.

Suggested verification:

- Schema validation for the new YAML shape.
- Targeted scenario test covering before/after classification.

Commit target:

- "[MER-5486] Cover instructor dashboard support custom parameters"

## Phase 4 - Challenging Objectives with subobjectives

Goal:

- Validate that the Challenging Objectives panel handles a low-proficiency subobjective under a parent objective.

Why:

- The UI can render parent objectives and expandable subobjective rows.
- Current scenarios use flat objectives only.
- The projection includes `row_type`, `children`, `has_children`, `parent_objective_id`, and subobjective navigation data.

Feasibility:

- This should be achievable with existing scenario infrastructure.
- The scenario DSL already supports objective operations such as `create_sub`.
- The main complexity is creating enough attempts attached to the subobjective so the proficiency projection classifies it as Low, while preserving a meaningful parent row.

Work:

- Create or extend a dashboard scenario with hierarchical objectives:
  - Parent objective: "Apply problem solving"
  - Subobjective: "Select a strategy"
  - Optional sibling subobjective with High/Medium proficiency to prove only the Low child is included.
- Attach activities to the subobjective.
- Simulate known wrong/correct answer patterns.
- Assert `instructor_dashboard_challenging_objectives` includes:
  - parent objective row with `has_children: true`
  - child row in `children`
  - child `row_type: "subobjective"`
  - child `proficiency_label: "Low"`

Candidate YAML shape:

```yaml
- assert:
    instructor_dashboard_challenging_objectives:
      section: "instructor_dashboard_section"
      state: "populated"
      rows_by_title:
        "Apply problem solving":
          has_children: true
          children:
            - title: "Select a strategy"
              row_type: "subobjective"
              proficiency_label: "Low"
```

Questions/challenges:

- Confirm whether the projection includes only low subobjectives, or includes parent context plus low descendants.
- Confirm expected behavior when the parent itself is not Low but a child is Low.

Suggested verification:

- Scenario runner plus schema validation.

Commit target:

- "[MER-5486] Cover instructor dashboard challenging subobjectives"

## Phase 5 - Optional empty Assessments and Summary coverage

Goal:

- Complete no-activity/no-submission coverage beyond Progress and Student Support.

Why:

- Current `initial_empty_dashboard.scenario.yaml` covers zero Progress and all learners in `not_enough_information`.
- It does not assert empty/no-submission Assessments behavior or Summary no-data behavior.

Work:

- Extend `initial_empty_dashboard.scenario.yaml` or add a new focused scenario.
- Assert:
  - Assessments panel lists the graded page with `completed_count: 0`, if the projection includes the row before any submissions.
  - Summary cards have expected no-data/ready states and do not invent metrics.

Questions/challenges:

- Confirm actual projection behavior for graded pages with zero submissions. It may return either an assessment row with zero completion or no assessment metric rows, depending on the Grades oracle.

Suggested verification:

- Scenario runner.

Commit target:

- "[MER-5486] Cover instructor dashboard empty assessment states"

## Recommended follow-up order

1. Progress custom threshold.
2. Challenging Objectives subobjectives.
3. Student Support active/inactive filtered lists.
4. Student Support custom parameters.
5. Optional empty Assessments/Summary refinements.

Rationale:

- Progress custom threshold is likely the smallest infrastructure change.
- Subobjectives use existing objective authoring support and mostly require scenario data.
- Student Support active/inactive needs deterministic timestamp handling.
- Student Support custom parameters needs a new assertion or directive surface.
- Empty Assessments/Summary is valuable, but less central than the user-configurable panel behavior.

## Guardrails

- Keep the current MER-5486 branch focused; implement these cases in a follow-up PR after merge.
- Prefer product-facing YAML names.
- Avoid exposing internal oracle/projection terminology.
- Avoid fixed sleeps.
- Keep each scenario small enough that failures identify the affected dashboard panel clearly.
