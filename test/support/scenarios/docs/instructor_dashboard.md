# Instructor Dashboard Assertions

This document covers scenario directives and assertions for validating the
Instructor Intelligent Dashboard without rendering LiveView HTML.

## Table of Contents

- [Overview](#overview)
- [dashboard_analytics_ready](#dashboard_analytics_ready)
- [instructor_dashboard_summary](#instructor_dashboard_summary)
- [instructor_dashboard_progress](#instructor_dashboard_progress)
- [instructor_dashboard_student_support](#instructor_dashboard_student_support)
- [instructor_dashboard_challenging_objectives](#instructor_dashboard_challenging_objectives)
- [instructor_dashboard_assessments](#instructor_dashboard_assessments)
- [Complete Workflow](#complete-workflow)

---

## Overview

Instructor dashboard assertions validate the data projections consumed by the
Instructor Intelligent Dashboard route:

```text
/sections/{SECTION_SLUG}/instructor_dashboard/insights/dashboard
```

They are intended for scenario tests that create real course content, enroll
learners, simulate learner activity, and then assert instructor-facing dashboard
results. These assertions should use product-facing names and should not expose
internal data-source terminology in YAML.

Use `dashboard_analytics_ready` after learner actions that change analytics and
before any instructor dashboard assertion. This keeps tests deterministic without
using fixed sleeps.

---

## dashboard_analytics_ready

Prepares analytics-backed dashboard data for a section.

### Parameters

- `section`: Name of the section whose dashboard analytics should be ready (required)

### Example

```yaml
- answer_question:
    student: "alice"
    section: "biology_section"
    page: "Practice 1"
    activity_virtual_id: "practice_1_mcq"
    response: "a"

- dashboard_analytics_ready:
    section: "biology_section"
```

### Notes

- Use this after `answer_question`, `finalize_attempt`, or other learner actions
  that affect dashboard analytics.
- The directive validates that the section exists, rebuilds derived section
  relationships used by dashboard analytics, and drains snapshot work when the
  test environment uses manual Oban queues.
- Do not use this as a general-purpose wait directive.

---

## instructor_dashboard_summary

Asserts the top summary cards shown by the Instructor Intelligent Dashboard.

### Parameters

- `section`: Name of the section to inspect (required)
- `scope`: Optional scope. Use `"course"` or `{container: "Container Title"}`
- `tolerance`: Numeric comparison tolerance for expected numbers
- `total_students`: Expected total enrolled learner count
- `cards`: Expected subset of summary cards keyed by card id
- `metrics`: Expected subset of raw summary metrics
- `available_slots`: Expected visible data slots
- `missing_slots`: Expected unavailable data slots
- `scope_label`: Expected scope label
- `course_title`: Expected course title

Supported card ids include:

- `average_student_progress`
- `average_class_proficiency`
- `average_assessment_score`

### Example

```yaml
- assert:
    instructor_dashboard_summary:
      section: "biology_section"
      tolerance: 0.1
      total_students: 4
      cards:
        average_student_progress:
          status: "ready"
          value_number: 53.6
```

### Notes

- The three summary cards can be covered by separate scenarios when each card
  needs a different realistic data setup.
- `average_student_progress` pairs naturally with progress scenarios.
- `average_class_proficiency` pairs naturally with objective/proficiency scenarios.
- `average_assessment_score` pairs naturally with graded assessment scenarios.

---

## instructor_dashboard_progress

Asserts the progress tile for course or container scope.

### Parameters

- `section`: Name of the section to inspect (required)
- `scope`: Optional scope. Use `"course"` or `{container: "Container Title"}`
- `tolerance`: Numeric comparison tolerance
- `axis_label`: Expected chart axis label
- `class_size`: Expected learner count
- `completion_threshold`: Completion percentage threshold used to count learners as complete
- `items`: Expected progress items keyed by unit/page label
- `series`: Expected visible series subset
- `series_all`: Expected full series subset
- `empty_state`: Expected empty-state object, when applicable

### Example

```yaml
- assert:
    instructor_dashboard_progress:
      section: "biology_section"
      scope:
        container: "Unit 1"
      axis_label: "Course Pages"
      class_size: 4
      items:
        "Lesson 1":
          completed_count: 2
          completed_percent: 50.0
```

### Notes

- Course scope generally reports top-level units.
- Container scope generally reports pages or child modules inside the selected
  container.
- `completed_count` and `completed_percent` are calculated at the dashboard
  completion threshold.

---

## instructor_dashboard_student_support

Asserts the student support tile and its learner buckets.

### Parameters

- `section`: Name of the section to inspect (required)
- `scope`: Optional scope. Use `"course"` or `{container: "Container Title"}`
- `tolerance`: Numeric comparison tolerance
- `parameters`: Optional Student Support thresholds for this assertion
- `has_activity_data`: Whether dashboard support has enough activity signal
- `totals`: Expected total, active, and inactive student counts
- `buckets`: Expected subset of support buckets keyed by bucket id
- `default_bucket_id`: Expected default selected bucket
- `bucket_priority`: Expected bucket ordering

Supported bucket ids include:

- `struggling`
- `on_track`
- `excelling`
- `not_enough_information`

### Example

```yaml
- assert:
    instructor_dashboard_student_support:
      section: "biology_section"
      has_activity_data: true
      totals:
        total_students: 4
        active_students: 4
        inactive_students: 0
      buckets:
        struggling:
          count: 1
          student_names: ["Sam Struggling"]
          active_student_names: ["Sam Struggling"]
          inactive_student_names: []
        not_enough_information:
          count: 1
          student_names: ["Nina No Data"]
```

### Notes

- Bucket assignment depends on both progress and proficiency signal.
- Students with no proficiency signal are classified as `not_enough_information`.
- Activity status is based on the dashboard student-info data available in the
  scenario, not simply on whether a learner answered a question in that file.

---

## instructor_dashboard_challenging_objectives

Asserts the challenging objectives tile.

### Parameters

- `section`: Name of the section to inspect (required)
- `scope`: Optional scope. Use `"course"` or `{container: "Container Title"}`
- `tolerance`: Numeric comparison tolerance
- `state`: Expected tile state, such as `"populated"`, `"empty_low_proficiency"`,
  or `"no_data"`
- `has_objectives`: Whether objectives with meaningful data exist
- `row_count`: Number of low-proficiency objective rows
- `rows`: Expected row subset
- `rows_by_title`: Expected row subset keyed by objective title
- `scope_label`: Expected scope label
- `course_title`: Expected course title

### Example

```yaml
- assert:
    instructor_dashboard_challenging_objectives:
      section: "biology_section"
      scope:
        container: "Applications Unit"
      state: "populated"
      row_count: 1
      rows_by_title:
        "Apply problem solving":
          proficiency_label: "Low"
```

### Notes

- There is no standalone `instructor_dashboard_proficiency` assertion because
  proficiency is currently surfaced through summary, student support, and
  challenging objectives.
- For stable proficiency data, create enough first attempts for the objective
  being tested.

---

## instructor_dashboard_assessments

Asserts the assessments tile for graded pages.

### Parameters

- `section`: Name of the section to inspect (required)
- `scope`: Optional scope. Use `"course"` or `{container: "Container Title"}`
- `tolerance`: Numeric comparison tolerance
- `total_rows`: Expected assessment row count
- `has_assessments`: Whether the tile contains assessment rows
- `rows`: Expected row subset
- `rows_by_title`: Expected row subset keyed by assessment title

### Example

```yaml
- assert:
    instructor_dashboard_assessments:
      section: "biology_section"
      tolerance: 0.1
      total_rows: 1
      has_assessments: true
      rows_by_title:
        "Checkpoint Quiz":
          completion:
            completed_count: 3
            total_students: 4
            ratio: 0.75
          metrics:
            mean: 50.0
          histogram_bins:
            - range: "0-10"
              count: 1
            - range: "10-20"
              count: 0
```

### Notes

- The assessments tile only includes graded pages.
- Prefer real learner attempts with `visit_page`, `answer_question`, and
  `finalize_attempt` when possible.
- The summary card `average_assessment_score` should be covered alongside
  assessment scenarios when closing dashboard summary coverage.

---

## Complete Workflow

```yaml
- use:
    file: "base.scenario.yaml"

- visit_page:
    student: "student_excelling"
    section: "instructor_dashboard_section"
    page: "Checkpoint Quiz"

- answer_question:
    student: "student_excelling"
    section: "instructor_dashboard_section"
    page: "Checkpoint Quiz"
    activity_virtual_id: "checkpoint_foundations_mcq"
    response: "a"

- finalize_attempt:
    student: "student_excelling"
    section: "instructor_dashboard_section"
    page: "Checkpoint Quiz"

- dashboard_analytics_ready:
    section: "instructor_dashboard_section"

- assert:
    instructor_dashboard_assessments:
      section: "instructor_dashboard_section"
      total_rows: 1
      rows_by_title:
        "Checkpoint Quiz":
          completion:
            completed_count: 1
```
