# MER-5794 Learning Objective Coverage UI - Product Requirements Document

## 1. Overview

Provide authors with summary counts and expandable attachment details for Learning Objectives and Sub-Objectives in the workspace Learning Objectives editor. Authors should be able to distinguish formative and summative coverage, inspect page-first attachments, and navigate to related authoring content without changing course associations.

This work consumes the read-only `Oli.Authoring.ObjectiveCoverage` model delivered by `MER-5855`. It is the `core_ui` feature lane for the Objectives Editor epic.

## 2. Background & Problem Statement

The Learning Objectives page currently does not give authors a useful, consolidated view of how much course content is attached to each objective. Authors must infer coverage from course content and cannot quickly inspect or open the pages and embedded activities associated with an objective.

The feature must preserve the distinction between parent and Sub-Objective coverage: parent summaries include direct and descendant attachments, while Sub-Objective summaries include only direct attachments. The interaction must remain read-only and must use the compact, project-scoped coverage model rather than adding per-row queries or full content loads.

## 3. Goals & Non-Goals

### Goals

- Show objective-level coverage counts that are correct for direct and descendant attachments.
- Let authors independently expand objectives and Sub-Objectives to inspect page-first details.
- Let authors switch between formative and summative details in memory.
- Provide read-only navigation to pages and embedded activities.
- Match the approved Figma visual states, iconography, overflow layout, and accessibility guidance.
- Keep the workspace editor integrated with `Oli.Authoring.ObjectiveCoverage` as its single coverage source.

### Non-Goals

- Display or navigate Activity Bank selections in v35.
- Add Activity Bank indexing or scan full page content to infer bank coverage.
- Implement search, coverage-issue filters, course-content filters, or CSV export.
- Create, edit, delete, or retag objectives, pages, or activities.
- Implement proficiency aggregation from `MER-5821`.
- Add a cache, GenServer, persistence table, migration, or separate coverage query service.

## 4. Users & Use Cases

- Author: scan Learning Objective and Sub-Objective coverage counts while reviewing a course.
- Author: expand one objective without expanding unrelated objectives.
- Author: inspect formative or summative pages and embedded activities grouped beneath each page.
- Author: open a page or embedded activity directly in the authoring editor.
- Author using assistive technology: operate expansion and assessment controls with keyboard input and perceive their state.

## 5. UX / UI Requirements

- Top-level Learning Objectives show page count, formative activity count, summative activity count, and descendant Sub-Objective count.
- Sub-Objectives show formative and summative activity counts.
- Parent counts include direct and descendant content; Sub-Objective counts remain direct-only.
- Expansion is local to the selected objective row.
- Objectives with no tagged pages or activities do not show an empty Formative/Summative toggle.
- Expanded content is page-first: each page is displayed before the embedded activities belonging to it.
- The Formative/Summative control filters page and activity details to the selected assessment bucket.
- A page in the selected bucket remains visible with the appropriate empty-state message when it has no matching activities.
- Use the lesson icon for page links, the practice icon for formative content, and the assignment icon for summative content.
- Follow Figma for overflow activity presentation, including the two-column grid.
- Page and embedded activity links use existing authoring navigation conventions and preserve focus/anchor context where supported.
- Expand/collapse and assessment controls are keyboard accessible, expose state with ARIA, and have visible focus indicators.
- Loading, empty-project, and model-load failure states follow existing workspace authoring conventions.

Figma source of truth: [Learning Objectives Updates](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates).

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: tolerate missing or malformed optional coverage references using the core model's safe, deterministic output behavior.
- Security: preserve project and working-publication scoping and existing author authorization; do not expose content from another project.
- Read-only safety: navigation and rendering must not write revisions, associations, objective mappings, or activity data.
- Performance: use the prebuilt coverage model, avoid full page/activity content loads, and avoid repeated database queries per objective, page, activity, or toggle.
- Determinism: preserve stable ordering for objective rows, pages, and activity details.
- Accessibility: satisfy keyboard operation, ARIA state, and visible-focus expectations from the Jira ticket.
- Internationalization: preserve original titles for display; do not replace source labels with normalized search text or identifiers.

## 9. Data, Interfaces & Dependencies

- Primary data interface: `Oli.Authoring.ObjectiveCoverage`.
- Primary UI consumer: `lib/oli_web/live/workspaces/course_author/objectives_live.ex`.
- Core data dependency: `docs/exec-plans/current/epics/objectives-editor/core_data/informal.md` and its implemented compact working-publication projection.
- The model supplies objective hierarchy, direct and inherited attachment relationships, page-first details, assessment buckets, stable resource metadata, and deterministic ordering.
- Embedded activity relationships come from `activity_refs`; initial coverage excludes Activity Bank selections and standalone banked activities.
- Page navigation should use existing authoring route conventions, including `Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page.slug)` where applicable.
- Jira source: `MER-5794`, under the Objectives Editor epic `MER-5784`; the later Jira comment excluding Activity Bank selections supersedes the original Activity Bank navigation bullet for v35.
- Jira records `MER-5793` as a blocker; this dependency requires confirmation before implementation because the epic plan schedules hierarchy updates in a later lane.

