# Learning Objectives Course Content Filter - Functional Design Document

## 1. Executive Summary

Extend the current workspace Learning Objectives LiveView with a read-only Course content filter backed by the existing `Oli.Authoring.ObjectiveCoverage` snapshot. The design keeps curriculum scope calculation in the coverage module, keeps URL/state orchestration in the LiveView, and renders the hierarchical checklist through a focused Phoenix component. No database schema, persistence model, or new process is required.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001: Add the Figma-aligned `Course content` toolbar control.
  - FR-002/FR-003: Render a scrollable Unit/Module/Section/Page checklist with OR selection, descendant inclusion, and correct objective/Sub-Objective matching.
  - FR-004: Preserve composed state and serialize selections in query parameters.
  - FR-005: Show active state and the deduplicated active container/page count.
  - FR-006: Provide accessible, truncating, tooltip-backed, resilient controls.
  - FR-007: Use the shared compact, read-only coverage model.
- Non-functional requirements:
  - Filtering must be deterministic, scoped to the project’s working publication, free of N+1 interaction queries, and free of writes.
  - Controls must satisfy the ticket’s keyboard, ARIA, semantic hierarchy, labeling, focus, and tooltip requirements.
- Assumptions:
  - The current workspace route is the implementation target: `lib/oli_web/live/workspaces/course_author/objectives_live.ex`.
  - The query parameter is a comma-separated, sorted list of curriculum resource ids under the `course_content` key.
  - Parent selections are scope shortcuts. The selected set remains the explicitly selected node ids; effective page scope is expanded in the coverage module.
  - Activity Bank selections remain outside the embedded-only coverage boundary.

Traceability: AC-001 through AC-010 are represented by the design and verification decisions below.

## 3. Repository Context Summary

- What we know:
  - `ObjectivesLive` already owns toolbar rendering, URL patching through `live_path/2`, search state, sorting through `SortableTable.TableHandlers`, async coverage loading, and objective row rendering.
  - `Oli.Authoring.ObjectiveCoverage` already builds one compact working-publication projection and exposes `curriculum_by_id`, `curriculum_children_by_parent`, `curriculum_descendants_by_id`, `curriculum_paths_by_id`, `pages_by_id`, objective coverage, and `curriculum_pages/2`.
  - `filter_rows/3` is the existing table filter seam, but raw URL state is only available during `handle_params/3`; the implementation uses an optional `filter_rows/4` callback for the content predicate while retaining the three-argument compatibility form.
  - `SortableTable.TableHandlers` already handles query-param-driven pagination, sorting, search, and filter patches. Changes must preserve its parameter contract.
  - The existing LiveView tests cover search, sort, URL state, coverage loading, and objective rendering in `test/oli_web/live/workspaces/course_author/objectives_live_test.exs`.
  - The coverage unit tests in `test/oli/authoring/objective_coverage_test.exs` are the right place for pure curriculum-to-page and objective matching behavior.
  - The approved toolbar reference is [Figma node 327:29961](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=327-29961&m=dev); the ticket also links filter-state references at nodes 502:12219 and 365:19378.
- Phase-3 decisions:
  - The checklist is a feature-local native `<details>` hierarchy with native checkboxes; no existing shared tree primitive fit the controlled URL-backed behavior.
  - Parent selection is explicit only: descendant checkboxes remain independently selected while descendant scope is applied by the coverage model.
  - The empty-state copy is `No learning objectives match the selected course content.` and the URL key is the sorted, comma-separated `course_content` value.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

1. `ObjectivesLive` adds the toolbar trigger and assigns `course_content_open`, `course_content_selection`, `course_content_scope_ids`, and the loaded coverage state.
2. A focused function component, preferably `OliWeb.Workspaces.CourseAuthor.Objectives.ContentFilter`, renders the trigger, active count, scrollable checklist, expansion controls, checkboxes, and tooltip attributes. It emits LiveView events rather than owning persisted state.
3. `ObjectivesLive.handle_event/3` handles opening/closing and selection changes. Each selection normalizes ids, resets pagination to zero, and calls `push_patch/2` through `live_path/2` with all current table params plus the new content selection.
4. `ObjectivesLive.filter_rows/4` parses the normalized selection from raw URL params, asks `ObjectiveCoverage` for matching objective ids, then composes those ids with the existing search result before table sorting and pagination. The three-argument form remains as a compatibility delegate.
5. `ObjectiveCoverage` owns curriculum descendant expansion and page/objective matching. The LiveView does not scan revisions or reconstruct activity relationships.

