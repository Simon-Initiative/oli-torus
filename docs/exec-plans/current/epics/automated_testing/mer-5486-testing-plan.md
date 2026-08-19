# MER-5486 testing plan

This plan defines the expected test cases for Instructor Intelligent Dashboard scenario tests. The implementation should prioritize readable YAML and instructor-facing assertions while avoiding internal terms such as "oracle".

## Recommended Base Dataset

Create a new suite under `test/scenarios/instructor_dashboard/`.

Proposed shared setup:

- Project `instructor_dashboard_course`.
- Two units: `Foundations Unit` and `Applications Unit`.
- Six practice pages with MCQs, three per objective, to satisfy the minimum data threshold for proficiency.
- One or two graded pages, for example `Checkpoint Quiz` and `Application Quiz`.
- Objectives:
  - `Master foundations`
  - `Apply concepts`
- MCQ activities with known correct options.
- Section `instructor_dashboard_section`.
- Enrolled instructor.
- Students:
  - `ava_excelling`: completes almost everything, correct on first attempt.
  - `ben_on_track`: medium/high progress and medium proficiency.
  - `cleo_struggling_low_progress`: low progress and incorrect answers.
  - `diego_struggling_high_progress`: high progress but incorrect answers.
  - `nora_no_data`: enrolled with no activity.

Notes:

- For stable proficiency, every classified learner should have at least 3 first attempts for the evaluated objective.
- For progress distribution, some learners should skip pages so they remain in the 0 bin.
- For assessments, use graded pages with real finalization if viable.

## Test Cases

### TC-01 course summary metrics reflect known class activity

Setup:

- Use the base dataset.
- Simulate a mix of progress, proficiency, and assessment scores.

Assertions:

- `instructor_dashboard_summary` with `section`, `scope: "course"`.
- Validate `total_students`.
- Validate cards/metrics: `average_student_progress`, `average_class_proficiency`, `average_assessment_score`.
- Validate `scope_label` or `course_title` if the assertion supports it.

Coverage note:

- The three summary cards do not need to be asserted in a single scenario, but the completed MER-5486 scenario set must cover each card at least once.
- `average_student_progress` belongs naturally with the progress/student support scenario.
- `average_class_proficiency` belongs naturally with the proficiency/challenging objectives scenario.
- `average_assessment_score` belongs naturally with the assessment outcomes scenario.

Implementation notes:

- The projection source is `projections.summary.metrics` and `summary_tile.cards`.
- Use decimal tolerance.
- Do not require recommendation/AI for this ticket unless the snapshot returns it as unavailable.

### TC-02 progress distribution at course scope

Setup:

- Base dataset with two units.
- Distribute activity so `Foundations Unit` has more completed learners than `Applications Unit`.

Assertions:

- `instructor_dashboard_progress` with `scope: "course"`.
- Validate `class_size`.
- Validate `axis_label: "Course Units"`.
- Validate series by label:
  - count/percent above the default threshold 100.
  - key bins such as `0`, `50`, `100`, if the assertion exposes bins.

Implementation notes:

- Projection source: `projections.progress.progress_tile.series_all`.
- To simplify YAML, allow `items:` with `label`, `completed_count`, `completed_percent`, and `bins`.

### TC-03 progress distribution at container scope

Setup:

- Reuse the base dataset.
- Scope `container: "Foundations Unit"` or equivalent by title if the assertion helper resolves resource ids.

Assertions:

- `instructor_dashboard_progress` with container scope.
- Validate that the axis is `Course Pages`.
- Validate that only pages from the selected container appear.

Implementation notes:

- This is important coverage because the route allows dashboard scope navigation.
- The assertion can accept `scope: {container: "Foundations Unit"}` in YAML and resolve it to `container:<id>`.

### TC-04 student support buckets include excelling, on track, struggling, and no data

Setup:

- `ava_excelling`: progress >= 80 and proficiency >= 80.
- `ben_on_track`: progress >= 40 and proficiency >= 40, without reaching excelling.
- `cleo_struggling_low_progress`: progress < 40 and proficiency <= 40.
- `diego_struggling_high_progress`: progress > 80 and proficiency <= 40.
- `nora_no_data`: no progress or proficiency.

Assertions:

- `instructor_dashboard_student_support` with `scope: "course"`.
- Validate totals: `total_students`, `active_students`/`inactive_students` if time is stabilized.
- Validate bucket counts:
  - `excelling: 1`
  - `on_track: 1`
  - `struggling: 2`
  - `not_enough_information: 1`
