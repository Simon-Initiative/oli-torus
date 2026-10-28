# Linked Activities Details From Learning Objectives

## Ticket Context

User story: as an instructor, when I select View Activities from a Learning Objective, I want the
linked activities page to show each activity's question details so I can immediately understand
where students are struggling.

The requested destination is the Linked Activities page for the selected Learning Objective. It
should list all activities associated with the selected objective, including activities attached to
its sub-objectives, and each row should expand into the same question-level details already shown on
the Scored Activities and Practice Activities instructor dashboard pages.

Required detail sections:

- Question
- Answer Key
- Hints
- Explanation
- Dynamic Variables when applicable
- Answer distribution
- First Try Correct
- Eventually Correct

Required table controls:

- Search
- Attempts filter
- Score filter
- Clear All Filters
- Sortable Attempts
- Sortable Score / `% Correct`

Negative requirements:

- Navigating to this page must not modify activity data or student responses.
- Activities not associated with the selected Learning Objective, or with its sub-objectives when a
  parent objective is selected, must not display.
- An activity with no question-level analytics must still expand and show the appropriate empty
  state.

## Existing Scored And Practice Activity Views

The Scored Activities and Practice Activities tabs are already one shared implementation with
different source page lists.

The root LiveView is `lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex`.
It handles:

- `/sections/:section_slug/instructor_dashboard/insights/scored_pages`
- `/sections/:section_slug/instructor_dashboard/insights/practice_pages`

The user-facing tab labels are Scored Activities and Practice Activities, while this delivery
dashboard code path names the active tabs `:scored_pages` and `:practice_pages`.

For Scored Activities:

1. `InstructorDashboardLive.handle_params/3` loads enrolled students.
2. It builds the initial page list with
   `OliWeb.Delivery.InstructorDashboard.Helpers.get_assessments/2`.
3. That helper reads graded pages from
   `Oli.Delivery.Sections.SectionResourceDepot.graded_pages/1`.
4. Page metrics are loaded asynchronously through
   `OliWeb.Delivery.InstructorDashboard.Helpers.load_metrics/3`.

For Practice Activities:

1. `InstructorDashboardLive.handle_params/3` loads the same student, script, and activity-type
   context.
2. It builds the initial page list with
   `OliWeb.Delivery.InstructorDashboard.Helpers.get_practice_pages/2`.
3. That helper reads ungraded pages from
   `Oli.Delivery.Sections.SectionResourceDepot.practice_pages/1`.
4. Page metrics are loaded through the same `load_metrics/3` helper.

Both tabs render the same LiveComponent:

- `lib/oli_web/components/delivery/pages/pages.ex`
  (`OliWeb.Components.Delivery.Pages`)

That component owns both levels of the current experience:

- Page-list mode: one row per scored or practice page.
- Selected-page mode: one row per activity on the selected page.

When a page is selected, `Pages` uses:

- `get_activities/3` to discover the activity revisions on that page and attach row-level attempts
  and average-score metrics.
- `OliWeb.Delivery.Pages.ActivitiesTableModel` to render the activity table.
- `OliWeb.Delivery.ActivityHelpers.summarize_activity_performance/6` to build the detailed
  per-activity analytics payload.
- `OliWeb.Delivery.ActivityHelpers.preview_render/6` to render the activity preview in the same
  delivery context.
- `ActivitiesTableModel.render_assessment_details/2` to render the expandable details row.

## Shared Activity Detail UI

The common activity table model is
`lib/oli_web/components/delivery/pages/activities_table_model.ex`.

It defines the activity columns used in the selected-page view:

- Chevron column
- `#`
- `Question Stem`
- `Learning Objectives`
- `Attempts`
- `% Correct`

The expandable row behavior is also centralized there:

- The chevron sends `paged_table_selection_change`.
- `Pages` tracks `expanded_activity_ids`.
- Expanding a row lazily loads that activity's summary if it is not already in
  `loaded_activity_summaries`.
- Loaded summaries are cached in `activity_summary_cache`.
- `ActivitiesTableModel.render_assessment_details/2` renders either the loaded details or a loading
  spinner.

The actual question details are rendered by
`lib/oli_web/components/delivery/activity_helpers.ex`.

`ActivityHelpers` is explicitly documented as common infrastructure for instructor dashboard
activity metrics across Scored Activities, Practice Activities, and Surveys. Its summary path
assembles:

- Resource summary rows for the activity.
- Response summary rows and answer-distribution data.
- Activity revisions.
- Students with and without attempts.
- First-attempt correctness.
- Eventually-correct correctness.
- Rendered activity preview.
- Activity-specific staged details such as answer key, hints, explanation, and dynamic variables
  when supported by the activity model.

That is the infrastructure the Linked Activities page should reuse. The new page should not
rebuild the tabbed question-details UI in `RelatedActivitiesTableModel`.

## Current Linked Activities Route