The toolbar order is search/sort, Coverage Issues, Course content, then the existing Download CSV and New Objective actions, matching the supplied Figma reference.

### 4.2 State & Data Flow

Initial load:

1. `mount/3` initializes an empty selected-id set and starts the existing async `ObjectiveCoverage.load/1` task.
2. `handle_async/3` stores the model and calls a single filtering/table-refresh path.
3. The component receives a deterministic checklist derived from `model.curriculum_by_id` and `model.curriculum_children_by_parent`.

Selection update:

1. The event payload contains one curriculum resource id and its intended checked/unchecked state.
2. The LiveView validates positive integer ids against `model.curriculum_by_id`, updates only explicit selections, sorts and deduplicates them, and pushes a patch with `course_content=<id,id,...>`.
3. `handle_params/3` restores the selection from the URL, normalizes it through `ObjectiveCoverage.normalize_curriculum_selection/2`, and derives the effective scope through `ObjectiveCoverage.objective_scope_for_pages/2`.
4. The table filter composes content matching with the current query/search matching ids. Sort and pagination then operate on the filtered rows.
5. If no selections are present, the content predicate is an identity function and the complete list is restored.

Effective scope is a set of page resource ids. For each explicit selected node, include the node and its precomputed descendants, then retain ids present in `pages_by_id`. This naturally gives OR semantics and deduplicates overlapping parent/child selections.

### 4.3 Lifecycle & Ownership

- URL query parameters are the durable source of truth for selected curriculum ids and existing table state.
- LiveView assigns are the render-time cache of parsed URL state and the loaded coverage snapshot.
- The dropdown open/closed state is transient UI state. It may remain local to the component, but selection state must be controlled by the LiveView so patches, refreshes, and browser navigation converge on one state.
- The coverage snapshot is request/process scoped as documented by `ObjectiveCoverage`; it is not cached globally and does not need a supervisor or transaction.
- When coverage reloads after an authoring mutation, retain only selected ids still present in the new model and recompute effective scope/results.

### 4.4 Alternatives Considered

- Database query per selection: rejected because it violates the existing compact projection boundary and creates N+1 behavior for a read-only filter.
- Full page-content scan in the LiveView: rejected because `activity_refs` and the existing coverage indexes already provide the required page/activity relationship.
- Client-only filtering: rejected because the authoritative coverage model and existing table/search lifecycle are server-side LiveView state, and URL/history behavior should be handled by Phoenix patches.
- New persisted filter state: rejected because query parameters satisfy sharing/history requirements without a migration or user-specific stored preference.
- Rebuilding the entire table/filter framework: rejected because `SortableTable.TableHandlers` already provides the correct patch and sorting lifecycle; extend its filter seam instead.

## 5. Interfaces

- `Oli.Authoring.ObjectiveCoverage.curriculum_pages(model, selected_ids) :: [positive_integer()]`
  - Existing function; use it to expand explicit curriculum selections into deduplicated page ids.
- Add pure coverage APIs: `ObjectiveCoverage.objective_ids_for_pages(model, page_ids) :: MapSet.t()` for directly matched objective ids and `ObjectiveCoverage.objective_scope_for_pages(model, page_ids) :: MapSet.t()` for those ids plus objective ancestors.
  - They must union direct page objective ids and objective ids from embedded activities occurring on those pages, return deterministic ids, and perform no database access or writes.
  - Keeping direct matches separate from the visible objective scope lets the UI show a matching parent while hiding unrelated sibling Sub-Objectives.
- Add a pure helper, preferably `ObjectiveCoverage.curriculum_nodes(model) :: [map()]`, if the component should not know the model’s internal map shape.
  - Return stable node ids, titles, resource type, ordered child ids, and depth/path metadata needed for rendering and accessible labels.
- `ObjectivesLive.live_path/2`
  - Preserve existing `query`, `filter`, `sort_by`, `sort_order`, `offset`, `expanded`, and sidebar parameters while adding/removing the content selection key.
