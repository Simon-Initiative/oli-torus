# MER-5800 Learning Objectives Course Content Filter - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/objectives-editor/content_filter/prd.md`
- FDD: `docs/exec-plans/current/epics/objectives-editor/content_filter/fdd.md`
- Requirements: `docs/exec-plans/current/epics/objectives-editor/content_filter/requirements.yml`
- Informal source: `docs/exec-plans/current/epics/objectives-editor/content_filter/informal.md`
- Parent epic plan: `docs/exec-plans/current/epics/objectives-editor/plan.md`
- Shared data dependency: `docs/exec-plans/current/epics/objectives-editor/core_data/`
- Jira: `MER-5800` under epic `MER-5784`
- Figma toolbar reference: `https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=327-29961&m=dev`

## Scope

Implement the Course content filter in the current workspace Learning Objectives editor. The work includes the Figma-aligned toolbar control, hierarchical curriculum checklist, read-only filtering through direct page and embedded-activity coverage, active selection count, query-parameter persistence, composition with existing table state, and accessibility behavior.

The implementation extends `Oli.Authoring.ObjectiveCoverage`, `OliWeb.Workspaces.CourseAuthor.ObjectivesLive`, and the existing sortable-table lifecycle. It does not add database storage, a new process, a new global cache, Activity Bank coverage, or unrelated search/Coverage Issues/CSV functionality.

## Clarifications & Default Assumptions

- Use the current workspace editor route; do not expand this slice to the older Objectives LiveView.
- Use a new `course_content` query parameter containing sorted, deduplicated curriculum resource ids unless adjacent feature work establishes a repository-standard key before implementation.
- Explicit parent selections are retained separately from effective descendant page scope. Child items are not automatically selected when a parent is selected.
- Effective scope is the deduplicated set of pages under selected curriculum nodes. OR semantics apply across selected branches.
- Objective matching includes direct page tags and objective tags on embedded activities within selected pages.
- The active count is the deduplicated count of selected active containers and pages, as clarified in Jira.
- Use native checkbox semantics where possible; confirm the parent selected-state visual treatment against Figma before final markup.
- No feature flag, migration, new telemetry event, or persistent user preference is planned.

## Phase 1: Coverage API and Filter-State Contract

- Goal: Establish pure, testable curriculum scope and objective matching APIs plus a stable URL/state contract before changing the toolbar.
- Tasks:
  - [x] Confirm the final query key/encoding and document it in the implementation if adjacent search or Coverage Issues work defines a shared convention.
  - [x] Extend `Oli.Authoring.ObjectiveCoverage` with a pure page-to-objective matching accessor, using existing direct page and embedded-activity indexes.
  - [x] Add a pure curriculum-node accessor or view model that exposes stable ids, titles, resource types, ordered children, and path/depth data for the checklist.
  - [x] Define normalization helpers for positive ids, sorted/deduplicated explicit selections, effective page ids, active container/page count, and invalid URL values.
  - [x] Define composition rules for content matches with existing search, sort, pagination, expansion, and Coverage Issues parameters.
  - [x] Keep the API project-scoped and request-snapshot based; do not add queries, writes, caches, or process state.
- Testing Tasks:
  - [x] Add ObjectiveCoverage tests for Unit/Module/Section/Page descendant expansion and deterministic ordering.
  - [x] Add tests for OR semantics, overlapping parent/child deduplication, direct page tags, embedded-activity tags, and matching parent/sub-objective ids.
  - [x] Add tests for invalid/missing/cyclic optional curriculum data and stable empty selections.
  - [x] Command(s): `mix test test/oli/authoring/objective_coverage_test.exs`
- Definition of Done:
  - Pure APIs provide checklist data, effective page scope, objective matches, and active counts without database access.
  - URL parsing/serialization rules are explicit and preserve unrelated existing parameters.
  - Tests cover the data contract for AC-002, AC-003, AC-005, AC-009, and AC-010.
- Gate:
  - ObjectiveCoverage tests pass; code inspection confirms no full page/activity content load, N+1 filter query, or mutation path.
