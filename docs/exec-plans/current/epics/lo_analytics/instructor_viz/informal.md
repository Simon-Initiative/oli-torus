# Instructor Expanded Learning Objective Visualization

## Ticket Context

Jira: MER-5814, "Instructor: Expanded LO Visualization"

Status at investigation time: Analyzing.

The feature replaces the expanded Learning Objective visualization in the instructor dashboard
Insights / Learning Objectives tab. The new design groups students by two dimensions:

- Learning proficiency on the x-axis.
- Activity completion on the y-axis.

Required groups:

- Needs Support: low proficiency, high activity.
- Excelling: high proficiency, high activity.
- Limited Activity: completed less than half of linked activities.

The ticket also includes accessibility requirements: groups must be keyboard selectable, the
student table controls must be keyboard navigable, and all interactive controls need visible focus
indicators.

## Current User Flow

The relevant route is the instructor dashboard Insights / Learning Objectives tab. The root
LiveView renders `OliWeb.Components.Delivery.LearningObjectives` from
`lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex`.

Current flow:

1. The LiveView loads objectives for the section with
   `Sections.get_objectives_and_subobjectives(section, exclude_sub_objectives: false, include_related_activities_count: true)`.
2. `OliWeb.Components.Delivery.LearningObjectives` renders the Learning Objectives table.
3. The table uses `OliWeb.Delivery.LearningObjectives.ObjectivesTableModel`.
4. Instructor-dashboard rows are expandable through the first chevron column.
5. Expanded rows render `OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView`.
6. `ExpandedObjectiveView` asynchronously loads per-objective analytics when the row is expanded.
7. Once loaded, the expanded row renders:
   - the current dot distribution visualization,
   - an optional selected-proficiency student table,
   - the sub-objectives table.

The expanded-row async load sends data back to the root LiveView as a message and the root forwards
it into the expanded component with `send_update/3`.

## Current Rendering Implementation

The expanded visualization is `assets/src/components/misc/DotDistributionChart.tsx`, registered in
`assets/src/apps/Components.tsx` as `Components.DotDistributionChart`.

It is mounted from `ExpandedObjectiveView.render_dots_chart/1` through
`OliWeb.Common.React.component/4` in LiveView mode. The wrapper lives in
`lib/oli_web/common/react.ex` and uses `PhoenixLiveReact.live_react_component`.

The current visualization is a hybrid:

- Vega-Lite renders the horizontal stacked bar that represents aggregate proficiency distribution.
- React renders an SVG dot layer above the bar.
- React also owns hover state, selected proficiency section state, dot tooltips, the SVG
  accessibility labels, and keyboard handling for the proficiency section hit areas.

Important current behavior:

- The visualization is one-dimensional: x-axis is proficiency only.
- Proficiency labels are `Not enough data`, `Low`, `Medium`, and `High`.
- Colors are purple/gray and have separate light/dark palettes in the React component.
- The bar data is calculated client-side from the `proficiency_distribution` prop.
- Dot data is calculated client-side from the `student_proficiency` prop.
- Students are grouped by proficiency label and exact rounded proficiency percentage.
- If six or more students share the same rounded proficiency value, they are rendered as one larger
  grouped dot; otherwise they render as a vertical tower of individual dots.
- The visual selection region is the proficiency segment of the horizontal bar, not an individual
  dot.
- Selecting a proficiency segment calls `pushEventTo("#expanded-objective-<unique_id>", "show_students_list", %{proficiency_level: level})`.
- Closing the selected segment calls `hide_students_list`.

The current chart already has some keyboard support for selecting a proficiency segment, but the
new feature needs keyboard support around three semantic groups rather than four proficiency
segments.

## Current Expanded Data Sources

`ExpandedObjectiveView` derives the expanded visualization data in
`lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`.

For a selected objective:

- `Oli.Delivery.Sections.enrolled_student_ids(section_slug)` supplies the enrolled student IDs and
  excludes instructors.
- `Oli.Delivery.Metrics.proficiency_per_student_for_objective(section_id, [objective_id])` supplies
  proficiency labels for enrolled students that have enough analytics data.
- `calculate_proficiency_distribution_from_student_data/3` filters to enrolled students and adds
  missing students as `Not enough data`, so chart totals match enrollment.
- `Oli.Delivery.Metrics.student_proficiency_for_objective(section_id, objective_id)` supplies
  individual records with `id`, numeric `proficiency`, and `proficiency_range`.