- LiveView events:
  - `toggle_course_content_filter`: open/close the menu.
  - `toggle_course_content_item`: validate and patch one explicit selection.
  - `clear_course_content_filter`: remove the selection parameter and patch the current URL state.
- Component assigns should include a stable root id, checklist nodes, selected ids, effective count, and open state. Interactive elements must expose `aria-expanded`, `aria-checked`/native checkbox state, `aria-controls`, and labels containing curriculum titles.

## 6. Data Model & Storage

- No database schema change, migration, or new persistent record.
- URL representation: sorted, comma-separated curriculum resource ids under the agreed `course_content` query key. Invalid ids are ignored when parsing; an empty normalized set removes the key.
- In-memory model additions, only if needed:
  - page-to-objective lookup including direct page tags and embedded activity tags; or
  - a derived `objective_ids_by_page` map built once during `ObjectiveCoverage.build/2`.
- Existing `curriculum_descendants_by_id` supplies parent expansion. Existing `curriculum_by_id` and `curriculum_children_by_parent` supply checklist nodes. Existing objective hierarchy maps determine parent/sub-objective rendering.
- The active count is computed from the deduplicated effective selection of containers and pages, not from the number of explicit ids and not from objective matches.

## 7. Consistency & Transactions

- There is no write transaction. Every selection event is a pure state transition followed by a LiveView URL patch.
- The selected ids and all other table params are atomically represented by one generated URL, preventing partial client/server state.
- If a selected curriculum node disappears between URL creation and coverage load, ignore it and remove it from the normalized effective state on the next patch/render.
- The current working-publication snapshot is the consistency boundary for one render. A later authoring change is reflected when the existing coverage reload path runs.

## 8. Caching Strategy

N/A for cross-request caching. Reuse the existing request-scoped `ObjectiveCoverage` snapshot and its precomputed descendant/relationship maps. Memoization inside `ObjectiveCoverage.build/2` is appropriate for construction, but no Cachex key or supervised cache should be added.

## 9. Performance & Scalability Posture

- Load curriculum and relationship data once with the existing compact projection.
- Expand selected curriculum nodes with map lookups and `MapSet`/sorted-list operations; do not query per node or per objective.
- Precompute page-to-objective matching once if the current model cannot derive it without scanning all pages on every filter event.
- Keep filtering linear in the number of selected/effective pages plus objective relationships, followed by the existing table sort/pagination.
- Bound URL input by accepting only positive integer ids, deduplicating them, and optionally applying the existing query-length conventions if the repository has one.
- Verify with unit tests and code review that full revision `content` is not selected or loaded and that no N+1 query path is introduced.

## 10. Failure Modes & Resilience

- Coverage is still loading: render the existing loading state and keep the filter disabled or visibly unavailable until the model exists.
- Coverage load fails: retain the existing error/retry state; do not attempt ad hoc curriculum queries.
- Invalid query ids: discard unknown/non-positive ids and render the valid subset without crashing.
- Missing children or cyclic/malformed curriculum data: rely on the model’s normalized safe descendant maps, render available nodes, and avoid recursive UI traversal without a visited/derived structure.
- No matching objectives: preserve the table’s existing empty-state mechanism with Course content-specific copy when content selections are active.
- Very long titles: apply overflow truncation and tooltip metadata without allowing the menu to widen or break scrolling.
- Browser history patch race: use `push_patch`/`replace` consistently with the existing table handlers and derive render state from `handle_params/3`, not only from the click event.

## 11. Observability

- Reuse existing `ObjectiveCoverage` load/build telemetry and AppSignal error monitoring.
- Log unexpected coverage/filter exceptions at the existing LiveView boundary with project-scoped metadata, without logging full course content or query URLs containing excessive data.
- No new business telemetry event is required. If an existing UI interaction telemetry convention is used, record filter open/apply/clear counts without curriculum titles or learner data.
- Monitor coverage load latency and LiveView errors; filtering itself should remain in-process and should not add database latency per interaction.

## 12. Security & Privacy

- The existing authoring route authorization and project scope remain the access-control boundary. The filter must operate only on the already-authorized project’s working publication.
- Validate ids against the loaded project model; never use query-param ids to fetch arbitrary resources outside the project.
- Filtering is read-only and must not invoke objective/page/activity mutation events.
- Do not expose hidden resource data in tooltips, labels, logs, or URL parameters; URLs contain only resource identifiers needed to reproduce the view.
- Preserve existing institution/project scoping in the LiveView and coverage query.

