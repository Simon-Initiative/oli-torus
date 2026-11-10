# Learning Objective, Sub-Objective Summary & Attachments

## Ticket and Epic Context

This feature describes Jira ticket [`MER-5794`](https://eliterate.atlassian.net/browse/MER-5794), “Learning Objective, Sub-Objective Summary & Attachments,” within the Objectives Editor epic (`MER-5784`). The ticket is the primary authoring UI consumer of the coverage model described in [`core_data/informal.md`](../core_data/informal.md) and implemented by `Oli.Authoring.ObjectiveCoverage`.

The ticket is assigned to the `core_ui` feature lane. The epic plan places the work after `MER-5855` (the coverage data source) and before the filtering and miscellaneous Objectives Editor work. Jira currently records `MER-5793` as blocking this ticket; that dependency should be revisited before implementation because the epic plan places the hierarchy UI work in a later lane.

## User Problem

Authors can attach pages and activities to Learning Objectives and Sub-Objectives, but the Learning Objectives page does not provide a concise view of how much course content each objective covers or an efficient way to inspect and open that content. Authors need to understand coverage at a glance, expand an objective when more detail is useful, and navigate directly to the related page or embedded activity without changing any associations.

## Desired Experience

On the authoring Learning Objectives page, each Learning Objective and Sub-Objective should show compact coverage information. An author can independently expand an objective row to see its attached course content. Expanded content is organized page-first: a page appears before the activities embedded in that page.

The UI should consume one already-built, project-scoped `ObjectiveCoverage` model. Expansion and Formative/Summative changes should filter the model in memory rather than scan revision content or issue a new query for every objective, page, activity, or toggle change.

## Summary Behavior

For each top-level Learning Objective, show:

- The number of associated pages attached directly to the objective or through any descendant Sub-Objective.
- The number of formative activities attached directly or through any descendant Sub-Objective.
- The number of summative activities attached directly or through any descendant Sub-Objective.
- The number of descendant Sub-Objectives.

For each Sub-Objective, show:

- The number of formative activities attached directly to that Sub-Objective.
- The number of summative activities attached directly to that Sub-Objective.

Parent counts include direct and descendant attachments. Sub-Objective counts are direct-only. Repeated tags or repeated activity occurrences must not inflate summary counts; an activity may still appear in more than one page detail group when it is embedded on more than one page.

## Expanded Details

An objective or Sub-Objective that has tagged pages or activities can be expanded independently. Its expanded section includes a Formative/Summative toggle:

- Formative shows formative pages and their formative embedded activities.
- Summative shows summative pages and their summative embedded activities.
- Pages are rendered before the activities belonging to each page.
- A page that belongs in the selected assessment bucket remains visible even when it has no activities in that bucket, with the appropriate empty-state message.
- An objective or Sub-Objective with no tagged pages or activities does not show an empty toggle.
- Expanding one row does not expand any other row.

Page classification comes from the page's `graded` value. Embedded activities inherit their formative or summative classification from the containing page. Initial coverage is embedded-only and comes from the compact `activity_refs` relationships in the core data model.

## Navigation

Navigation is read-only and must not modify Learning Objective, Sub-Objective, page, activity, or association data.

- Selecting a page opens that page in the authoring course editor.
- Selecting an embedded activity opens its containing page and, where supported, focuses or anchors the activity.
- Activity Bank selections are not displayed or navigated in the v35 implementation. This is an explicit Jira clarification, even though the original acceptance-criteria text mentions Activity Bank navigation; bank-selection coverage is follow-up scope in the epic's core-data design.

Use the existing authoring route conventions, including `Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page.slug)` for page links, and preserve enough resource/slug/anchor metadata for downstream navigation.

## Visual and Interaction Guidance

The Figma file is the source of truth for visual details, spacing, component states, overflow behavior, and the attached screenshots:

- [Expanded objective and attachment layout](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=329-1300&t=rfgEo9XfqXD1U4gM-1)
- [Updated detail state](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=365-15474&t=3H48U1zDOPWwOKAT-1)
- [Summary/objective state](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=276-18247&t=rfgEo9XfqXD1U4gM-1)
- [Overflow activity styling](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=362-12594&t=3H48U1zDOPWwOKAT-1)

Overflow activities should follow the Figma two-column grid treatment. Use the requested icon language:

- Lesson icon for page links.
- Practice icon for formative pages and activities.
- Assignment icon for summative pages and activities.

The Jira issue includes four screenshot attachments from July 20 and July 31, 2026. They should be treated as supporting visual references alongside the linked Figma nodes rather than as a separate interaction specification.

## Accessibility

- Expand/collapse controls must be keyboard accessible.
- Expanded state must be exposed with appropriate ARIA state and relationships.
- The Formative/Summative control must be keyboard operable and communicate its selected state to assistive technologies.
- All interactive controls need visible focus indicators.

Apply the repository's existing authoring components and accessibility conventions, while preserving the semantics of the objective hierarchy for screen readers.

## Data and Integration Boundary

The UI should use `Oli.Authoring.ObjectiveCoverage` as the single source for summaries, details, assessment buckets, and later filtering/search composition. The core-data work provides:

- Project and working-publication scoping.
- Parent/Sub-Objective hierarchy and descendant relationships.
- Direct page/activity attachments and inherited parent coverage.
- Page-first detail groups with embedded activities.
- Page classification and activity classification inherited from page context.
- Stable page/resource identifiers, titles, slugs, and navigation metadata.
- Deterministic ordering and safe handling of missing or malformed optional data.

The workspace editor is the primary consumer: `lib/oli_web/live/workspaces/course_author/objectives_live.ex`. Keep query and data shaping out of the LiveView. Do not copy the older `Publishing.find_attached_objectives/1` approach into a second UI-specific query path, and do not load full page/activity `content` for this feature.

## Scope

### Included

- Summary counts on Learning Objective and Sub-Objective rows.
- Independent expand/collapse state for each row.
- Formative/Summative details toggle.
- Page-first rendering of attached pages and embedded activities.
- Empty states for pages without activities in the selected bucket.
- Page and embedded-activity navigation.
- Figma-aligned icons, overflow layout, and component states.
- Keyboard and assistive-technology accessibility behavior.
- UI tests proving direct versus inherited parent counts, direct-only Sub-Objective counts, assessment filtering, page-first grouping, empty states, independent expansion, and read-only navigation.

### Excluded or Deferred

- Activity Bank selection display or navigation in v35.
- Activity Bank indexing or full page-content scanning.
- Search, coverage-issue filters, and course-content filters owned by later epic tickets.
- CSV export.
- Objective creation, editing, deletion, or association mutation.
- Proficiency aggregation from `MER-5821`.
- A new cache, GenServer, persistent coverage table, migration, or separate UI query service.

## Important Edge Cases

- A parent objective with only descendant attachments still shows those attachments in its summary and details.
- A Sub-Objective does not inherit content from its parent or siblings.
- Directly attached formative and summative pages remain in their respective assessment buckets; a page must not appear in both buckets merely because it is directly attached.
- An embedded activity displayed under a page uses that page's assessment bucket.
- Duplicate objective tags and duplicate activity references are deduplicated in counts.
- The same embedded activity on multiple pages remains represented in each relevant page group while summary counts remain deduplicated.
- Objectives with no content do not expose an empty Formative/Summative toggle.
- Invalid or missing optional references should produce stable empty/partial detail data rather than crashing the page.
- Loading, empty-project, and model-load failure states should follow existing workspace authoring conventions.

## Verification Direction

The implementation should add focused frontend/component or LiveView coverage for the interaction contract and use the existing `ObjectiveCoverage` tests as the backend data contract. At minimum, verify:

1. Summary counts distinguish parent aggregation from Sub-Objective direct counts.
2. Formative and Summative toggles render only the selected page/activity bucket.
3. Page-first grouping and page empty states are deterministic.
4. Expansion state is isolated per objective row.
5. Page and embedded-activity links carry the correct project/resource/anchor context.
6. Activity Bank selections are absent from the v35 UI.
7. Navigation does not issue writes or alter objective/page/activity associations.
8. Keyboard focus, ARIA expanded state, and toggle selected state are present.

## Jira Context Captured

The full MER-5794 description, issue fields, comments, and attachment metadata were reviewed. The relevant comments are:

- Darren Siegel: use feature slug `core_ui` and provide the analyzer the complete description and screenshots.
- Darren Siegel: Activity Bank Selections are not supported in v35.

The ticket is High priority, In Progress, and has a five-point estimate. Its original Activity Bank navigation criterion is therefore superseded for this implementation by the later explicit v35 comment and the epic's embedded-only coverage decision.
