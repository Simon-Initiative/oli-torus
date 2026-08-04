# LearningObjectiveCoverage Data Source Design Notes

## Ticket Scope

This document captures the technical plan for `MER-5855` Implement LearningObjectiveCoverage data source.

This ticket is the data foundation for the Learning Objectives Editor coverage work. It should provide an application-level library module that efficiently reads the project working publication once, then builds in-memory structures that support:

- Learning Objective and Sub-Objective coverage summaries.
- Expanded page/activity detail rendering.
- Formative/Summative filtering.
- Low coverage filtering.
- Course content filtering by unit/module/page.
- Text search across Learning Objectives, Sub-Objectives, pages, and activities.

The UI tickets should consume this module instead of issuing separate page, activity, or objective queries.

`LearningObjectiveCoverage` is not intended to be a GenServer, supervised process, cache process, or external service boundary. It should be a plain Elixir module with functions called by the parent LiveView in the LiveView process. The separation is for testability, readability, and keeping non-UI data shaping out of the LiveView module.

## Feature Summary

Authors need the Learning Objectives Editor to show how much course material is attached to each Learning Objective and Sub-Objective. Coverage means the number of tagged pages and the number of tagged activities, broken down into formative and summative course material.

The UI should show summary counts on each top-level Learning Objective and each Sub-Objective, then allow each objective row to expand into detailed page and activity links. Parent Learning Objective counts include both direct attachments and attachments through Sub-Objectives. Sub-Objective counts include only content attached to that Sub-Objective.

Related filtering work will add:

- Low coverage filtering, where formative or summative counts are below a configured threshold.
- Course content filtering by unit, module, or page.

The central technical requirement is to build the full Learning Objective to page/activity map efficiently in authoring, without reading full page or activity content in the interaction path.

## Key Design Goals

- Use one targeted custom query for the working publication projection.
- Read compact revision attributes only.
- Do not select page `content`.
- Do not select activity `content`.
- Do not load full activity revisions just to compute counts, filters, search, or CSV rows.
- Do not ask the database repeated per-objective, per-page, or per-filter questions.
- Partition and enrich the query result in application memory.
- Build stable lookup maps once and let UI/filter/search code consume those maps.
- Keep the data source deterministic and side-effect free; reading coverage must not modify objectives, pages, activities, or associations.

## Current Code Context

The active workspace Learning Objectives Editor is `lib/oli_web/live/workspaces/course_author/objectives_live.ex`.

There is also an older editor at `lib/oli_web/live/objectives/objectives.ex`. Unless product needs both routes updated, implementation should target the workspace editor first because it is wired into the current course-author workspace shell and includes newer state such as pending Sub-Objective deletion.

The existing editor already performs an async first-load attachment pass:

- `ObjectivesLive.build_objectives/4` fetches objective mappings.
- It starts a task that calls `Publishing.project_working_publication/1`.
- It then calls `Publishing.find_attached_objectives/1`.
- `handle_info({:finish_attachments, ...}, socket)` folds those attachment rows into page/activity counts.

That current approach is useful but incomplete for this feature.

`Publishing.find_attached_objectives/1` already avoids loading full revision content. It explodes `revision.objectives` from revisions mapped into the working publication. However, it does not return enough data for the new coverage UI:

- It does not return `resource_id`.
- It does not return page `graded` status.
- It does not return activity `scope`.
- It does not provide page-to-activity grouping.
- Current parent Learning Objective activity counts are direct-only, not direct plus child Sub-Objective attachments.

Delivery space has an optimized precomputed field:

- `section_resources.related_activities` stores direct objective-to-activity relationships.
- It is populated by `Oli.Delivery.Sections.PostProcessing` under the `:related_activities` action.
- Runtime delivery code should use `Oli.Delivery.Sections.SectionResourceDepot` to read those arrays.
- Parent objectives still need child aggregation because direct arrays do not include activities attached only to child objectives.

Authoring does not have `SectionResourceDepot`, so the authoring implementation should use compact working-publication queries rather than copying the delivery depot model immediately.