- Dependencies:
  - `objectives-editor/core_data` ObjectiveCoverage model and its existing curriculum indexes.
- Parallelizable Work:
  - Query-key investigation and test fixture preparation can proceed in parallel, but API implementation must settle before LiveView integration.

## Phase 2: LiveView State, Filtering, and URL Persistence

- Goal: Integrate the content selection into the existing `ObjectivesLive` table/filter lifecycle while preserving all other URL-backed state.
- Tasks:
  - [x] Add explicit selection and derived effective-scope assigns with loading, ready, reload, and invalid-selection behavior.
  - [x] Update `live_path/2` and the patch parameter helper so Course content selections round-trip with query, sort, order, offset, expansion, sidebar, and existing filter parameters.
  - [x] Add LiveView events for opening/closing, toggling an item, and clearing all Course content selections; route selection changes through `push_patch/2` and reset pagination to zero.
  - [x] Extend `filter_rows/3` or its composition seam to apply content matching and existing search matching before sorting and pagination.
  - [x] Ensure direct URL load, refresh, back/forward navigation, and coverage reload restore only valid selections and recompute results.
  - [x] Render the Course content empty state when selections produce no objectives without resetting unrelated state.
  - [x] Preserve read-only behavior and project authorization; validate all ids against the loaded model.
- Testing Tasks:
  - [x] Add LiveView tests for initial URL restoration, selection/clear patches, multiple selections, parent/child semantics, and pagination reset.
  - [x] Add tests proving search, sort, and existing filter parameters survive applying Course content selections; Coverage Issues-specific UI is not present in this LiveView.
  - [x] Add tests for refresh/direct URLs, copied URLs, patch-compatible URL state, no matches, invalid ids, and no writes.
  - [x] Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - The table displays only objectives/Sub-Objectives matching the effective selected page scope.
  - Query parameters are the source of truth and all existing table state remains compatible.
  - Tests cover AC-003, AC-004, AC-005, AC-006, and AC-010.
- Gate:
  - Targeted LiveView tests pass and rendered state proves that filter interaction changes only view/query state, never course content or relationships.
- Dependencies:
  - Phase 1 ObjectiveCoverage APIs and the existing `SortableTable.TableHandlers` parameter lifecycle.
- Parallelizable Work:
  - LiveView URL/state tests and empty-state copy can be prepared while API tests finish; event wiring depends on the finalized parameter contract.

## Phase 3: Toolbar Checklist Component and Accessibility

- Goal: Deliver the Figma-aligned Course content control and an accessible, usable hierarchical checklist.
- Tasks:
  - [x] Add a focused `ContentFilter` function component under `lib/oli_web/live/workspaces/course_author/objectives/` or the final existing objectives component namespace.
  - [x] Place the trigger after Coverage Issues and before Download CSV/New Objective, with the exact `Course content` label and existing design tokens/components.
  - [x] Render deterministic nested Unit/Module/Section/Page rows with scroll containment and independent expand/collapse state.
  - [x] Render explicit checkbox state separately from effective descendant scope; apply the approved parent/child visual treatment.
  - [x] Add active indication and deduplicated selected active container/page count.
  - [x] Add truncation and full-title tooltip behavior for overflowing curriculum titles.
  - [x] Implement Escape/outside-click/focus-return behavior according to the confirmed component convention.
  - [x] Add semantic hierarchy, accessible labels, `aria-expanded`, `aria-controls`, checkbox state, visible focus styles, and keyboard operation.
  - [x] Keep the component controlled by LiveView selection state and emit only the defined read-only events.
- Testing Tasks:
  - [x] Add render/event tests for toolbar placement, checklist rendering, selection patching, active badge/count, and clear behavior.
  - [x] Add accessibility assertions for native checkbox labels, tree semantics, expanded trigger state, and visible focus indicators.
  - [x] No client-side component was introduced; focused Jest tests and frontend lint/format checks are not applicable.
  - [x] Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
  - [x] Not applicable: phase 3 is implemented as a server-rendered HEEx/LiveView component with no frontend bundle changes.
