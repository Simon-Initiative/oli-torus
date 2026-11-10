# Learning Objectives Course Content Filter - Product Requirements Document

## 1. Overview

Add a `Course content` dropdown to the Learning Objectives authoring toolbar. Authors can select curriculum locations in a hierarchical checklist and limit the displayed Learning Objectives and Sub-Objectives to content within those locations. The filter must compose with search, sort, and Coverage Issues state and persist in query parameters for sharing and browser history.

## 2. Background & Problem Statement

Authors reviewing objective coverage need to focus on a specific Unit, Module, Section, or Page. The current objective list requires scanning the whole course and does not provide a curriculum-aware way to narrow the review. MER-5800 requires a read-only filter backed by the shared `ObjectiveCoverage` model so that direct page tags and embedded-activity tags are evaluated consistently without repeated content queries.

## 3. Goals & Non-Goals

### Goals

- Provide a Figma-aligned `Course content` toolbar filter.
- Support hierarchical curriculum selection with OR semantics and descendant inclusion.
- Filter parent Learning Objectives and matching Sub-Objectives through page and embedded-activity associations.
- Preserve filter state across query-parameter URLs, refreshes, and browser history.
- Preserve existing search, sort, and Coverage Issues state when the filter changes.
- Meet the ticket’s keyboard, ARIA, hierarchy, labeling, focus, truncation, and tooltip requirements.

### Non-Goals

- Mutating objectives, pages, activities, or relationships.
- Implementing search, sorting, Coverage Issues filtering, or CSV export.
- Adding Activity Bank coverage beyond the shared embedded-page coverage model.
- Introducing a persistent filter table, cache, GenServer, or separate query service.
- Redesigning the broader course outline or authoring toolbar.

## 4. Users & Use Cases

- Author: select a Unit, Module, Section, or Page to inspect only the objectives represented in that part of the course.
- Author: select multiple curriculum branches and review the union of their objective coverage.
- Author: share a filtered Learning Objectives URL or use browser back/forward navigation without losing filter state.

## 5. UX / UI Requirements

- Add the exact label `Course content` to the Learning Objectives toolbar, after Coverage Issues and before the Download CSV/New Objective action grouping, consistent with [Figma node 327:29961](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=327-29961&m=dev).
- Opening the control displays a scrollable Unit/Module/Section/Page checklist and keeps the menu open while multiple items are selected.
- Selecting a parent includes descendants for filtering but does not require child checkboxes to be independently selected; selecting a child does not select its ancestors.
- Show an active-filter indication and count selected active containers and pages without double-counting overlapping selections.
- Truncate overflowing curriculum titles and provide a tooltip with the full title.
- Use existing Torus components and design tokens for dropdowns, checkboxes, tooltips, spacing, colors, focus states, and typography.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Filtering is read-only and must not write content or relationship data.
- Initial coverage/filter data must use the project’s compact working-publication projection and in-memory indexes; do not load full page/activity content or issue N+1 filter queries.
- The hierarchy and controls must be keyboard operable, expose checkbox and expanded/collapsed state to assistive technologies, provide descriptive labels, communicate structure programmatically, and show visible focus indicators.
- Curriculum titles and query-parameter state must be handled safely when optional or malformed data is present.
- Results and hierarchy ordering must be deterministic for stable rendering and automated tests.

## 9. Data, Interfaces & Dependencies

- The workspace surface is `lib/oli_web/live/workspaces/course_author/objectives_live.ex`.
- Use `Oli.Authoring.ObjectiveCoverage` and the shared model from `MER-5855` as the source for curriculum scope, descendant pages, objective attachments, and embedded-activity relationships.
- The data source must support direct page objective tags and objectives attached to embedded activities on selected pages.
- Encode selected curriculum identifiers together with existing search, sort, and Coverage Issues parameters using the LiveView’s query-parameter conventions.
- Jira is the system of record for MER-5800; Figma is the visual source of truth for the toolbar and filter states.