- `retrieve_students_data/1` joins those records to account data from `Oli.Accounts.get_users_by_ids/1`.
- `add_missing_students_to_proficiency_data/4` filters to enrolled students, adds missing students,
  and adds linked-activity attempt data.

The resulting `student_proficiency` assign currently includes:

- `id`
- `email`
- `full_name`
- `name`
- `given_name`
- `family_name`
- `proficiency`
- `proficiency_range`
- `activities_attempted_count`
- `total_related_activities`

Only `id`, `proficiency`, and `proficiency_range` are currently represented in the React prop type.
The activity completion fields already exist server-side for the student table and can likely be
used by the new 2D matrix after the prop contract is expanded.

## Current Proficiency Model

`Oli.Delivery.Metrics.proficiency_range/2` defines the current labels:

- Fewer than 3 first attempts: `Not enough data`.
- `nil` proficiency: `Not enough data`.
- Proficiency `<= 0.4`: `Low`.
- Proficiency `<= 0.8`: `Medium`.
- Above `0.8`: `High`.

`student_proficiency_for_objective/2` computes numeric proficiency from
`Oli.Analytics.Summary.ResourceSummary` rows for objective resources in a section. It uses first
attempt correctness with partial weight for incorrect first attempts, grouped by student.

## Current Activity Completion Model

`ExpandedObjectiveView.add_missing_students_to_proficiency_data/4` gets linked activities from
`SectionResourceDepot.get_section_resource(section_id, objective_id).related_activities`.

`Oli.Delivery.Metrics.student_activities_attempted_count/3` counts distinct linked activity
resource IDs where each student has at least one attempt. The query reads
`Oli.Analytics.Summary.ResourceSummary` activity rows with:

- matching section,
- matching enrolled student IDs,
- matching related activity resource IDs,
- `project_id == -1`,
- activity resource type,
- `num_attempts > 0`.

The current table renders this as `activities_attempted_count out of total_related_activities`.
MER-5814 needs this transformed into an activity completion percentage for the y-axis and for group
membership. Limited Activity is explicitly less than 50% of linked activities.

Open point: the current implementation treats attempted at least once as activity completion for the
existing table wording. The ticket says Activity Completion is based on linked activities. The design
doc should confirm whether "completion" means attempted at least once, submitted, completed page,
scored completion, or the current attempted-count proxy.

### Derived Related Activity Data

There is already derived data for objective-to-activity relationships:

- Migration `priv/repo/migrations/20250924163704_add_related_activities_to_section_resources.exs`
  adds `section_resources.related_activities` as a `bigint[]`.
- Backfill migration
  `priv/repo/migrations/20250924163747_populate_related_activities_for_existing_section_resources.exs`
  populated the field for existing sections.
- Runtime maintenance lives in `Oli.Delivery.Sections.PostProcessing` under the
  `:related_activities` action.
- `PostProcessing.apply(section, :all)` includes `:related_activities` and is invoked after section
  curriculum rebuild/update flows.

The post-processing algorithm is intentionally section-local:

1. Fetch all objective revisions in the section.
2. Fetch all activity revisions in the section with non-nil `objectives`.
3. Extract objective resource IDs from each activity revision's `objectives` map.
4. Intersect those IDs with section objective IDs.
5. Batch-update each objective `section_resources.related_activities` array.

This means runtime code does not need to scan activity revision JSONB to answer "which activities
directly attach objective X?" It can read the precomputed array from `SectionResourceDepot`, which
loads section resources into the depot/cache for containers, pages, and objectives.

For an already-initialized section depot, this is a zero-database-query read path. The expanded
visualization can derive the objective and sub-objective related activity IDs directly from the
Depot cache instead of touching `revisions`, `published_resources`, or `section_resources` in the
database at interaction time.

Important caveat: `related_activities` is direct-only. For a top-level objective, it contains
activities that directly attach that top-level objective. It does not appear to include activities
that attach one of the top-level objective's sub-objectives. Existing usages, including
`Sections.get_activities_for_objective/2`, `Sections.get_objectives_and_subobjectives/2` with
`include_related_activities_count: true`, and the expanded visualization's
`add_missing_students_to_proficiency_data/4`, use the direct array as-is.

Requirement 1 for MER-5814 needs a broader denominator for top-level objectives: activities that
attach either the selected top-level objective or any of its sub-objectives. The efficient path should
reuse the direct arrays rather than re-querying revision JSONB:

