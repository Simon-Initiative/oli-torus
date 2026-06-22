# Bank Selection Bulk Actions - Product Requirements Document

## 1. Overview
`MER-5623` extends the activity bank selection manager so instructors can select multiple questions in the current manager query and remove or restore them in one action. The work adds same-state bulk selection, contextual bulk remove/restore controls, warning behavior for invalid bulk removals, and UI state rules that remain compatible with the future filtering work in `MER-5624`.

## 2. Background & Problem Statement
`MER-5622` delivered the standalone manager route, candidate list, right-hand preview, and single-question remove/restore behavior for one activity bank selection. That workflow becomes repetitive and inefficient for large banks because instructors must toggle candidates one by one. Jira for `MER-5623` asks for faster bulk management while preserving the existing selection-count guardrails, preview shell behavior, and selection-specific customization semantics. The design also needs to avoid boxing `MER-5624` into a local-only filtering model; large banks should continue to behave as query-backed lists rather than a one-time in-memory snapshot.

## 3. Goals & Non-Goals
### Goals
- Allow instructors to select multiple currently listed questions and apply one bulk remove or bulk restore action.
- Enforce same-state bulk selection so available and removed questions cannot be selected together.
- Make the header checkbox operate on the currently shown rows for the active query only.
- Preserve the selection-count guardrail by validating the full bulk removal set before any persistence occurs.
- Reuse the existing invalid-removal modal pattern, with pluralized copy when the blocked action targets multiple questions.
- Keep the manager implementation compatible with future server-side filters and URL-param-driven query state from `MER-5624`.

### Non-Goals
- Implementing the filter toolbar, search, learning-objective filters, question-type filters, or empty-state variants from `MER-5624`.
- Persisting checkbox selection state in URL params.
- Applying bulk actions across rows that are not currently shown in the active manager query.
- Changing learner delivery, authored resources, publications, or historical attempts.
- Introducing a page-level launch-path change outside the existing bank selection manager route.

## 4. Users & Use Cases
- Instructor: selects several available questions in the manager list and removes them together to narrow the pool for one section page.
- Instructor: selects several removed questions in the manager list and restores them together after reconsidering prior exclusions.
- Instructor or admin in preview mode: sees clear disabled-state affordances when the current selection mode prevents mixing available and removed rows.
- Engineering team: uses this feature slice to define the selection-state model that later filtering work will extend through URL-param-backed query changes.

## 5. UX / UI Requirements
- The management surface must follow the approved Figma nodes:
  - bulk-selection manager view: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7595`
  - invalid-removal modal baseline: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-15926`
- Candidate rows continue to show one checkbox per row plus one master checkbox in the header.
- All checkboxes load deselected by default.
- When one or more available questions are selected:
  - available rows remain selectable
  - removed-row checkboxes become disabled
  - removed rows appear visually muted
  - the manager shows a `Remove Selected (n)` control above the table
- When one or more removed questions are selected:
  - removed rows remain selectable
  - available-row checkboxes become disabled
  - available rows appear visually muted
  - the manager shows a `Restore Selected (n)` control above the table
- The right-hand preview must disable its single-question remove/restore control while a bulk selection is active so competing mutation paths are not shown together.
- The master checkbox must affect only the rows currently shown by the active manager query.
- If a bulk removal would leave fewer active questions than the selection count, the manager must show the invalid-removal modal with singular or plural copy matching the attempted action.
- The future filter toolbar should be able to bind to URL params without requiring a redesign of the bulk-action controls or checkbox-state model.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: row checkboxes, the master checkbox, the bulk action control, disabled states, and the invalid-removal modal must remain keyboard accessible with visible focus states and accessible labels.
- Reliability: bulk actions must be atomic. A blocked bulk removal must not partially persist candidate exclusions.
- Performance: the backend should avoid N round-trip mutation flows for N selected rows when one bulk domain operation can validate and persist the whole set.
- Compatibility: the implementation must preserve the current manager route contract and leave room for future URL-param-backed filtering without forcing a state-model rewrite.
- Security and authorization: only preview-authorized instructor/admin users may perform bulk candidate mutations, using the same delivery customization boundary as single-question actions.

## 9. Data, Interfaces & Dependencies
- Depends on `MER-5622` for the bank selection manager LiveView, preview bridge, and current warning-modal flow.
- Depends on `MER-5639` for delivery-owned exclusion storage and selection-specific candidate mutation semantics.
- Likely requires a new bulk backend entry point in `Oli.Delivery.InstructorCustomizations` so one request can validate and persist multiple candidate toggles atomically.
- The manager should continue to treat the visible rows as the result set for the current query, not as a historical accumulation of every candidate ever loaded during the session.
- Future filtering work should be able to express the active query through URL params such as visibility/search/filter choices, with checkbox selections remaining LiveView state only.

## 10. Repository & Platform Considerations
- The implementation surface remains primarily `liveview/heex` plus delivery-domain context work in Elixir.
- The LiveView should keep only source state that is needed for the active query and the current checked set; derived selection mode and selectable-row state should come from helpers rather than duplicated assigns.
- Bulk validation and persistence rules must live in `Oli.Delivery.InstructorCustomizations`, not in the LiveView.
- LiveView tests remain the primary automated layer for UI state transitions, while targeted ExUnit tests should cover the new bulk domain operation.
- The route should stay compatible with future `handle_params`-driven filters so refreshed pages can reconstruct the active query from URL params later.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Operational success is primarily correctness and workflow efficiency:
  - bulk remove/restore actions succeed without requiring repeated single-row actions
  - blocked bulk removals show the modal instead of partially mutating state
  - manager state remains consistent after remove, restore, load-more, and later URL-param query changes
- Existing logs and AppSignal coverage should remain sufficient for unexpected LiveView event failures and domain mutation errors.

## 13. Risks & Mitigations
- Risk: implementing bulk actions as repeated single-row mutations creates avoidable query volume and partial-failure edge cases. Mitigation: add one atomic backend bulk operation that validates and persists the whole set.
- Risk: baking selection logic into a local-only loaded-row model makes `MER-5624` harder. Mitigation: define the active list as the current query result and keep query state separate from checked-row state.
- Risk: plural warning behavior drifts from the existing invalid-removal pattern. Mitigation: reuse the current modal structure and limit the change to dynamic singular/plural copy plus bulk-action wiring.
- Risk: checkbox selections become stale after mutations. Mitigation: normalize checked ids against the refreshed active query after each successful mutation and clear invalid entries.

## 14. Open Questions & Assumptions
### Open Questions
- Should a successful bulk action clear all checked rows unconditionally, or preserve only rows that remain valid and visible after the refreshed query result is loaded?

### Assumptions
- The future filter implementation will own URL params for query state, but `MER-5623` does not need to persist checked candidate ids across a full page refresh.
- The manager list should continue to support load-more pagination within the current query, and the master checkbox should operate only on the rows currently shown.
- The preview bridge can be extended to expose a disabled state for single-question actions during bulk selection without redesigning the preview transport contract.

## 15. QA Plan
- Automated validation:
  - LiveView tests for same-state row selection, master-checkbox behavior on shown rows, contextual bulk action rendering, disabled preview action state, and plural invalid-removal modal behavior
  - targeted Elixir tests for the new bulk domain operation, including atomic validation and persistence outcomes
  - regression tests proving load-more and refreshed query results normalize checked rows safely
- Manual validation:
  - compare the bulk-selection state transitions against the approved Figma node
  - verify the header checkbox never selects hidden or unloaded questions
  - verify that blocked bulk removals open the warning modal with pluralized copy and do not partially persist
  - verify that single-question preview actions disable while a bulk selection is active

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