## Recommended Backend Design

Add a dedicated authoring coverage library module, for example `Oli.Authoring.ObjectiveCoverage`, and have the Learning Objectives Editor call that module directly.

The module should build coverage from the project working publication using a single compact projection query over the current unpublished publication mappings. It should not select full page or activity `content`.

### Projection Query

The query should join:

- `publications`
- `published_resources`
- `revisions`
- `projects`, or otherwise scope to the target project

The query must be scoped to the target project and to `publications.published IS NULL`. The important point is to read the revisions currently referenced by `published_resources`, not every historical unpublished revision row.

The query should be a projection into maps or a small struct, not `%Revision{}` records with preloads. Returning compact rows makes it harder for callers to accidentally depend on full revision data.

Select the union of compact attributes needed for Learning Objectives, pages, activities, and course-content filtering:

- `rev.id`
- `rev.resource_id`
- `rev.resource_type_id`
- `rev.slug`
- `rev.title`
- `rev.deleted`
- `rev.objectives`
- `rev.children`
- `rev.graded`
- `rev.activity_refs`
- `rev.scope`
- `rev.activity_type_id`

Filter to relevant resource types:

- Learning Objectives
- Pages
- Activities
- Containers, for unit/module/page filtering

Fields that do not apply to a row's resource type will simply be ignored during post-processing. `resource_type_id` is required so the module can partition the projection into objective, page, activity, and container rows.

The query result should be the only database read required for initial coverage, filtering, and text search. Later features such as CSV export may add their own narrowly scoped export query if they need fields not present here, but should still avoid full revisions.

### In-Memory Post-Processing

After the projection query returns, the module should partition rows by `resource_type_id`:

- Objective rows.
- Page rows.
- Activity rows.
- Container rows.

Post-processing should then build normalized lookup maps:

- `objective_id -> objective_revision`
- `parent_objective_id -> child_objective_ids`
- `child_objective_id -> parent_objective_ids`
- `page_id -> page_summary`
- `activity_id -> activity_summary`
- `page_id -> embedded_activity_ids`, from `activity_refs`
- `container_or_page_id -> descendant_page_ids`, from container/page `children`
- `objective_id -> direct_page_ids`
- `objective_id -> direct_activity_ids`
- `objective_id -> aggregate_objective_ids`, where parent objectives include their child Sub-Objective ids
- `objective_id -> coverage_summary`
- `objective_id -> detail_groups`
- `objective_id -> searchable_text`
- `page_id -> curriculum_path`, if needed for display/export/filtering

The post-processing step should prefer `MapSet` while building relationships, then convert to sorted lists where deterministic rendering or testing benefits from stable ordering.

### Search Index

The data source must support text search without issuing separate database queries.

Build a simple in-memory search projection for each top-level Learning Objective and each Sub-Objective. Searchable text should include:

- Learning Objective title.
- Sub-Objective titles.
- Page titles attached to the objective or its Sub-Objectives.
- Embedded activity titles attached to the objective or its Sub-Objectives.

For matching behavior, start with normalized partial substring matching:

- Downcase text.
- Trim whitespace.
- Collapse repeated whitespace.
- Match the query against the precomputed `searchable_text`.

The search projection should preserve enough match metadata for UI behavior:

- If a Sub-Objective title matches, the parent Learning Objective can be shown and expanded.
- If a page title matches, the relevant objective row can be shown and expanded.
- If an activity title matches, the relevant objective row and page group can be shown and expanded.
- Matching terms can be highlighted by the UI using the original titles from the coverage detail data.

Do not use database full-text search for the initial Learning Objectives Editor search. The data needed for search is already in memory from the coverage projection, and issuing a separate search query would create another path that must be reconciled with active filters.

### Page-To-Activity Mapping

Use `revisions.activity_refs` for page-to-embedded-activity relationships.

This column is maintained when page content changes in `lib/oli/authoring/editing/page_editor.ex`. It avoids scanning page `content` during the Learning Objectives Editor interaction path.

