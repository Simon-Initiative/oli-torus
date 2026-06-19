# Bank Selection Manager - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/fdd.md`

## Scope
Deliver `MER-5622` as the standalone bank-selection management LiveView inside preview mode. The work covers the destination route, shared preview shell integration, paged candidate browsing, right-panel question preview, selection-candidate remove/restore flows, invalid-removal warning handling, and success feedback. It explicitly excludes the page-level `Manage Questions` launch link wiring from `PreviewLessonLive`.

## Clarifications & Default Assumptions
- `MER-5620` or a follow-up ticket will wire the page-level CTA into this route later.
- `Remove` / `Restore` in this work item are triggered from the right-hand preview through the existing preview action contract; the left list owns selection state and reflects removed/enabled state.
- Any left-list multi-select or bulk mutation behavior is out of scope here and belongs to `MER-5623`.
- The new surface reuses the preview-shell header contract from `MER-5617` and preview activity rendering from `MER-5618`.
- Initial endless-scroll behavior may be implemented as deterministic paged append in LiveView; no browser-side virtualization is assumed.
- No feature flag is planned for this work item.

### Requirements Traceability
- `AC-001`, `AC-002`:
  - covered by Phase 1 through the new route, mount validation, and preview context handling
- `AC-003`, `AC-004`:
  - covered by Phase 2 through shell/header reuse and local back behavior
- `AC-005`, `AC-006`, `AC-007`, `AC-008`:
  - covered by Phases 2 and 3 through the paged candidate list, row states, and right-panel preview
- `AC-009`, `AC-010`, `AC-011`, `AC-012`, `AC-013`:
  - covered by Phase 4 through mutation events, modal handling, whole-bank removal, and flash feedback

## Phase 1: Route And Preview Session Integration
- Goal: introduce the standalone preview-session destination route and validate mount-time scope.
- Tasks:
  - [x] Add `PreviewRoutes.selection_path/4`.
  - [x] Add a new LiveView route under the existing preview live session.
  - [x] Resolve and validate section/page/selection targets during mount.
  - [x] Preserve safe `return_to` and `request_path` handling for the new route.
- Testing Tasks:
  - [x] Add route-helper and authorization coverage.
  - [x] Add LiveView tests for valid and invalid route access.
  - Command(s): `mix test test/oli_web/live/delivery/instructor`
- Definition of Done:
  - authorized preview users can open the selection-manager route directly
  - invalid targets fail safely without crashing the preview session
- Gate:
  - route and mount tests pass
- Dependencies:
  - existing preview-shell/session work from `MER-5617`
- Parallelizable Work:
  - route helper and mount validation can proceed in parallel with initial UI skeleton work once the path shape is fixed

## Phase 2: Shell, Local Back Contract, And Candidate List Surface
- Goal: render the Figma-aligned management workspace with paged candidate rows and selection state.
- Tasks:
  - [x] Build the LiveView layout using the reusable Instructor View header and delivery header.
  - [x] Add the local back control and origin-page contract separate from the persistent header return.
  - [x] Render selection metadata, active available count, and candidate rows with removed-state styling.
  - [x] Implement incremental candidate loading from `list_bank_selection_candidates/4`, using the already resolved `%Section{}`, `%Revision{}`, and selection map once mount has established them.
  - [x] Keep selected-row state stable as additional pages load.
- Testing Tasks:
  - [x] Add LiveView tests for shell rendering, local back behavior, removed-state row styling, and paged append behavior.
  - Command(s): `mix test test/oli_web/live/delivery/instructor`
- Definition of Done:
  - the management surface matches the intended structural layout
  - candidate rows load incrementally and preserve selected state
- Gate:
  - list-state and navigation tests pass
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - UI structure and paged state helpers can be split once mount assigns are stable