## 13. Testing Strategy

- `test/oli/authoring/objective_coverage_test.exs`:
  - Test curriculum parent expansion, overlapping selection deduplication, stable ordering, and page-only effective scope.
  - Test direct page and embedded-activity objective matching, including parent Learning Objective inclusion and Sub-Objective distinction.
  - Test invalid/missing/cyclic optional curriculum data and no database access from pure filter functions.
- `test/oli_web/live/workspaces/course_author/objectives_live_test.exs`:
  - Test toolbar trigger/menu, hierarchy rendering, multiple selections, parent/child semantics, active count, clear, and no-match state.
  - Test URL serialization/restoration and composition with query, sort, Coverage Issues params, refresh, and back/forward-compatible patches.
  - Test filtering does not change persisted objective/page/activity associations.
  - Assert required labels, native checkbox state or ARIA state, `aria-expanded`, focus classes, truncation, and tooltip attributes.
- If the component is extracted into a client-side React surface, add the narrow Jest/component tests there and retain LiveView tests for URL and server filtering behavior.
- Run the targeted `mix test` files, `mix format --check-formatted` or repository-equivalent formatting gate, and the relevant frontend test/lint checks if a client component is introduced.

Requirements coverage: FR-001/AC-001; FR-002/AC-002; FR-003/AC-003; FR-004/AC-004; FR-005/AC-005/AC-006; FR-006/AC-007/AC-008/AC-009; FR-007/AC-010.

## 14. Backwards Compatibility

- Existing URLs without `course_content` remain unchanged and show the full objective list.
- Existing search, sort, expansion, sidebar, Coverage Issues, and CSV parameters must continue to parse and round-trip when Course content is added.
- Existing `selected` legacy expansion behavior remains untouched; the new course-content key must not reuse `selected` because that parameter is already interpreted by the sortable table compatibility path.
- No migration or backfill is required.

## 15. Risks & Mitigations

- The existing coverage model lacks a direct page-to-objective API: add one pure derived index/API rather than putting relationship logic in the LiveView.
- The shared sortable-table handler may overwrite custom params: centralize URL construction in `live_path/2`/the patch helper and add round-trip tests with every existing parameter.
- The sortable-table lifecycle provides an optional four-argument filter callback and post-parameter synchronization callback so feature-specific URL state is available before filtering without changing existing table consumers.
- A custom nested checklist may be inaccessible: prefer semantic native controls, explicit hierarchy metadata, and automated plus manual keyboard checks.
- Parent selection semantics may be visually ambiguous: confirm Figma/product behavior before implementation and separate explicit selection state from effective descendant scope.
- Large hierarchies may produce unwieldy URLs: normalize/deduplicate ids and confirm acceptable URL size; if necessary, define a compact encoding before implementation rather than adding persistence.

## 16. Resolved Decisions & Follow-ups

- The final query key is `course_content`, encoded as sorted, comma-separated resource ids; existing query, sort, order, expansion, sidebar, and generic filter parameters are preserved.
- Parent selection is represented by an explicit parent checkbox; descendant scope is applied by the coverage model without marking child checkboxes selected.
- The menu closes on outside click/Escape and returns focus to the trigger through the existing LiveView JS convention.
- Empty-state copy is `No learning objectives match the selected course content.`; the active count is the deduplicated selected active container/page count.
- CSV export preserves the content selection through the existing parameter projection; dedicated CSV behavior remains outside this feature’s scope.

## 17. References

- `docs/exec-plans/current/epics/objectives-editor/content_filter/informal.md`
- `docs/exec-plans/current/epics/objectives-editor/content_filter/prd.md`
- `docs/exec-plans/current/epics/objectives-editor/content_filter/requirements.yml`
- `docs/exec-plans/current/epics/objectives-editor/core_data/informal.md`
- `lib/oli/authoring/objective_coverage.ex`
- `lib/oli_web/live/workspaces/course_author/objectives_live.ex`
- `lib/oli_web/live/common/sortable_table/table_handlers.ex`
- `test/oli/authoring/objective_coverage_test.exs`
- `test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- [MER-5800](https://eliterate.atlassian.net/browse/MER-5800)
- [Figma toolbar reference](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=327-29961&m=dev)