There is already a routed LiveView for a linked-activities page:

- Route: `/sections/:section_slug/instructor_dashboard/insights/learning_objectives/related_activities/:resource_id`
- LiveView:
  `lib/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live.ex`
- Table model:
  `lib/oli_web/components/delivery/learning_objectives/related_activities_table_model.ex`

The Learning Objectives table links to this route from
`lib/oli_web/components/delivery/learning_objectives/objectives_table_model.ex`.

Current behavior is only a partial fit for the ticket:

- It resolves the selected objective.
- It loads activities with `Oli.Delivery.Sections.get_activities_for_objective/2`.
- It renders a simple table with question stem, attempts, and percent correct.
- It supports search, sort, pagination, and back-parameter preservation.
- It does not render expandable activity details.
- It does not include the `Attempts` and `Score` filter controls from the scored/practice activity
  detail table.
- It uses direct `related_activities` for the selected objective only.
- It does not include activities attached only to sub-objectives when the selected resource is a
  parent Learning Objective.

The current tests in
`test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs`
cover the simpler behavior. They are a useful starting point, but the new feature should revise them
around expandable details and parent-plus-subobjective inclusion.

## Related Activity Source Set

The source-of-truth design for obtaining linked activity resource IDs is already captured in
`docs/exec-plans/current/epics/lo_analytics/instructor_viz/informal.md`.

Important points from that design:

- `section_resources.related_activities` already stores a precomputed direct objective-to-activity
  relationship.
- The field is populated by `Oli.Delivery.Sections.PostProcessing` under the `:related_activities`
  action.
- The expensive scan of activity revision objective attachments belongs in post-processing and
  backfill, not in instructor interaction paths.
- Runtime code should use `Oli.Delivery.Sections.SectionResourceDepot` to read these arrays from the
  section resource depot/cache.
- The current direct array is not enough for parent objectives, because a parent objective's
  `related_activities` does not include activities attached only to its child objectives.

For this feature, the linked activity set should be:

1. Resolve the selected objective section resource.
2. Resolve its effective child objective resource IDs when it is a parent objective.
3. Fetch the selected objective plus child objective section resources from the depot with
   `SectionResourceDepot.get_resources_by_ids/2`.
4. Union and de-duplicate every `related_activities` array from those section resources.
5. Use that unique activity resource ID set as the only activities displayed on the Linked
   Activities page.

This preserves the negative requirement that unrelated activities are not displayed while keeping
the page load path aligned with the earlier performance design.

## Technical Direction

Complete the existing routed `RelatedActivitiesLive` rather than introducing a second URL. The route
and Learning Objectives table link already exist, and the current LiveView already has the right
high-level page shell and back-navigation responsibility.

Refactor toward a shared activity-list/detail boundary instead of copying the selected-page branch
from `OliWeb.Components.Delivery.Pages`.

Pragmatic implementation shape:

1. Introduce a reusable activity details component or service boundary for instructor activity rows.
   A likely name is `OliWeb.Components.Delivery.ActivityDetails` or
   `OliWeb.Components.Delivery.ActivityInsightsTable`.
2. Move the generic selected-activity state from `Pages` into that boundary:
   `activity_summary_cache`, `loaded_activity_summaries`, `expanded_activity_ids`,
   `maybe_load_activity_summary/2`, `assign_activity_details_state/1`, and adaptive summary repair
   polling.
3. Keep `ActivitiesTableModel` as the shared table renderer where possible. It already renders the
   chevron, `Question Stem`, `Attempts`, `% Correct`, and the detail row. If the Linked Activities
   page does not need the `#` or `Learning Objectives` columns, add a small mode/configuration to
   the table model rather than creating a separate non-expandable table model.
4. Replace or retire `RelatedActivitiesTableModel` unless it becomes a thin wrapper around
   `ActivitiesTableModel`. The current model is too shallow for this ticket because it cannot render
   the existing question-detail UI.
5. Have `RelatedActivitiesLive` build linked activity rows and pass them into the shared boundary
   directly, with a route-specific title and back link.
6. Keep the visible controls consistent with selected-page activity mode in `Pages`: search,
   `Attempts`, `Score`, and `Clear All Filters`.

## Page Context Caveat

The existing activity summary pipeline is page-scoped:

- `ActivityHelpers.summarize_activity_performance/6` receives a `page_revision`.
- It calls `Oli.Analytics.Summary.summarize_activities_for_page/3`.
- It calls `Oli.Analytics.Summary.get_response_summary_for/3`.
- It uses the page revision for activity ordinal mapping and preview rendering.

Linked activities are objective-scoped, so their unique activity resource IDs may come from multiple
pages. The implementation needs to preserve the containing page context for each activity.

Recommended approach:

1. After deriving the unique linked activity IDs, build an activity-to-page context map from section
   pages.
