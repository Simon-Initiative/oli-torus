# Bank Selection Manager - Functional Design Document

## 1. Executive Summary
`MER-5622` adds a new preview-session LiveView dedicated to one activity bank selection. The LiveView reuses the Instructor View shell and return context from `MER-5617`, the preview rendering contract from `MER-5618`, and the delivery-side customization APIs from `MER-5639`. It focuses on the manager route, local back contract, candidate-list paging behavior, right-hand preview rendering, and warning flows for candidate management. The simplest adequate design is a server-driven LiveView with a paged candidate list and a single selected-candidate preview, not a new React app or a reuse of the legacy controller preview.

## 2. Requirements & Assumptions
- Functional requirements:
  - provide a standalone preview-session LiveView route for one page selection
  - preserve the persistent Instructor View header while introducing local back-to-page behavior
  - list bank candidates with active/removed state, dynamic active count, and incremental loading
  - preview the selected candidate using the existing preview activity pipeline
  - remove and restore candidates through `Oli.Delivery.InstructorCustomizations`
  - block invalid removals with a dynamic warning modal and provide a whole-bank removal path from that modal
- Non-functional requirements:
  - keep authorization server-side and preview-context-safe
  - avoid loading the entire candidate bank in one request
  - keep state ownership in LiveView/UI, not in domain contexts
  - preserve accessibility semantics for table-like row selection and warning modal interaction
- Assumptions:
  - `MER-5618` preview rendering is available for the right-hand panel by the time this work is implemented

### 2.1 Requirements Traceability
- `AC-001`, `AC-002`:
  - covered by the new preview-session LiveView route, server-side authorization, and preview-context sanitation
- `AC-003`, `AC-004`:
  - covered by reuse of the shared Instructor View header plus a separate local back target contract
- `AC-005`, `AC-006`, `AC-007`:
  - covered by paged candidate loading, row-state mapping from `list_bank_selection_candidates/4`, and incremental append/reset behavior
- `AC-008`:
  - covered by candidate selection state and right-panel preview rendering through the preview activity pipeline
- `AC-009`, `AC-010`:
  - covered by LiveView mutation events calling `exclude_bank_candidate/5` and `restore_bank_candidate/5` with refreshed candidate state
- `AC-011`, `AC-012`:
  - covered by explicit invalid-removal modal state and a whole-bank removal event that calls `exclude_bank_selection/4`