## Phase 3: Right-Panel Preview Rendering
- Goal: preview the currently selected candidate through the shared preview activity pipeline.
- Tasks:
  - [x] Add a server-side helper or presenter for rendering one candidate preview.
  - [x] Default selection to the first visible row when present.
  - [x] Update the right panel dynamically when the user selects another row.
  - [x] Reuse existing browser hooks/components needed to hydrate preview custom elements in the rendered HTML.
- Testing Tasks:
  - [x] Add Elixir tests for the preview-render helper.
  - [x] Add LiveView tests proving row selection updates the right-hand preview.
  - Command(s): `mix test test/oli_web/live/delivery/instructor test/oli_web/components/delivery`
- Definition of Done:
  - selecting a candidate updates the right panel without introducing a new preview stack
- Gate:
  - preview helper and row-selection tests pass
- Dependencies:
  - Phase 2
  - preview rendering contract from `MER-5618`
- Parallelizable Work:
  - helper extraction and panel markup can proceed in parallel once the selected-row state contract is settled

## Phase 4: Mutation Flows, Warning Modal, And Feedback
- Goal: support remove/restore, invalid-removal protection, whole-bank removal from the modal, and success feedback.
- Tasks:
  - [x] Implement `Remove` and `Restore` event handlers through `Oli.Delivery.InstructorCustomizations`.
  - [x] Refresh visible rows and active count from authoritative context responses after each mutation.
  - [x] Implement the invalid-removal warning modal with dynamic copy from the insufficient-candidates error payload.
  - [x] Implement the `Remove bank` path from the modal through `exclude_bank_selection/4`.
  - [x] Add success flash messages for remove, restore, and whole-bank removal outcomes.
- Testing Tasks:
  - [x] Add LiveView tests for successful remove/restore, invalid-removal modal flow, and whole-bank removal behavior.
  - [x] Add tests for count refresh and mutually exclusive actions per row.
  - Command(s): `mix test test/oli_web/live/delivery/instructor`
- Definition of Done:
  - remove/restore auto-save correctly
  - invalid removals warn instead of silently persisting
  - success feedback is visible after mutations
- Gate:
  - mutation and warning-flow tests pass
- Dependencies:
  - Phase 3
- Parallelizable Work:
  - success-flash copy and modal rendering can be developed alongside the mutation event handlers

## Phase 5: QA Hardening And Spec Sync
- Goal: close the work item with targeted verification, accessibility checks, and spec updates if implementation details drift.
- Tasks:
  - [x] Run targeted LiveView and helper tests across the new route and mutation flows.
  - [x] Perform manual comparison against the manager and modal Figma nodes.
  - [x] Verify keyboard/focus behavior across row actions and modal controls.
  - [x] Reconcile any implementation-driven clarifications back into the work item docs.
- Testing Tasks:
  - [x] Run the final targeted backend/UI test commands.
  - [x] Run `mix format` on touched Elixir files.
  - Command(s): `mix test test/oli_web/live/delivery/instructor test/oli_web/components/delivery`, `mix format`
- Definition of Done:
  - automated coverage and manual verification both confirm the management workflow is ready for later entry-point wiring
- Gate:
  - tests pass, formatting is clean, and docs stay aligned with final behavior
- Dependencies:
  - Phases 1 through 4
- Parallelizable Work:
  - docs reconciliation and manual QA can run while any last low-risk test adjustments land

## Parallelization Notes
- Route/helper work can start before the final UI layout is complete.
- Candidate-list state management and preview-render helper extraction are the main independent threads after mount behavior is fixed.
- Mutation flows should wait until selected-row and count-refresh state contracts are stable.

## Phase Gate Summary
- Gate A: standalone route and preview-session integration are stable.
- Gate B: Figma-aligned shell, local back contract, and paged candidate list are stable.
- Gate C: right-panel preview reuses the shared preview stack correctly.
- Gate D: remove/restore and invalid-removal warning flows are correct and user-visible.
- Gate E: targeted QA and spec reconciliation are complete.