- Definition of Done:
  - The toolbar and checklist match the approved Figma intent and existing Torus component/token conventions.
  - Authors can operate the complete control with keyboard and assistive technology.
  - Tests cover AC-001, AC-002, AC-007, AC-008, and AC-009.
- Gate:
  - LiveView/component tests pass; manual keyboard and Figma comparison find no missing state, focus, hierarchy, truncation, or tooltip behavior.
- Dependencies:
  - Phase 2 state/events and the final checklist-node interface.
- Parallelizable Work:
  - Visual styling, accessibility assertions, and manual Figma inspection can proceed in parallel after the component input/event contract is fixed.

## Phase 4: Hardening, Review, and Traceability Closure

- Goal: Verify the complete slice against repository quality, security, performance, accessibility, design, and requirements gates.
- Tasks:
  - [x] Review project/institution scoping and query-param validation for unauthorized resource exposure.
  - [x] Review query and memory behavior for one compact snapshot, no full content loads, no N+1 interactions, and bounded URL/state normalization.
  - [x] Review telemetry/logging for useful error visibility without course-content or title leakage.
  - [x] Compare toolbar, open menu, active state, long-title, empty, and no-match states with the Figma references and Jira screenshots.
  - [x] Run applicable security, performance, Elixir/LiveView, UI/TypeScript, and requirements reviews under `docs/CODEREVIEW.md`.
  - [x] Add implementation proof references for every acceptance criterion in changed tests/code artifacts.
  - [x] Update FDD/plan assumptions if query encoding, parent checkbox state, or CSV parameter composition changes during implementation.
- Testing Tasks:
  - [x] Run focused ObjectiveCoverage and ObjectivesLive suites.
  - [x] Run broader authoring/objectives regression targets if shared table, URL, or coverage helpers changed.
  - [x] Run formatting and relevant frontend lint/tests for changed files; frontend checks are not applicable because no `assets/` files changed.
  - [x] Command(s): `mix test test/oli/authoring/objective_coverage_test.exs test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
  - [x] Command(s): `mix format --check-formatted`
  - [x] Command(s): `python3 /Users/raph/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/objectives-editor/content_filter --action verify_implementation`
- Definition of Done:
  - All ten acceptance criteria have implementation proof and the implementation matches the PRD/FDD scope.
  - Targeted tests, formatting, applicable frontend checks, reviews, and traceability checks pass.
  - No competing coverage query, persistent filter state, or mutation behavior has been introduced.
- Gate:
  - Phases 1-3 pass; all AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, and AC-010 references are verified; no unresolved review findings remain.
- Dependencies:
  - Phases 1-3 complete.
- Parallelizable Work:
  - Security review, performance review, Figma comparison, and documentation reconciliation can run concurrently before final validation.

## Parallelization Notes

- Phase 1 is the dependency foundation because both LiveView filtering and checklist rendering depend on stable ObjectiveCoverage accessors and selection semantics.
- Phase 2 and Phase 3 may overlap after Phase 1’s interfaces are fixed: LiveView URL/filter behavior can proceed alongside component markup, but both must use the same controlled selection contract.
- Phase 4 reviews and manual visual/accessibility checks can run in parallel, followed by the final sequential test and traceability gates.
- Do not parallelize changes that independently invent query-parameter encoding, parent selection visuals, or objective matching rules; those decisions must remain centralized.

## Phase Gate Summary

- Gate A: ObjectiveCoverage scope/matching APIs and selection normalization pass pure tests for AC-002, AC-003, AC-005, AC-009, and AC-010.
- Gate B: LiveView filtering, query persistence, filter composition, clear/no-match behavior, and read-only state pass AC-003, AC-004, AC-005, AC-006, and AC-010.
- Gate C: Figma-aligned toolbar/checklist and keyboard/accessibility behavior pass AC-001, AC-002, AC-007, AC-008, and AC-009.
- Gate D: Full targeted regression, formatting, review, design comparison, implementation proof, and requirements validation pass AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, and AC-010.