## 10. Repository & Platform Considerations

- Keep domain and coverage shaping in `lib/oli/`; keep LiveView orchestration and rendering concerns in `lib/oli_web/`.
- Preserve the mixed Phoenix LiveView and focused React architecture; extend the existing workspace surface rather than introducing a broad client shell.
- Use Phoenix LiveView tests for server-driven expansion, toggle, rendering, and navigation behavior; use Jest/component tests if the relevant interaction is client-side.
- Reuse existing authoring components, icons, routes, and accessibility conventions.
- Apply security, performance, Elixir/LiveView, UI, TypeScript, and requirements review lenses as applicable to the implementation changes.
- Jira remains the system of record for scope and implementation tracking.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Roll out through the normal deployment process after the core data source and UI verification gates pass. No migration or backfill is required because Activity Bank coverage remains deferred.

## 12. Telemetry & Success Metrics

- Reuse existing aggregate ObjectiveCoverage load/build telemetry and AppSignal conventions without logging authored page or activity content.
- Observe model-load duration, row/resource counts, and tagged failure states where existing telemetry is available.
- Success signal: authors can determine objective coverage and open related pages or embedded activities without issuing additional per-objective content queries or mutating associations.
- UX verification should confirm correct counts, useful expansion behavior, assessment filtering, navigation, and accessible interaction states.

## 13. Risks & Mitigations

- Incorrect parent aggregation: reuse the core model's descendant-aware summaries and add tests distinguishing parent, child, and duplicate attachment behavior.
- Formative/summative leakage: classify pages from `graded` and inherit activity classification from the containing page; test both buckets explicitly.
- UI introduces N+1 or full-content reads: keep the LiveView bound to the ObjectiveCoverage model and review query boundaries.
- Activity Bank requirements conflict: treat the explicit v35 Jira comment as the current scope and document bank coverage as follow-up work.
- Navigation loses activity context: preserve page resource identifiers, slugs, and supported anchor/focus metadata in rendered links.
- Accessibility regressions: test keyboard interaction, ARIA expanded/selected state, and visible focus behavior.
- Dependency on hierarchy work is unclear: resolve the `MER-5793` blocker before implementation or move only the required hierarchy foundation into the core UI slice.

## 14. Open Questions & Assumptions

### Open Questions

- Does `MER-5793` provide a hard prerequisite for the summary/attachment UI, or can the existing hierarchy render the required states?
- What exact page-editor URL/query/anchor contract is available for focusing an embedded activity?
- What exact empty-state copy and loading/error presentation should be used if the Figma nodes do not specify them?
- Should an activity repeated on multiple pages display page-local duplicates while remaining deduplicated in summary counts? The core-data design assumes yes.

### Assumptions

- `MER-5855` is the authoritative data source and is available before this UI slice is integrated.
- The workspace Learning Objectives editor is the primary target; the older objectives route is not migrated by this work item.
- Static embedded activities are the only activity coverage shown in v35.
- Page assessment classification is determined by `graded`; embedded activities inherit the containing page's bucket.
- Existing authoring authorization and project scoping apply to the UI's data load and navigation.
- Figma is authoritative for visual details and component states; Jira acceptance criteria and comments are authoritative for product scope.

## 15. QA Plan

- Automated validation:
  - Run `requirements_trace.py` capture and structure validation, then `validate_work_item.py --check prd`.
  - Add targeted LiveView/component tests for summary counts, direct versus inherited semantics, independent expansion, assessment toggling, page-first details, empty states, navigation, and no-write behavior.
  - Add accessibility assertions for keyboard operation, ARIA expanded/selected state, and visible-focus classes/attributes where supported by the test stack.
  - Run affected `mix test` targets and/or focused `yarn test` targets, plus `mix format` or frontend formatting/linting as applicable.
  - Review the ObjectiveCoverage query boundary for project scoping, no full content selection, and no per-row query path.
- Manual validation:
  - Compare summary, expanded, overflow, empty, and navigation states against the linked Figma nodes and Jira screenshots.
  - Verify a parent with descendant-only content, a direct-only Sub-Objective, duplicate attachments, formative and summative pages, and a page with no matching activities.
  - Verify Activity Bank selections are absent and navigation leaves all associations unchanged.
  - Verify keyboard-only operation and screen-reader-visible state for expansion and assessment selection.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