Avoid reusing older helpers such as `Publishing.determine_parent_pages/2` for this feature. Those helpers still use JSON path scans over page `content`, which is exactly what this feature should avoid.

If there is concern about older or stale rows where `activity_refs` has not been populated, handle that as a migration/backfill or repair concern, not as a reason to parse all page content during normal editor rendering.

## Coverage Calculation

Normalize objective attachments into compact relationships.

For pages:

- Read direct page objective tags from `page.objectives["attached"]`.
- Each page attachment contributes to the matching objective.
- The page is formative when `graded == false`.
- The page is summative when `graded == true`.

For activities:

- Read activity objective tags from all part entries in `activity.objectives`.
- Deduplicate objective ids per activity.
- Embedded activities inherit formative or summative classification from their parent page through `activity_refs`.
- If the same activity appears on multiple pages, count it once per objective and assessment bucket for summary counts, but preserve enough detail for page-grouped display.

For parent Learning Objectives:

- Aggregate over `MapSet.new([parent_id | child_ids])`.
- Include direct content attached to the parent objective.
- Include content attached through Sub-Objectives.
- Deduplicate pages and activities by resource id per bucket.

For Sub-Objectives:

- Aggregate only over the Sub-Objective id.
- Do not include sibling or parent attachments.

## Banked Activity Ambiguity

A standalone banked activity has objective tags but no inherent formative or summative status. That status exists only when the activity is used in a page context or selected through some page-level configuration.

The initial offering should count only static embedded activities. Activity coverage counts should not include activity bank selections or standalone banked activities.

This keeps the first implementation semantically clear: the counts represent concrete activities that are statically referenced by pages through `activity_refs`.

### Follow-Up: Deterministic Bank Selection Coverage

A later feature can expand coverage to include deterministic activity bank selections, but that should be implemented as a separate indexed capability rather than by parsing all page content in the Learning Objectives Editor interaction path.

Some bank selections deterministically target a Learning Objective. For example, a selection whose logic includes an objective-positive clause such as `objectives contains [objective_id]` under an AND-style expression guarantees that selected candidates target that objective.

Other bank selections only create possible coverage. For example, a selection whose logic is `tags contains ["hard"]` may randomly select activities that target a Learning Objective, but it does not guarantee that the learner will receive an activity for that objective. These possible matches should not be included in the primary coverage count because they would overstate actual coverage.

Recommended follow-up model:

- Add a compact derived index of bank selections per page revision.
- Populate it when page content changes in the page editor.
- Populate it during course import, ingest, duplication, and other page-revision creation paths.
- Provide a just-in-time project backfill or background indexing job for existing projects after rollout.
- Keep normal Learning Objectives Editor rendering on the compact projection/index data, not full page `content` scans.

The derived index should store enough selection summary data for coverage without resolving the full candidate set:

```elixir
%{
  "version" => 1,
  "selections" => [
    %{
      "id" => selection_id,
      "count" => count,
      "guaranteed_objective_ids" => [objective_id],
      "referenced_objective_ids" => [objective_id]
    }
  ]
}
```

The static analyzer for `guaranteed_objective_ids` should match delivery semantics:

- `objectives contains [ids]` guarantees those ids.
- `objectives equals [ids]` guarantees those ids.
- `objectives does_not_contain [ids]` guarantees no positive objective coverage.
- `objectives does_not_equal [ids]` guarantees no positive objective coverage.
- `all` clauses guarantee the union of child guarantees.
- `any` clauses guarantee only the intersection of child guarantees.

If deterministic bank-selection coverage is added later, the UI should distinguish it from embedded activity coverage. A bank selection represents activity slots or candidate selection rules, not concrete embedded activity links.

Possible future labels:

- Embedded activities
- Bank activity slots
- Deterministic bank selections

Activity-bank selections are currently checked during objective deletion via `Publishing.find_objective_in_selections/2`, which scans page content for selection conditions referencing objectives. Those selection pages may need coverage treatment, but they are not the same as concrete embedded activity references. This should be clarified before counting them as activity coverage.