1. Resolve the selected top-level objective's effective child objective resource IDs. Existing code
   already does this through `SectionResourceDepot.objectives_with_effective_children/1` or by
   reading the selected objective section resource and hydrating children when needed.
2. Fetch the parent and child objective section resources in one depot call:
   `SectionResourceDepot.get_resources_by_ids(section_id, [parent_id | child_ids])`.
3. Union and de-duplicate all `related_activities` arrays from those objective section resources.
4. Use `length(unique_related_activity_ids)` as the total linked activity denominator.
5. Pass the same unique activity ID list into `Metrics.student_activities_attempted_count/3` to get
   raw per-student numerator counts.

This keeps the expensive JSONB traversal in post-processing/backfill paths and keeps the expanded
visualization path to cached section-resource reads plus one indexed summary query for student
activity counts.

### Current Raw Count Query

`Metrics.student_activities_attempted_count/3` is already the likely numerator query. It returns:

```elixir
%{student_id => attempted_activity_count}
```

The implementation already performs aggregate-only work. It does not pull raw `resource_summary`
records into Elixir. It counts `COUNT(DISTINCT resource_id)` from `resource_summary`, groups by
`user_id`, and selects only `{user_id, count}`.

Current helper predicates:

- `section_id` matches the section,
- `user_id` is in the supplied enrolled student ID list,
- `resource_id` is in the linked activity ID list,
- `project_id == -1`,
- `resource_type_id` is the activity type,
- `num_attempts > 0`.

For MER-5814, the efficient query contract should stay the same shape:

```sql
SELECT user_id, COUNT(DISTINCT resource_id) AS attempted_activity_count
FROM resource_summary
WHERE section_id = $section_id
  AND project_id = -1
  AND resource_type_id = $activity_type_id
  AND resource_id = ANY($linked_activity_ids)
  AND user_id != -1
  AND num_attempts > 0
GROUP BY user_id
```

If we already have enrolled student IDs in memory, filtering with `user_id = ANY($student_ids)` is
even more precise than `user_id != -1`, because it excludes any non-enrolled or non-student user rows
that may exist in section analytics. Either way, the query should return only the aggregated
student-to-count map. Missing students should be filled as `0` when building the visualization data.

This uses summary data, not raw attempts. The `resource_summary_scopes` unique index covers
`project_id`, `section_id`, `user_id`, `resource_id`, `resource_type_id`, and `part_id`, so the query
has usable indexed leading predicates for the section/project/user/resource dimensions. Because
activities may have multiple parts, the query groups by user and counts distinct activity resource
IDs.

The current semantic label is therefore "attempted linked activities" rather than a stricter
"completed linked activities" signal. If product accepts this as Activity Completion, the completion
percentage is:

```text
activities_attempted_count / total_linked_activity_count
```

If product requires a stricter completion definition, we need to identify or add a different summary
signal before implementing the matrix.

## Current Student Table And Email Integration

Selecting a proficiency segment sets `selected_proficiency_level` in `ExpandedObjectiveView`.

When selected, it renders
`OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList` from
`lib/oli_web/components/delivery/learning_objectives/student_proficiency_list.ex`.

Current table behavior:

- Filters the complete `student_proficiency` list by `proficiency_range`.
- Builds a sortable table with `OliWeb.Delivery.LearningObjectives.StudentProficiencyTableModel`.
- Columns are selection checkbox, student name, and activities attempted.
- Supports select all and per-row selection.
- Email button is shown above the table.
- Selected students are converted into an email modal payload.
- The email modal itself is rendered by the parent `LearningObjectives` component, not inside the
  expanded-row table, to avoid stacking issues.

The email show/hide path is:

1. `StudentProficiencyList` builds `email_modal_payload`.
2. `OliWeb.Components.Delivery.Students.EmailButton` sends `{:show_email_modal, caller_assigns}`.
3. The root instructor dashboard LiveView handles the message and sends the payload to the
   `LearningObjectives` component.
4. `LearningObjectives` renders
   `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal`.

Current limitations relative to MER-5814:

- The table is below the visualization, not beside it.
- The header is proficiency-centric and has no group count, group explanation, or recommended
  action.
- It has no Load More behavior; it renders all students in the selected proficiency group.
- It does not have a proficiency filter inside Limited Activity.
- It filters by `proficiency_range`; new groups will need a single mutually exclusive group
  assignment per student.

## Current Sub-objectives Table

Expanded rows always render a sub-objectives table after the visualization/student table area.