- Validate student names by bucket.

Implementation notes:

- Projection source: `projections.student_support.support.buckets`.
- If `last_interaction_at` remains dependent on real timestamps, skip active/inactive assertions in the first scenario.

### TC-05 proficiency signal feeds visible dashboard outcomes

Setup:

- Base dataset with known answers per objective.
- At least one objective with a `High` distribution and another with `Low` or `Medium`.

Assertions:

- Do not treat this as an independent panel. In the current view, proficiency appears as a signal used by:
  - `instructor_dashboard_summary`, especially `average_class_proficiency`.
  - `instructor_dashboard_student_support`, to classify learners together with progress.
  - `instructor_dashboard_challenging_objectives`, to highlight objectives with low proficiency.
- Validate that a known answer distribution produces the expected `average_class_proficiency` in Summary.
- Validate that those same proficiency data place students in the expected Student Support buckets.
- Validate that only objectives with mode `Low` are covered by TC-06.

Implementation notes:

- This test case exists to protect the proficiency signal that feeds visible tiles, not because there is a separate "Proficiency" tile.
- Do not implement `instructor_dashboard_proficiency` in the first version unless an equivalent visible dashboard surface is identified.
- If detailed objective distribution introspection is needed, cover it under `instructor_dashboard_challenging_objectives` or under summary/support depending on the visible behavior being tested.

### TC-06 challenging objectives shows low-proficiency objectives

Setup:

- Make `Master foundations` or a subobjective end with mode `Low`.
- Make another objective end with `High`/`Medium`.

Assertions:

- `instructor_dashboard_challenging_objectives`.
- Validate `state: "populated"`.
- Validate `row_count`.
- Validate rows by objective title and `proficiency_label: "Low"`.
- Validate that non-low objectives do not appear as challenging, except as parent/context if applicable.

Implementation notes:

- Projection source: `projections.challenging_objectives`.
- If flat objectives are used, the first scenario avoids parent/child complexity. A second case can cover subobjectives.

### TC-07 assessments aggregate completion and scores

Setup:

- Create `Checkpoint Quiz` as graded.
- Three or more learners with known scores, for example 100, 50, 0; one learner incomplete.
- Finalize real attempts or use `complete_scored_page` as a documented initial phase.

Assertions:

- `instructor_dashboard_assessments`.
- Validate row by assessment title.
- Validate `completed_count`, `total_students`, completion ratio/status.
- Validate `minimum`, `median`, `mean`, `maximum`.
- Validate main histogram buckets.

Implementation notes:

- Projection source: `projections.assessments.assessments.rows`.
- The projector sorts by due/available date and hierarchy order; add schedule coverage in a later phase if needed.

### TC-08 dashboard handles enrolled students without activity

Setup:

- Section with enrolled learners, but nobody visits pages.

Assertions:

- Summary should not invent metrics.
- Progress class size is correct, with counts at 0.
- Student Support bucket `not_enough_information` contains everyone.
- Assessments with graded pages show completion 0.

Implementation notes:

- This protects empty/initial dashboard state.
- It can be a short separate scenario.

### TC-09 container scope filters assessments and objectives

Setup:

- Two units, each with an objective and quiz.
- Activity in both scopes.

Assertions:

- `instructor_dashboard_assessments` for `Foundations Unit` includes only quizzes from that unit.
- `instructor_dashboard_challenging_objectives` for `Foundations Unit` includes only objectives contained in that unit.

Implementation notes:

- Important for dashboard navigation.
- Can be implemented after TC-03.

### TC-10 custom student support thresholds

Setup:

- Learner with progress/proficiency close to thresholds.

Assertions:

- Default thresholds classify the learner as on-track.
- With custom parameters, the learner is classified as excelling or struggling.

Implementation notes:

- The projector supports settings via `student_support_settings`.
- The YAML assertion could accept `parameters:` with instructor-facing names.
- This is not part of the minimum acceptance criteria; leave it for a later phase.

## Minimum Acceptance Criteria Coverage

To satisfy MER-5486 with a strong initial slice:

- TC-01 summary.
- TC-02 progress course scope.
- TC-04 student support buckets.
- TC-05/TC-06 proficiency signal through summary/support/challenging objectives.
- TC-07 assessments if the graded-attempt flow is stable in the same iteration.
