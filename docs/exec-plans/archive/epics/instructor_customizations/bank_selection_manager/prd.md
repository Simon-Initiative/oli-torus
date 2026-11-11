# Bank Selection Manager - Product Requirements Document

## 1. Overview
`MER-5622` introduces a dedicated Instructor View management surface for one activity bank selection on one basic page. The work item delivers a standalone LiveView where instructors can browse candidate questions, inspect the selected question through the existing preview rendering contract, remove or restore candidates for that selection, and handle invalid-removal warnings without mutating authored content.

## 2. Background & Problem Statement
The delivery-side customization backend now supports section- and page-specific exclusion of individual candidates inside an activity bank selection. What is still missing is the instructor-facing workspace for using that capability. The legacy bank preview controller is read-only, controller-rendered, and structurally different from the newer Instructor View shell. Jira for `MER-5622` expects a secondary Instructor View workflow with its own local back behavior, selection-scoped question management, dynamic preview, removed-state affordances, and minimum-count protection. Without a dedicated management LiveView, preview routing would need to either resurrect the old controller preview or embed complex selection-management logic into the page shell instead of reusing a dedicated workflow.

## 3. Goals & Non-Goals
### Goals
- Deliver a standalone Instructor View LiveView route for managing one bank selection on one preview page.
- Preserve the global Instructor View header and return context while adding a local back-to-page action for the manager.
- Show current active-question count, selection criteria summary, candidate list state, and a dynamic preview panel.
- Allow remove and restore actions for selection candidates using the existing delivery customization context.
- Prevent invalid candidate removal through an explicit warning workflow when the selection would fall below its required count.
- Reuse the existing preview rendering contract for the right-hand question preview instead of inventing a separate rendering stack.

### Non-Goals
- Rendering the `Manage Questions` CTA inside `PreviewLessonLive`.
- Wiring navigation from the page-level bank-selection card into this LiveView.
- Implementing multi-select or bulk actions from `MER-5623`.
- Implementing search, learning-objective filters, or question-type filters from `MER-5624`.
- Reworking page-level embedded-question and whole-selection controls that belong to `MER-5620`.
- Changing learner delivery, authored resources, or historical attempts.

## 4. Users & Use Cases
- Instructor: opens a bank-selection manager for one page selection, reviews which candidate questions are currently available, and removes or restores individual questions to fit section needs.
- Author or admin in preview mode: reviews the same management workflow without changing authored source content.
- Engineering team: uses the standalone selection-manager route and its `bank_candidate` target usage as the destination consumed by preview-page workflows.

## 5. UX / UI Requirements
- The management surface must follow the approved Figma nodes:
  - manager view: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7391`
  - minimum-count warning modal: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-15926`
- The surface must render inside the reusable Instructor View shell so the persistent header and origin-specific return label remain visible.
- A local back control must return to the originating preview page location rather than duplicating the persistent header exit action.
- The page body must include:
  - bank-selection title/header
  - active available-question count
  - selection criteria summary
  - left-side candidate table/list
  - right-side question preview panel
- Candidate rows must show a removed state with muted styling and a `Removed` pill when excluded for that selection.
- Candidate actions must be mutually exclusive:
  - active candidates show `Remove`
  - removed candidates show `Restore`
- The minimum-count warning modal must explain the required count and resulting remaining count using live selection data.
- When the user confirms `Remove bank` from the minimum-count warning modal, the manager must disable the whole selection and immediately navigate back to the originating preview page context.
- Successful changes must show positive user feedback after auto-save actions complete.
- Filter/search controls visible in the Figma node are future-ticket context only and should not become functional scope in this work item.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: local back, row selection, remove/restore controls, and warning-modal actions must be keyboard accessible, expose visible focus states, and provide accessible labels.
- Reliability: remove/restore actions must auto-save through the delivery customization context and leave the active-question count consistent with persisted state.
- Security and authorization: only preview-authorized instructor/admin users may access the management route or perform selection-candidate mutations.
- Performance: candidate browsing must avoid loading the entire matching bank into the LiveView process at once; the list should load incrementally from the existing paged candidate query.
- Compatibility: the work item must not require bank-selection rendering in `PreviewLessonLive` to exist yet, and it must not regress the existing preview shell or legacy bank-preview controller while both coexist.

