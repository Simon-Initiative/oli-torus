# Learning Objectives Course Content Filter

## Ticket and Epic Context

This feature describes Jira ticket [`MER-5800`](https://eliterate.atlassian.net/browse/MER-5800), “LO Authoring Course Content Filter,” within the Objectives Editor epic (`MER-5784`). The ticket is assigned to the `content_filter` feature lane and depends on the shared coverage model established by `MER-5855`.

The feature adds the Course content filter UI to the Learning Objectives authoring page, integrates it with the LiveView, and connects filtering to the `LearningObjectiveCoverage`/`Oli.Authoring.ObjectiveCoverage` data source. The Jira ticket is In Progress and High priority.

## User Problem

Authors reviewing Learning Objective and Sub-Objective coverage need to focus on a particular part of a course. Without a curriculum-aware filter, they must scan the entire objective list even when they are interested in one unit, module, section, or page.

## Desired Experience

The Learning Objectives page toolbar includes a `Course content` dropdown. Opening it reveals a scrollable, hierarchical checklist that mirrors the course outline:

- Unit
- Module
- Section
- Page

An author can select one or more curriculum items while keeping the menu open. Selections use OR semantics: an objective matches when it is associated with content in any selected branch. Selecting a parent includes all descendant content; selecting a child does not select or mark its ancestors.

The filter visibly indicates when it is active. The active count is the number of selected and active containers plus pages, including descendants activated by a selected parent. Clearing all selections restores the complete objective list.

## Filtering Behavior

When course-content selections are active:

- Show only top-level Learning Objectives associated with selected pages or with activities on selected pages.
- Include a parent Learning Objective when a matching Sub-Objective is associated with selected content.
- Under a displayed parent, show only the Sub-Objectives associated with selected content.
- Treat direct page objective tags and objective tags on embedded activities as matching relationships.
- Include descendant pages when a Unit, Module, or Section is selected.
- Show an appropriate empty state when no Learning Objectives match.

Filtering is a read-only view operation. It must not modify Learning Objectives, Sub-Objectives, pages, activities, or their relationships.

## Filter State and Composition

The Course content filter composes with the existing Learning Objectives page state:

- Applying or clearing it must preserve the current text search.
- Applying or clearing it must preserve the current sort order.
- Applying or clearing it must preserve the Coverage Issues filter and its settings.
- The selected curriculum item identifiers must be persisted in query parameters.
- Query parameters must support shareable filtered URLs and browser history back/forward navigation.
- Loading the page from a URL with course-content parameters must restore the same selected state and filtered results.

The filter should operate over the already-built in-memory coverage model. It should not issue a database query per selected item or scan full page content during interaction. The model should expose page/container scope and objective-to-page/activity relationships so the filter can compose with search, sort, and other filters without creating a second coverage path.

## Toolbar and Visual Guidance

The Figma file is the source of truth for toolbar placement, sizing, spacing, colors, typography, and control states:

- [Objectives toolbar with Course content item](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=327-29961&m=dev)
- [Course content filter design reference](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=502-12219&m=dev)
- [Course content filter state reference](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=365-19378&m=dev)

The fetched toolbar design places `Course content` after the Coverage Issues controls and before the action grouping for Download CSV and New Objective. It is a bordered dark-background dropdown with Open Sans semibold text, a downward chevron, six-pixel internal icon/text spacing where applicable, and six-pixel corner radius consistent with neighboring controls. The visible label is exactly `Course content`.

Long curriculum titles must truncate horizontally rather than expand the checklist beyond its layout. A tooltip must expose the complete title on hover/focus. The hierarchy remains scrollable, and the open menu remains available while selecting multiple items.

Reuse existing Torus toolbar, dropdown, checkbox, tooltip, spacing, color, and focus-state components/tokens wherever available. Do not introduce a parallel styling system based on the generated Figma reference code.

## Accessibility

- The toolbar dropdown and every checklist control must be keyboard accessible.
- The hierarchical structure must be conveyed programmatically; indentation alone is insufficient.
- Expand/collapse controls must expose their state with appropriate ARIA attributes.
- Each checkbox must expose its checked state and an accessible label containing the curriculum item name.
- Focus indicators must be visible for the trigger, expand/collapse controls, checkboxes, and any interactive menu elements.
- The filter should remain operable without pointer input and should preserve sensible focus when selections update the results.

These expectations come from the ticket's WCAG 2.1.1 Keyboard, 4.1.2 Name/Role/Value, 2.4.7 Focus Visible, 3.3.2 Labels or Instructions, and 1.3.1 Info and Relationships guidance.

## Data and Integration Boundary

The current workspace Learning Objectives Editor is `lib/oli_web/live/workspaces/course_author/objectives_live.ex`. Keep filter state orchestration in the LiveView and keep curriculum/objective relationship shaping in `Oli.Authoring.ObjectiveCoverage` (or the final shared module name established by `MER-5855`).

The coverage data source should provide, or make possible, these structures:

- Curriculum/container/page hierarchy and deterministic descendant page expansion.
- Page-to-curriculum scope for each page.
- Direct page objective attachments.
- Embedded activity references resolved to their containing pages.
- Activity objective attachments inherited through page scope.
- Objective and Sub-Objective matching results that preserve parent hierarchy.

Use the project working publication and compact revision projections. Do not load full page or activity `content`, add repeated per-filter queries, or reproduce the older `Publishing.find_attached_objectives/1` path in the UI.

## Scope

### Included

- `Course content` toolbar dropdown on the Learning Objectives authoring page.
- Scrollable Unit/Module/Section/Page hierarchical checklist.
- Independent multi-selection with OR semantics.
- Parent selection expanding to descendant content.
- Child selection without automatic parent selection.
- Active filter indication and selected active container/page count.
- Objective and Sub-Objective filtering through direct page and embedded-activity associations.
- Empty state when no objectives match.
- Query-parameter persistence, shareable URLs, and browser history restoration.
- Composition with current search, sort, and Coverage Issues filter state.
- Tooltip behavior for truncated curriculum titles.
- Keyboard, ARIA, focus, and programmatic hierarchy accessibility behavior.
- Focused LiveView/component tests and coverage-model tests as appropriate.

### Excluded or Deferred

- Changing objective, page, activity, or relationship data.
- Search, sort, or Coverage Issues filter implementation itself; this feature only composes with those existing or adjacent feature states.
- CSV export behavior, except preserving filter state for the later CSV feature if its contract requires it.
- Activity Bank selection coverage beyond activities resolvable through selected pages and the shared embedded-only coverage model.
- A new persistent filter table, cache, GenServer, or standalone query service.
- Redesigning the broader curriculum outline or authoring toolbar beyond adding this filter.

## Important Edge Cases

- Selecting a Unit includes all descendant Modules, Sections, and Pages for matching purposes.
- Selecting multiple branches deduplicates matching pages and objectives while retaining OR semantics.
- Selecting both a parent and a child does not double-count active content or objective matches.
- Selecting a child does not visually or semantically select its ancestors.
- An objective attached directly to a selected page is included.
- An objective attached only to an embedded activity on a selected page is included.
- A matching Sub-Objective causes its parent Learning Objective to appear, but unrelated sibling Sub-Objectives remain hidden.
- No matching content produces the empty state without changing search, sort, or Coverage Issues state.
- Clearing all selections removes the course-content constraint and restores the unfiltered results.
- Long titles truncate and expose their full values through tooltips.
- Malformed or missing optional curriculum descendants should not crash the editor; they should produce stable partial filtering data consistent with existing coverage behavior.
- Refreshing or navigating directly to a URL with filter parameters restores selections and results.

## Verification Direction

At minimum, verify:

1. The toolbar renders the exact `Course content` dropdown in the Figma-specified grouping.
2. The checklist exposes Unit, Module, Section, and Page hierarchy and supports scrolling.
3. One selection, multiple selections, parent selection, and child-only selection produce the expected scope.
4. The active count counts selected active containers and pages without double-counting descendants.
5. Direct page attachments and embedded-activity attachments both match the correct objectives.
6. Parent Learning Objectives and only the matching Sub-Objectives are rendered.
7. Search, sort, and Coverage Issues state survive filter changes.
8. Clearing selections restores the full list.
9. Query parameters preserve state across refresh, shareable URLs, and browser history navigation.
10. No content or association writes occur while filtering.
11. Long titles truncate and provide complete-title tooltips.
12. Keyboard navigation, checkbox state, expanded state, labels, hierarchy semantics, and visible focus indicators meet the ticket accessibility contract.

## Jira Context Captured

The full MER-5800 description, issue fields, and comments were reviewed. The relevant clarifications are:

- Darren Siegel: use feature slug `content_filter`; build the Content Filter UI, integrate it into the LiveView, and connect it to the Learning Objectives Coverage data source.
- Darren Siegel: horizontally overflowing titles must truncate and provide a tooltip with the full contents.
- Darren Siegel: the active content-filter count includes all selected active containers and pages.
- Darren Siegel: persist filter state in query parameters to support sharing and history navigation.