## Suggested Data Shape

Return a top-level data structure that gives callers both raw lookup maps and objective-ready coverage rows. The exact structs can be adjusted during implementation, but the shape should make the module the single source for coverage, filtering, and search.

```elixir
%{
  objectives_by_id: %{objective_id => objective_summary},
  pages_by_id: %{page_id => page_summary},
  activities_by_id: %{activity_id => activity_summary},
  containers_by_id: %{container_id => container_summary},
  descendants_by_container_id: %{container_or_page_id => MapSet.t(page_id)},
  coverage_by_objective_id: %{
    objective_id => %{
      counts: %{
        pages: page_count,
        formative_activities: formative_activity_count,
        summative_activities: summative_activity_count,
        sub_objectives: sub_objective_count
      },
      issues: %{
        formative?: boolean,
        summative?: boolean
      },
      search: %{
        text: normalized_search_text,
        targets: [
          %{resource_id: resource_id, kind: resource_kind, title: original_title}
        ]
      },
      pages: %{
        formative: [page_summary],
        summative: [page_summary]
      },
      activities_by_page: %{
        page_resource_id => %{
          formative: [activity_summary],
          summative: [activity_summary]
        }
      }
    },
  },
  top_level_objective_ids: [objective_id]
}
```

The exact shape can be adjusted for the LiveView, but it should preserve:

- Fast summary counts.
- Page-first detail rendering.
- Activities grouped under parent pages.
- Enough link data for page and embedded activity navigation.
- Enough metadata for formative/summative toggles.
- Enough normalized text and match metadata for partial text search.
- Enough descendant-page lookup data for course-content filtering.

## UI Behavior Implications

Learning Objectives and Sub-Objectives with no tagged pages or activities should not display empty toggles.

Expanded state should be tracked per objective or Sub-Objective row. Expanding one item should not expand others.

The Formative/Summative toggle should filter the already-loaded coverage structure in memory. It should not trigger a new scan of revision content.

Pages should display above their activities. If a page is tagged for the selected assessment type but has no matching activities for that type, display the requested empty-state message.

Navigation should be read-only:

- Page links should use the authoring page edit path.
- Embedded activity links should navigate to the page editor with enough anchor/query state to focus the activity, if the page editor supports that.

Existing page links use `Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page.slug)`.

## Filtering Design

All initial filters should run against the in-memory data structure returned by `LearningObjectiveCoverage`.

Low coverage filtering should run against computed coverage counts in memory after the coverage map is built.

Text search should run against the precomputed normalized search text and preserve enough match metadata for UI expansion/highlighting.

Course content filtering should use the `container_or_page_id -> descendant_page_ids` map produced from the same projection query's container/page rows.

When a course content scope is active:

- Direct page tags count only for pages in scope.
- Embedded activity coverage counts only through scoped parent pages.
- Standalone banked activities should probably be excluded unless product defines how they relate to a content scope.

Filter composition should be deterministic and in memory:

- Search narrows by text match.
- Coverage Issues narrows by threshold state.
- Course Content narrows by descendant page scope.
- Sort runs after filtering.
- Pagination or row limits run after sorting.

This keeps filtering predictable and avoids pushing threshold, text search, and tree-scope behavior into complex SQL.

## Performance Notes

The initial implementation should be efficient with one bounded working-publication projection query that selects compact columns only.

Do not load all full activity revisions.

Do not load or parse all page `content` during the editor interaction path.

Do not implement separate database queries for each filter or search mode.

Use `activity_refs` for page-to-activity relationships.

Potential future indexes or backfills:

- A GIN index on `revisions.activity_refs` could help if future features query pages by a set of activity ids repeatedly.
- A backfill for `revisions.activity_refs` may be needed if older page revisions have empty or stale values.
- If objective JSON querying becomes a bottleneck, consider a generated or cached authoring-side attachment table, but only after profiling shows the compact query approach is insufficient.

The likely first implementation does not need a delivery-style persistent authoring depot. It should be measured before introducing another cache lifecycle.