## 9. Data, Interfaces & Dependencies
- Depends on `MER-5639` and its delivery-owned `Oli.Delivery.InstructorCustomizations` APIs for listing candidates, excluding/restoring candidates, and excluding the whole bank selection.
- Depends on `MER-5617` for the reusable Instructor View shell/header contract and local-vs-global back semantics.
- Depends on `MER-5618` for preview-mode activity rendering that can be reused in the right-hand question preview.
- Assumes `MER-5620` will add the page-preview `Manage Questions` launch path into this route later while keeping page-level bank-selection behavior outside this work item's scope.
- Reuses the existing preview route inputs:
  - `section_slug`
  - page `revision_slug`
  - `selection_id`
  - safe `return_to` / `request_path` preview context
- May need a small server-side preview helper to render one candidate question through the same preview component pipeline already used in Instructor View.

## 10. Repository & Platform Considerations
- The implementation surface is primarily `liveview/heex`, with server-rendered preview HTML and existing browser hooks used to hydrate preview custom elements.
- Domain rules must stay in `Oli.Delivery.InstructorCustomizations`; the new LiveView should orchestrate UI state only.
- LiveView is the source of truth for each candidate's enabled/removed state.
- The right-hand preview uses the already-established preview action contract to emit `Remove` / `Restore` intents for `bank_candidate` targets back to the LiveView.
- The new route should live under the existing preview LiveView session so preview-mode assigns and the global return context are reused.
- LiveView tests are the primary automated test layer for route access, local navigation behavior, UI state transitions, and warning-modal flows.
- Targeted ExUnit tests should cover any new preview helper that assembles candidate preview HTML from the existing rendering pipeline.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Operational success is primarily workflow correctness:
  - preview-authorized users can open the management surface directly
  - remove/restore actions persist and update the count correctly
  - invalid removals trigger the warning modal instead of silently persisting
- Existing logs and AppSignal coverage should remain sufficient for route/render failures and mutation errors.

## 13. Risks & Mitigations
- Sequencing risk with adjacent preview work: keep page-level bank-selection behavior out of scope and document the manager route expectations explicitly so this LiveView stays focused on candidate management.
- Preview-stack duplication risk: reuse the existing preview rendering contract for the right panel instead of introducing a separate bespoke question preview implementation.
- Large-bank memory risk: use incremental paging/endless-load behavior backed by the existing paged candidate query rather than loading all candidates into assigns.
- Return-navigation confusion: preserve the separation between the persistent Instructor View header exit and the local back-to-page action in both docs and tests.
- Warning-flow drift: align the invalid-removal modal copy and action structure to the approved Figma node rather than reusing unrelated legacy modals.

## 14. Open Questions & Assumptions
### Open Questions
- Should the attempts-started warning reuse an already-shared warning contract by the time implementation begins, or does this work item need to own the first LiveView integration of that warning pattern for selection-candidate actions?

### Assumptions
- The legacy controller-backed bank preview may remain in the repo temporarily while the new management LiveView lands.
- The right-hand preview panel can rely on the preview-mode activity contract from `MER-5618` and does not need to invent new browser-side rendering elements.
- Candidate list filters shown in Figma are explicitly deferred to later tickets and should not block the initial manager implementation.

## 15. QA Plan
- Automated validation:
  - LiveView tests for authorization, route rendering, local back behavior, row selection, remove/restore, and minimum-count warning flows
  - targeted Elixir tests for any new candidate-preview rendering helper and route helper functions
  - targeted tests proving incremental candidate loading preserves row state and selected-preview behavior
- Manual validation:
  - open the route directly for a valid preview section/page/selection and compare to the approved Figma nodes
  - verify local back returns to the originating page anchor/location contract
  - verify removed rows show muted styling and `Removed` pill
  - verify invalid removals surface the warning modal with correct dynamic counts and copy
  - verify successful remove/restore actions show success feedback and update the visible count immediately

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