`get_sub_objectives_data/3` loads children for the expanded top-level objective, calls
`Metrics.objectives_proficiency/3`, and then counts related activities from
`SectionResourceDepot.get_resources_by_ids/2`.

This table is likely still required below the new expanded visualization unless the epic changes the
expanded-row layout more broadly.

## Test Coverage Found

Relevant tests:

- `test/oli_web/components/delivery/learning_objectives/expanded_objective_view_test.exs`
  verifies the expanded component renders the React chart and handles sub-objective cases.
- `test/oli_web/components/delivery/learning_objectives/student_proficiency_list_test.exs`
  covers student list selection, sorting, email payload behavior, and related table behavior.
- `test/oli/analytics/summary/metrics_v2_test.exs` covers
  `student_proficiency_for_objective/2`, `objectives_proficiency/3`, and
  `student_activities_attempted_count/3`.
- `test/oli/delivery/sections_test.exs` covers
  `Sections.get_objectives_and_subobjectives/2` proficiency distributions and related activity
  counts.

Likely new coverage needed:

- A pure grouping function that assigns each student to exactly one MER-5814 group.
- Boundary tests for low/high proficiency and `< 50%` activity completion.
- Empty group rendering.
- Switching groups and deselecting the selected group.
- Load More append behavior if implemented server-side.
- Email payload for selected group students.
- Accessibility tests for keyboard group selection and focusable controls where practical.

## Technical Approach

The path forward can reuse most of the existing expanded Learning Objective implementation. The
feature is a rework of the visualization and selected-student table behavior, not a completely new
data pipeline.

### Reuse The Expanded Row Boundary

Keep `OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView` as the owner of expanded
row data loading and selected-group state. It already has the right lifecycle:

- It loads analytics only when a row is expanded.
- It supports async loading and forwards results through the root instructor dashboard LiveView.
- It already has access to `section_id`, `section_slug`, selected objective resource ID, objective
  title, section title, and current instructor.
- It renders the chart, optional student table, and sub-objectives table in one expanded row.

Expected change: replace `selected_proficiency_level` with a selected semantic group key, such as
`selected_student_group`, and change the React event payload from `%{proficiency_level: level}` to
`%{group: group_key}`.

### Reuse The Hybrid Chart Architecture

The new chart has similar interaction complexity to the current chart, so the current hybrid
approach still fits:

- Vega-Lite can render stable chart primitives such as axes, plot background regions, labels, or
  matrix/scatterplot scaffolding.
- React/SVG should continue to render the interactive overlay: group hit areas, selected-region
  highlight, close affordance, dots, tooltips, keyboard handlers, focus states, and LiveView events.
- LiveReact `pushEventTo` should remain the event bridge back to
  `ExpandedObjectiveView.handle_event/3`.

This is a good reuse point because `DotDistributionChart` already solves several local concerns:

- LiveReact registration through `assets/src/apps/Components.tsx`.
- Dark-mode handling.
- Visibility/resize handling for charts rendered inside expandable rows.
- SVG overlay hit areas.
- Keyboard activation for selectable regions.
- LiveView event pushback with `pushEventTo("#expanded-objective-<unique_id>", event, payload)`.

Implementation can either replace `DotDistributionChart` or introduce a new component, for example
`StudentDistributionMatrix`. A new component is probably cleaner because the new chart is
two-dimensional and group-based rather than a one-dimensional proficiency distribution.

### Build The Student Dataset Server-side

The server-side expanded-row loader should build one enriched student dataset for the selected
top-level objective:

- enrolled student IDs,
- student identity and email,
- numeric proficiency,
- proficiency label,
- attempted linked activity count,
- total linked activity count,
- activity completion ratio,
- exactly one MER-5814 group assignment.

The current loader already gets most of this:

- `Sections.enrolled_student_ids(section_slug)` gives the student universe.
- `Metrics.student_proficiency_for_objective(section_id, objective_id)` gives numeric proficiency and
  proficiency labels for students with summary data.
- `retrieve_students_data/1` joins account data.
- missing students are already added as `Not enough data`.
- `Metrics.student_activities_attempted_count/3` already returns an aggregate student-count map.

The main data-loader change is to calculate the linked activity denominator using the top-level
objective plus sub-objectives, not only the selected objective's direct `related_activities` array.

### Derive Linked Activities From Depot Only

For the selected top-level objective, derive the unique linked activity resource IDs from
`SectionResourceDepot`:

1. Resolve the top-level objective's effective child objective resource IDs.
2. Fetch the parent and child objective section resources from the Depot cache with
   `SectionResourceDepot.get_resources_by_ids(section_id, [parent_id | child_ids])`.
3. Union and de-duplicate all `related_activities` arrays.

This is a major performance point: after the section depot is initialized, this step does not touch
the database. It avoids runtime queries against `revisions.objectives`, `published_resources`, or
`section_resources`. The expensive JSONB scan has already been moved to section post-processing and
backfill, where `section_resources.related_activities` is populated.

The unique linked activity IDs are then used for two things:

- `total_linked_activity_count = length(unique_activity_ids)`.
- the activity ID filter for the per-student attempted-count aggregate query.

### Query Only Aggregated Activity Counts

For the numerator, use the `resource_summary` aggregate pattern already implemented by
`Metrics.student_activities_attempted_count/3`.

The query should return only `{student_id, attempted_activity_count}` grouped by `user_id`; it should
not load raw summary rows. Current behavior counts distinct linked activity resource IDs where the
student has `num_attempts > 0`, which avoids double-counting activities with multiple parts.

Preferred implementation shape:

- Keep or adapt `Metrics.student_activities_attempted_count/3`.
- Pass `section_id`, enrolled student IDs, and the unique top-plus-subobjective activity IDs.
- Fill missing enrolled students with `0` attempted activities in Elixir when building the chart
  dataset.

Filtering by enrolled student IDs is more precise than `user_id != -1`. If a variant helper is
created that does not receive the student list, it should at least use `user_id != -1`, but the
expanded visualization already needs the enrolled student universe for missing-data handling.

### Define Group Assignment In One Place

Group assignment should be centralized in a pure Elixir helper so the chart and table cannot drift.
Every enrolled student must be assigned to at most one group, and table filtering should use that
precomputed group key rather than reimplementing chart logic.

Likely fields per student:

```elixir
%{
  id: student_id,
  full_name: full_name,
  email: email,
  proficiency: 0.0,
  proficiency_range: "Low" | "Medium" | "High" | "Not enough data",
  activities_attempted_count: attempted_count,
  total_related_activities: total_count,
  activity_completion: attempted_count / total_count,
  distribution_group: :needs_support | :excelling | :limited_activity | ...
}
```

Known group rules from the ticket:

- Limited Activity: completed or attempted less than 50% of linked activities.
- Needs Support: Low proficiency and high activity.
- Excelling: High proficiency and high activity.

Open group-rule decisions:

- Whether high activity is exactly `>= 50%` or a higher threshold.
- Where high-activity Medium students go.
- Where high-activity Not enough data students go.
- What to do when `total_related_activities == 0`.

### Reuse The Student Table And Email Plumbing

The current `StudentProficiencyList` and `StudentProficiencyTableModel` should be adapted or
superseded, but much of the behavior can be reused:

- checkbox selection,
- select all,
- sortable table model,
- selected email derivation,
- `EmailButton`,
- email modal payload construction,
- forwarding the modal payload to the parent `LearningObjectives` component,
- rendering `DraftEmailModal` outside the row/table stacking context.

The new table should become group-oriented:

- It filters by `distribution_group`, not `proficiency_range`.
- Its header renders the group count, explanation, and suggested action.
- Its columns should match the ticket: student name, learning proficiency, and activity completion.
- Limited Activity likely needs an additional proficiency filter because that group can contain all
  proficiency labels.
- Load More can be implemented inside the LiveComponent by rendering an initial slice of the
  precomputed group rows and appending more from the already-loaded dataset. Server pagination is
  only necessary if expected section sizes make the all-student expanded-row load unacceptable.

### Keep The Sub-objectives Table Unless Scope Changes

The existing expanded row always renders the sub-objectives table below the visualization area. This
can remain unchanged unless the epic explicitly changes the expanded-row layout beyond the new matrix
and selected-group table.

## Open Questions

- What is the approved definition of "Activity Completion" for linked activities: attempted at
  least once, submitted, completed, or another analytics field?
- Does `High Activity` mean `>= 50%` of linked activities, or a higher threshold?
- Where should high-activity Medium proficiency students appear?
- Where should high-activity Not enough data students appear?
- Should Limited Activity include students with `total_related_activities == 0`, or should that be a
  separate empty/no-linked-activities state?
- Should the new group table page from the server, or is loading all students for the expanded
  objective acceptable for expected section sizes?
- Should the existing sub-objectives table remain directly below the new visualization?