- `AC-013`:
  - covered by LiveView flash feedback after successful remove, restore, and whole-bank removal actions

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex` already establishes preview-mode shell behavior, safe `return_to` handling, and local preview back-link semantics for page preview surfaces.
  - `lib/oli_web/components/delivery/layouts.ex` already provides the reusable `instructor_preview_header/1` and shared delivery header used in preview mode.
  - `lib/oli/delivery/instructor_customizations.ex` already exposes:
    - `list_bank_selection_candidates/4`
    - `get_selection_exclusion_view/3`
    - `exclude_bank_candidate/5`
    - `restore_bank_candidate/5`
    - `exclude_bank_selection/4`
  - the candidate listing API already returns paged rows, active count semantics through `disable_allowed?`, and selection-enabled state.
  - `OliWeb.Components.Delivery.ActivityHelpers.preview_render/6` and `OliWeb.ManualGrading.RenderedActivity.render/1` already provide a practical server-side path for rendering one activity preview with the same browser hooks used elsewhere.
  - the old `ActivityBankController` preview route is controller-rendered and not aligned to the reusable Instructor View shell.
- Unknowns to confirm:
  - whether attempts-started warning logic already exists as a reusable contract by the time implementation begins

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- New LiveView:
  - add `OliWeb.Delivery.Instructor.BankSelectionManagerLive`
  - mount under the existing preview live session at a route like `/sections/:section_slug/preview/lesson/:revision_slug/selection/:selection_id`
  - own UI state:
    - current candidate page(s)
    - selected candidate id
    - selected preview HTML
    - current active candidate count
    - local back target
    - modal/warning state
- Preview route helpers:
  - extend `OliWeb.Delivery.Instructor.PreviewRoutes` with a dedicated selection-manager path helper
  - preserve `return_to` and `request_path` sanitation rules already used by preview lesson routes
- Preview shell reuse:
  - render `Layouts.instructor_preview_header/1` for the global return action
  - render the shared delivery header below it
  - implement a manager-local back control that targets the originating preview page/anchor contract
- Candidate preview helper:
  - add a small server-side helper module or function near the instructor preview boundary that:
    - resolves one candidate revision
    - computes its ordinal/preview metadata conservatively
    - calls `ActivityHelpers.preview_render/6`
  - this keeps browser-side preview hydration identical to the existing preview activity path
- Preview-route target resolution:
  - prefer a dedicated `InstructorCustomizations` entry point for `(section, revision_slug, selection_id)` so mount can resolve page type and selection membership in one step instead of splitting that logic across the LiveView
  - the public context boundary may delegate internally to `TargetResolver`, but web callers should stay coupled to `InstructorCustomizations`
- Warning modal:
  - use the shared modal component under `lib/oli_web/components/modal.ex`
  - store modal state in assigns with dynamic copy derived from the insufficient-candidates error payload

### 4.2 State & Data Flow
1. Mount resolves:
   - section and page revision through existing preview session assigns
   - safe preview navigation params (`return_to`, `request_path`)
   - selection target validity through mount-time route resolution
2. Initial assigns include:
   - first candidate page
   - active available count derived from the loaded rows and exclusion view or directly from context response
   - selected candidate defaulting to the first visible candidate
   - preview HTML for that selected candidate
3. User selects a candidate row:
   - LiveView updates `selected_candidate_id`
   - LiveView re-renders right-panel preview HTML for that candidate
4. User clicks `Remove` from the right-hand preview:
   - if row `disable_allowed?` is true, call `exclude_bank_candidate/5`
   - on success, refresh visible candidate state and active count, keep selection stable where possible, and show success flash
   - if the context returns `{:insufficient_selection_candidates, %{...}}`, open warning modal instead of persisting
5. User clicks `Restore` from the right-hand preview:
   - call `restore_bank_candidate/5`
   - refresh visible state/count and show success flash
6. User confirms `Remove bank` from the modal:
   - call `exclude_bank_selection/4`
   - on success, navigate back to the originating preview page context instead of leaving the user on a disabled manager surface
7. User scrolls or clicks load-more trigger:
   - LiveView requests the next page via `list_bank_selection_candidates/4`
   - once mount has already resolved `%Section{}`, `%Revision{}`, and the selection map, the LiveView should use the resolved-target function head to avoid repeating page/selection resolution queries on each load
   - append rows while preserving current removed/selected state

### 4.3 Lifecycle & Ownership
- Backend ownership:
  - selection validation, authorization, remove/restore persistence, and count rule enforcement remain in `Oli.Delivery.InstructorCustomizations`
- LiveView ownership:
  - route params, local back contract, selected-row state, preview HTML caching, load-more behavior, flash messages, and warning-modal orchestration
  - post-success redirect back to the originating preview page after whole-bank removal from the invalid-removal modal
  - authoritative enabled/removed state for each candidate row
- Browser-hook ownership:
  - existing preview custom-element hydration and MathJax/survey helper hooks remain responsible for rendering the preview HTML once inserted
- React preview-component ownership:
  - preview components remain primarily presentational even when they surface customization controls
  - preview components should not infer mutation behavior from activity type, route, or preview mode branches
  - the right-hand preview emits `Remove` / `Restore` intents through the already-established preview action contract and updates local preview state from the LiveView reply
- Future-ticket ownership:
  - `MER-5620` owns wiring a page-level `Manage Questions` link into this surface
  - `MER-5623` and `MER-5624` extend this LiveView with bulk actions and filtering rather than replacing it

### 4.4 Alternatives Considered
- Reuse `ActivityBankController` and restyle it:
  - rejected because it is controller-owned, uses the old layout, and would duplicate newer preview-session shell logic
- Build a React app mounted inside preview:
  - rejected because the workflow is primarily server-driven, depends on preview-session routing/authorization, and benefits from reusing existing LiveView shell/navigation patterns
- Render previews by manually composing activity-specific HTML:
  - rejected because it would fork the preview rendering contract from `MER-5618` and create a second activity-preview stack
- Load all candidates eagerly:
  - rejected because the candidate list API is already paged and the ticket explicitly calls for endless scroll behavior

## 5. Interfaces
- New route helper:
  - `PreviewRoutes.selection_path(section_slug, revision_slug, selection_id, params \\ [])`
- New LiveView events:
  - `"select_candidate"` with `%{"activity_resource_id" => id}`
  - `"load_more_candidates"` with paging cursor/offset
  - `"confirm_remove_bank"`
  - `"dismiss_invalid_remove_warning"`
- Established preview customization integration:
  - assume the preceding preview-page work already establishes the shared React <-> LiveView communication pattern for preview actions
  - this feature should reuse that integration rather than redefining transport, reply handling, hook behavior, or local preview-component state rules
  - in this work item, the right-hand preview is the primary UI surface that issues `Remove` / `Restore`
  - this LiveView only needs to supply the `bank_candidate` target for those preview-driven actions
  - the left candidate list is selection/navigation and state-reflection UI in this work item, not a bulk-mutation surface
- LiveView dispatch expectation for preview-action events:
  - when the incoming action targets `bank_candidate`, the handler should dispatch:
    - `Remove` -> `exclude_bank_candidate/5`
    - `Restore` -> `restore_bank_candidate/5`
  - whole-bank removal remains a manager-owned modal action and should dispatch `exclude_bank_selection/4`
- View model shape:
  - row entries should preserve:
    - `activity_resource_id`
    - `revision_slug`
    - `title`
    - `enabled?`
    - `disable_allowed?`
  - plus local UI-derived flags:
    - `selected?`
    - `preview_loaded?`
- Optional helper interface:
  - `render_selection_candidate_preview(section, page_revision, candidate_revision, opts \\ []) :: {:ok, rendered_html} | {:error, reason}`
- Candidate-listing efficiency contract:
  - `list_bank_selection_candidates/4` should support both:
    - `(section_or_id, page_resource_id, selection_id, opts)` for general callers
    - `(%Section{}, %Revision{}, selection_map, opts)` for already resolved preview-session callers
  - the manager LiveView should prefer the resolved-target head after mount so paging and refresh flows do not repeat target-resolution queries unnecessarily

## 6. Data Model & Storage
- No new database tables or schema changes are required.
- The LiveView reads and writes through the existing `activity_exclusions` storage owned by `Oli.Delivery.InstructorCustomizations`.
- In-memory LiveView state adds:
  - loaded candidate pages
  - selected candidate id
  - rendered preview cache for visible candidates if needed for performance
  - modal state for invalid removal

## 7. Consistency & Transactions
- Remove/restore and whole-bank disable operations rely on the existing transaction and locking guarantees already implemented in `Oli.Delivery.InstructorCustomizations`.
- The LiveView should treat context responses as authoritative and refresh visible state from the returned view/list response rather than applying optimistic client-only diffs.
- When a loaded page becomes stale after a mutation, the LiveView should recompute visible row state from fresh context data before rendering.

## 8. Caching Strategy
- No new cross-request cache is required.
- It is acceptable to keep an in-memory preview HTML cache for currently visible candidates during one LiveView session to avoid rerendering the same selected candidate repeatedly.
- Cache entries should be invalidated when the selected visible row set changes materially or when the session reloads.

## 9. Performance & Scalability Posture
- Use the existing paged candidate query with the default limit as the initial page size.
- Implement endless loading by requesting subsequent pages, not by increasing limit unboundedly.
- Keep only the visible/loaded candidate subset in assigns instead of the entire matching bank.
- Avoid repeated DB queries for the same preview when the selected candidate has not changed.

## 10. Failure Modes & Resilience
- Unauthorized access:
  - route should deny access consistently with existing preview authorization
- Invalid selection/page route:
  - LiveView should render a not-found or redirect-safe fallback rather than crashing
- Preview rendering failure for one candidate:
  - show a bounded error state in the right panel while keeping the candidate list usable
- Remove action races with external changes:
  - rely on context-level validation and show the returned error/warning state instead of persisting stale assumptions
- Direct route used outside the normal page-preview path:
  - acceptable; the route remains functional for direct/manual navigation

## 11. Observability
- Log or surface unexpected preview-render failures for candidate right-panel rendering.
- Reuse existing AppSignal/LiveView error reporting for route and event failures.
- No new product analytics are required; this is a preview customization workflow, not a learner flow.

## 12. Security & Privacy
- All mutations must pass the current preview actor into `Oli.Delivery.InstructorCustomizations` so authorization remains server-side.
- Route parameters must continue to use safe internal-path sanitation for preview return context.
- Candidate preview payloads must contain only preview-safe instructional content and must not expose learner attempt data.

## 13. Testing Strategy
- LiveView tests:
  - route render and authorization
  - local back contract
  - default selected candidate and preview update on row selection
  - remove/restore success flows and flash messages
  - invalid-removal modal flow and whole-bank removal path
  - incremental loading behavior and state preservation across appended pages
- Elixir tests:
  - preview route helper coverage
  - candidate preview helper coverage
  - any presenter functions for count/state shaping
- Manual QA:
  - compare manager view and warning modal against Figma
  - confirm keyboard operation and focus handling across rows/actions/modal

## 14. Backwards Compatibility
- The existing controller-backed bank preview route may remain temporarily; this work item does not need to delete it.
- No authored content, publication, or learner delivery behavior changes.
- Preview page shell behavior outside candidate management remains unchanged by this work item.

## 15. Risks & Mitigations
- Route-level integration depends on adjacent preview work; keep the manager focused on candidate management and its route/helper contract stable.
- Preview helper drifts from `MER-5618` rendering: mitigate by routing all right-panel rendering through the shared preview helper path.
- Endless-load UX becomes brittle in LiveView: start with deterministic paged append behavior and explicit tests around selection/state retention.
- Whole-bank remove outcome ambiguity: document the unresolved navigation choice and finalize it before implementation.
 - Whole-bank remove redirect could drop success visibility if not handled carefully: carry success feedback through the redirect target using standard flash behavior.

## 16. Open Questions & Follow-ups
- Confirm whether attempts-started warning support should be part of this work item or treated as an inbound shared-warning dependency when implementation begins.
- Align `MER-5620` documentation to the same server-authored preview-action contract so page preview and bank-selection management do not diverge into separate React event models.
- `MER-5620` will wire the `Manage Questions` CTA from the page-level bank-selection card into this route.
- `MER-5623` remains the place for any same-state multi-select or bulk remove/restore behavior from the left candidate list.

## 17. References
- `docs/exec-plans/current/epics/instructor_customizations/overview.md`
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`
- `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`
- Jira `MER-5622`
- Figma manager node `185:7391`
- Figma warning modal node `185:15926`