## 10. Repository & Platform Considerations

- Follow the Phoenix LiveView and server-rendered/React-focused frontend boundaries documented in `docs/FRONTEND.md` and `docs/BACKEND.md`.
- Keep domain/data shaping out of the LiveView where the coverage module can own it.
- Prefer LiveView tests for server-driven state, event handling, query parameters, and rendering; use focused unit tests for pure filtering/index logic.
- Run targeted `mix test` and formatting checks, plus relevant frontend checks when client components are changed.
- Apply the repository’s required security, performance, UI, TypeScript, and requirements review lenses when implementation changes warrant them.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Rollout follows the normal deployment flow. No data migration is expected because selected filter state is represented in URL query parameters and the coverage model already supplies the required read-only projection.

## 12. Telemetry & Success Metrics

- Use existing Phoenix/AppSignal error and latency monitoring to detect failures or regressions in the Learning Objectives filter interaction path.
- Success is demonstrated by authors being able to narrow the objective list by curriculum location, retain the filter in shared/history URLs, and use the filter without altering course data.
- No new product metric is required unless implementation introduces an existing project-standard interaction event for filter usage.

## 13. Risks & Mitigations

- Curriculum hierarchy and coverage indexes diverge: reuse the single `ObjectiveCoverage` model and add direct tests for descendant expansion and page/activity matching.
- Overlapping parent and child selections inflate counts or matches: normalize selected active pages/containers with sets before calculating counts and results.
- Query parameters reset unrelated toolbar state: centralize parameter parsing/serialization and test composition with search, sort, and Coverage Issues settings.
- Large courses make the checklist difficult to use: constrain the menu to a scrollable region, use deterministic ordering, and truncate titles with accessible tooltips.
- Accessibility is lost in custom hierarchical controls: use semantic labels/roles, keyboard-native controls where possible, explicit ARIA state, and focused accessibility verification.

## 14. Open Questions & Assumptions

### Open Questions

- What exact query-parameter key and encoding should be used for selected curriculum item identifiers, and must existing URLs from a prior implementation remain compatible?
- Should selected parent items render descendants as checked, indeterminate, or only as an active filtering scope?
- What is the approved empty-state copy for zero matching Learning Objectives?
- Which existing Torus dropdown, tree/checklist, and tooltip components should own the final implementation?

### Assumptions

- The feature targets the current workspace editor route, not the older Objectives LiveView, unless product explicitly expands the scope.
- OR semantics apply across all selected curriculum items and their descendant pages.
- A page or embedded activity match is sufficient to include its associated Learning Objective; only matching Sub-Objectives are shown beneath a matching parent.
- The active count is the deduplicated count of selected active containers and pages, as clarified in Jira.
- Activity Bank selections and standalone banked activities remain excluded from the initial embedded-only coverage model.
- No new telemetry event or feature flag is needed for this read-only authoring filter.

## 15. QA Plan

- Automated validation:
  - Validate `requirements.yml` structure and PRD headings with the Harness scripts.
  - Add focused coverage-model tests for descendant expansion, OR semantics, deduplication, direct page tags, and embedded-activity matches.
  - Add LiveView tests for open/multi-select/clear behavior, parent and child semantics, active counts, empty states, query-parameter restoration, browser-state composition, and read-only behavior.
  - Add UI/component tests where the checklist is implemented outside LiveView, including keyboard interaction, ARIA state, truncation, and tooltip behavior.
- Manual validation:
  - Compare toolbar placement and dropdown states with the referenced Figma designs.
  - Exercise a representative deep course hierarchy and long curriculum titles.
  - Verify refresh, copied URLs, and browser back/forward preserve selections and unrelated filters.
  - Verify keyboard-only operation and visible focus throughout the control.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
- [ ] MER-5800 behavior is covered by automated tests and manual UI/accessibility verification
- [ ] Code review requirements are satisfied
