# Analytics

## Scoped learning objective assertions

`assert.learning_objectives` verifies the objective titles available to a section at course scope
or within a named curriculum container. This exercises the same section learning-objective data
used by instructor and student dashboards.

- `section`: Scenario section name (required)
- `container`: Container title; omit or use `course` for the full course
- `includes`: Objective titles that must be present
- `excludes`: Objective titles that must not be present

At least one of `includes` or `excludes` must be non-empty.

```yaml
- assert:
    learning_objectives:
      section: "analytics_section"
      container: "Unit 1"
      includes:
        - "Apply feedback principles"
      excludes:
        - "Unrelated objective"
```

## Insights assertions

`assert.insights` verifies the analytics displayed by the authoring Insights screen. It calls
`Oli.Analytics.Summary.BrowseInsights.browse_insights/3` directly, so scenarios exercise the
same application interface as the UI.

### Common parameters

- `project`: Scenario project name (required)
- `sections`: Scenario section names to aggregate; omit or use an empty list for project-wide analytics
- `resource_type`: `page`, `activity`, or `objective` (required)
- `expected`: Analytics metrics to compare (required; use an empty map with `exists: false`)
- `exists`: Set to `false` to assert that no analytics row exists; defaults to `true`
- `tolerance`: Positive tolerance for calculated floating-point metrics; defaults to `0.000001`

Specify exactly one target matching `resource_type`:

- `page`: Authored page title
- `activity_virtual_id`: Scenario activity virtual ID
- `objective`: Authored learning objective title
- `part_id`: Optional activity part ID; required when an activity produces multiple insight rows

### Supported metrics

- `num_correct`
- `num_attempts`
- `num_hints`
- `num_first_attempts`
- `num_first_attempts_correct`
- `eventually_correct`
- `first_attempt_correct`
- `relative_difficulty`

Count metrics are compared exactly. `eventually_correct`, `first_attempt_correct`, and
`relative_difficulty` use the configured tolerance.

For individual activity parts, `eventually_correct` is the fraction of learners
with at least one full-credit evaluation of that part. Each learner counts once
per section and part. Later incorrect answers do not remove success, and retries
do not add learners. Whole-question displays (including adaptive screen rows)
require every scored part to have been correct for the same learner in the same
section, possibly on different attempts. A required part that was never attempted
prevents question success. The denominator includes learners who attempted any
required part; unattempted questions do not add learners.

Pages and objectives retain their existing response-accuracy calculation,
`num_correct / NULLIF(num_attempts, 0)`, displayed as **% Correct**. The existing
API field `eventually_correct` is retained for these rows for compatibility. It
counts full-credit part evaluations divided by all associated part evaluations,
including retries; it does not measure eventual success or mastery.

All correctness calculations use existing `ResourceSummary` counters. Question
part definitions come from content already resolved for display. There are no
joins to resource, activity, or part attempt history, no historical objective JSON
expansion, and no OLAP dependency, migration, or analytics replay.

Missing learner evidence makes part/question Eventually Correct unavailable,
including incomplete cross-section evidence. It never falls back to submission
accuracy or a measured zero. A measured zero requires attempted learners with no
successes. First Attempt Correct, submission counts, and relative difficulty keep
their existing calculations. Ordinary activity sorts page before fetching learner
counts; sorting by Eventually Correct considers all matching activity candidates.

### Activity example

```yaml
- assert:
    insights:
      project: "analytics_course"
      sections:
        - "section_one"
        - "section_two"
      resource_type: "activity"
      activity_virtual_id: "feedback_question"
      expected:
        num_attempts: 4
        num_hints: 1
        num_first_attempts: 3
        num_first_attempts_correct: 1
        eventually_correct: 0.5
        first_attempt_correct: 0.333333
        relative_difficulty: 0.683333
```

### Page and objective targets

```yaml
- assert:
    insights:
      project: "analytics_course"
      sections: ["section_one"]
      resource_type: "page"
      page: "Practice Page"
      expected:
        num_attempts: 2

- assert:
    insights:
      project: "analytics_course"
      sections: ["section_one"]
      resource_type: "objective"
      objective: "Apply feedback principles"
      expected:
        num_attempts: 2
```

### No-attempt target

```yaml
- assert:
    insights:
      project: "analytics_course"
      sections: ["section_one"]
      resource_type: "page"
      page: "Unanswered Page"
      exists: false
      expected: {}
```