2. Use the section depot to get scored and practice pages, or all visible lesson pages, then inspect
   page activity references with the existing resource helpers.
3. For each linked activity, record the containing page revision or section resource needed by
   `ActivityHelpers`.
4. Group activity summary calls by containing page:
   `ActivityHelpers.summarize_activity_performance(section, page_revision, activity_types_map, students, activity_ids_for_that_page, ...)`.
5. Merge the resulting summaries back into one linked-activity table keyed by activity resource ID.

If an activity resource ID can appear on multiple pages in a section, product/design needs to decide
whether the Linked Activities page should:

- show one row per unique activity resource ID with aggregated analytics across all containing
  pages,
- show one row per activity-page occurrence, or
- choose a canonical containing page and document that limitation.

The ticket wording says "unique set of resource ids", so the default direction is one row per unique
activity resource ID. If duplicate placement is possible, aggregation semantics must be made
explicit before implementation.

## Linked Activity Row Shape

The shared table/detail path should receive rows close to the selected-page activity rows used by
`ActivitiesTableModel` today:

```elixir
%{
  resource_id: activity_resource_id,
  title: activity_title,
  content: activity_revision.content,
  objectives: objective_titles,
  total_attempts: attempts_count,
  avg_score: average_score_ratio,
  order: display_order,
  revision: activity_revision,
  page_revision: containing_page_revision,
  has_lti_activity: boolean
}
```

The existing selected-page activity mode already calculates row attempts and average score. For
Linked Activities, prefer using the same summary data source that feeds the expandable details so
the table's attempts and `% Correct` values cannot drift from the expanded detail bars.

## Filters And Sorting

Reuse the same parameter semantics as the selected-page branch in `Pages` where practical:

- `text_search`
- `selected_attempts_ids`
- `avg_score_percentage`
- `avg_score_selector`
- `sort_by`
- `sort_order`
- `offset`
- `limit`

The Linked Activities page does not need page-level filters such as progress, low-progress cards, or
page cards. It does need the activity-level controls:

- `Attempts`: None, Less than 5, More than 5.
- `Score`: comparison selector plus percentage value.
- `Clear All Filters`.

Sorting should support at least:

- question stem/title,
- attempts,
- `% Correct`.

Search should match the same user-visible text the instructor sees in the `Question Stem` column.
If the row displays both title and extracted stem, search should include both.

## Navigation

The "View Activities" link from a Learning Objective should navigate to the existing route:

```text
/sections/:section_slug/instructor_dashboard/insights/learning_objectives/related_activities/:resource_id
```

The page should retain the current Learning Objectives back-parameter behavior so returning to the
Learning Objectives table restores the prior table filters, sorting, pagination, and selected
container scope.

The Linked Activities page heading should show the selected Learning Objective title. The back link
should remain "Back to Learning Objectives".

## Empty States

There are three distinct empty states to preserve:

- No linked activities exist for the selected objective plus sub-objectives.
- Filters/search remove every linked activity from the table.
- An individual linked activity has no question-level analytics yet.

The first two are page/table states. The third is an expanded-row state and should reuse the
existing selected-page message, such as "No attempt registered for this question", when
`ActivityHelpers` cannot produce rendered details.

## Testing Direction

Update or extend
`test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs`
to cover:

- The Learning Objectives table link navigates to the Linked Activities route for the selected
  objective.
- Parent objective selection includes activities attached to the parent and activities attached to
  its sub-objectives.
- Sub-objective selection includes only activities attached to that sub-objective.
- Duplicate activity resource IDs across parent/sub-objective arrays are displayed once.
- Unrelated activities are not displayed.
- Search filters linked activities.
- Attempts filter works.
- Score filter works.
- Clear All Filters restores the unfiltered linked activity list.
- Sorting works for question stem/title, attempts, and `% Correct`.
- Expanding a row renders the same question details used by Scored Activities and Practice
  Activities.
- Collapsing and re-expanding still works after page load.
- Activities with no question-level analytics expand and show the empty state.
- Navigating to the page and expanding/collapsing rows does not mutate activity revisions,
  attempts, responses, or summary rows.

Also keep focused unit coverage around any new pure helper that derives the parent-plus-subobjective
unique activity ID set from section resources.

## Open Questions

- Can one activity resource ID appear in multiple pages in a delivered section? If yes, should this
  page aggregate across page occurrences or show one occurrence row per page?
- Should the `Learning Objectives` column remain visible on the Linked Activities page? It may be
  redundant because all rows are scoped to one objective family, but it can help when rows are linked
  through different sub-objectives.
- Should the first activity auto-expand on load, matching current Practice Activities behavior, or
  should all rows start collapsed? The acceptance criteria only requires expandable rows; the
  screenshot shows an expanded row.
- Should the route name remain `related_activities` even though the product label is "Linked
  Activities"? Keeping the current route is lower-risk, but visible page copy should use the product
  term chosen by design.
