# Bank Selection Bulk Actions - Functional Design Document

## 1. Executive Summary
`MER-5623` extends the bank selection manager from `MER-5622` with same-state bulk selection and contextual bulk remove/restore actions. The simplest adequate design is to keep query state and checked-row state separate: the manager continues to render one active result set, while bulk actions operate only on the rows currently shown for that active query. A new atomic backend bulk operation should validate and persist the entire removal or restore set in one transaction so the LiveView does not loop through single-row mutations or allow partial outcomes.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001`, `FR-002`, `FR-003`, `FR-004` require same-state multi-select, contextual bulk actions, shown-row-only master selection, and disabled competing preview actions.
  - `FR-005` requires atomic validation and persistence for bulk removals.
  - `FR-006` requires a state model that stays compatible with future URL-param-backed server-side filters.
- Non-functional requirements:
  - preserve accessibility and keyboard behavior for the checkbox and modal flows
  - avoid N repeated mutation transactions for one bulk action
  - keep mutation rules inside `Oli.Delivery.InstructorCustomizations`
  - avoid coupling bulk semantics to a local-only in-memory filter model
- Assumptions:
  - `MER-5624` will introduce URL-param-backed query state later, but `MER-5623` only needs to prepare for that contract
  - checked candidate ids do not need to survive a full browser refresh in this work item

### 2.1 Requirements Traceability
- `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`:
  - covered by the LiveView checkbox-state model, same-state helper logic, and bulk-action toolbar rendering
- `AC-006`:
  - covered by extending the preview action contract with a disabled state while bulk selection is active
- `AC-007`, `AC-008`, `AC-009`, `AC-010`:
  - covered by a new bulk domain operation plus LiveView refresh/normalization after each completed mutation
- `AC-011`:
  - covered by keeping active-query state distinct from checked-row state so future URL-param query changes can replace the loaded result set cleanly

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex` already owns the manager route, loaded candidate rows, selected preview candidate, single-row checkbox state, preview bridge, and invalid-removal modal.
  - `Oli.Delivery.InstructorCustomizations` already exposes single-candidate remove/restore operations and the paged candidate query used by the manager.
  - the current LiveView already carries the essential source state for the active query:
    - loaded candidate rows
    - checked candidate ids
    - active count / total count / paging state
  - `MER-5624` is documented as an extension of the same manager LiveView, adding visibility filters, search, learning objective filters, question type filters, selected-filter states, and empty-state behavior.
- Unknowns to confirm:
  - whether the preview card disable treatment should be implemented purely through the preview action payload or requires a small React-side UI adjustment for explicit disabled styling

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- LiveView responsibilities:
  - continue owning the active result set (`candidates`) for the current manager query
  - continue owning `checked_candidate_ids` as ephemeral UI state for the current query result
  - derive `selection_mode` (`:none | :available | :removed`) from the currently checked rows
  - derive the selectable shown rows from `candidates + selection_mode` rather than storing redundant boolean state per row
  - render the contextual bulk action button above the table
  - normalize checked ids after any refreshed query result is loaded
- Backend responsibilities:
  - add one bulk mutation entry point under `Oli.Delivery.InstructorCustomizations`, e.g. `set_bank_candidates_enabled/6` or equivalent
  - validate target membership, active-count guardrails, and authorization once per request
  - persist the whole set atomically in one transaction
- Preview bridge responsibilities:
  - keep using the existing preview customization hook contract
  - receive a disabled/no-action state when bulk selection is active so the card cannot compete with the bulk path

### 4.2 State & Data Flow
1. The manager loads one active query result into `candidates`.
2. The user checks one row:
   - LiveView updates `checked_candidate_ids`
   - `selection_mode` becomes `:available` or `:removed`
   - shown rows with the opposite state become non-selectable
3. The user checks the master checkbox:
   - LiveView toggles only the shown rows that are selectable under the current `selection_mode`
   - hidden or unloaded rows are unaffected
4. The user clicks `Remove Selected (n)` or `Restore Selected (n)`:
   - LiveView sends the selected ids, target action, and current selection context to one bulk domain operation
5. The backend validates the whole set before writing:
   - resolve the section/page/selection target once
   - lock the page once
   - validate that every id belongs to the selection and matches the expected state
   - for remove, compute the hypothetical resulting active count before any writes, using the full selected set
   - if the hypothetical count is below the required selection count, return an insufficient-candidates error payload with plural-friendly counts and no writes
   - if valid, persist all rows together and return the refreshed exclusion view
6. The LiveView refreshes the active query result and normalizes `checked_candidate_ids` against the refreshed shown rows.
7. Later, when `MER-5624` changes the active query through URL params, the LiveView can replace `candidates` without redefining the checked-row semantics because checked ids remain separate from query state.

### 4.3 Lifecycle & Ownership
- Query lifecycle:
  - `candidates` represents the currently shown result set for the active query, not a historical accumulation of every row ever materialized in the session
  - load-more appends the next page of the same active query only
  - future URL-param filter changes should replace the query result and reset paging
- Checked-row lifecycle:
  - `checked_candidate_ids` belongs to the current query result and is not part of route state in this ticket
  - after successful mutations, invalid or no-longer-shown ids should be dropped during normalization
  - future query changes from `MER-5624` should clear checked ids by default unless a later ticket explicitly requests cross-query persistence
- Preview lifecycle:
  - single-question preview remains available for navigation and context
  - preview mutation actions are disabled while bulk selection is active

### 4.4 Alternatives Considered
- Loop through existing single-candidate mutation APIs from the LiveView:
  - rejected because it multiplies transactions and validation queries, and it creates partial-success failure modes that conflict with the required warning semantics
- Persist checked ids in URL params:
  - rejected for this work item because checked-row state is ephemeral, can become stale across query changes, and would add noisy URL semantics before there is a product requirement for shareable selection state
- Model future filtering as a local-only transform on whatever rows have already been loaded:
  - rejected because `MER-5624` is meant to help with large banks, and large-bank filtering only makes sense as a server-backed query that can repage over the full matching dataset

## 5. Interfaces
- New or updated backend interface:
  - bulk candidate toggle entry point under `Oli.Delivery.InstructorCustomizations`
  - input shape:
    - section
    - page resource id
    - selection id
    - candidate activity resource ids
    - desired enabled/disabled state
    - actor
  - output shape:
    - success: refreshed exclusion view or success tuple sufficient for LiveView refresh
    - error: invalid target, unauthorized, or insufficient candidates with counts for modal copy
- LiveView helpers:
  - `selection_mode(assigns)` derived from `checked_candidate_ids`
  - `selectable_candidates(assigns)` derived from shown rows plus `selection_mode`
  - `normalize_checked_candidate_ids(candidates, checked_ids)` refreshed after load-more and mutation results
- Future query interface compatibility:
  - reserve URL params for query state such as visibility/search/filter values
  - do not mix route params with checked-row state in this work item

## 6. Data Model & Storage
- No new tables are required.
- The backend continues to read and write `activity_exclusions`.
- The new bulk operation should use `insert_all` / `delete_all`-style set operations where appropriate instead of repeated single-row persistence calls.
- No migration is required for `MER-5623`.

## 7. Consistency & Transactions
- Bulk remove and bulk restore should each run in one transaction.
- The page row lock should be acquired once per bulk request.
- For bulk remove:
  - compute the hypothetical post-removal active candidate count from the full selected set before any writes
  - if the hypothetical count falls below the selection requirement, roll back without persisting any exclusion rows
- For bulk restore:
  - restoring multiple removed candidates can proceed atomically without the minimum-count guard because it only increases availability
- The LiveView should treat the backend response as authoritative and refresh the current query result after success.

## 8. Caching Strategy
- No new cross-request cache is required.
- The current in-memory LiveView state remains sufficient.
- N/A beyond the existing LiveView session state.

## 9. Performance & Scalability Posture
- Avoid one full target-resolution and validation stack per selected row.
- Prefer one query-backed refresh after a bulk action rather than repeated per-row refreshes.
- Keep the master checkbox constrained to the shown rows so bulk actions remain bounded by the active result page, even when the full bank is large.
- Preserve compatibility with future filtered query reloads so the manager can repage over large result sets instead of keeping an ever-growing in-memory list.

## 10. Failure Modes & Resilience
- Invalid mixed-state UI attempt:
  - prevented in the LiveView by disabling opposite-state rows and deriving selection mode from checked ids
- Stale checked ids after mutation or load-more:
  - handled by normalizing checked ids against the refreshed shown rows
- Blocked bulk remove:
  - backend returns insufficient-candidates payload
  - LiveView opens the invalid-removal modal with singular or plural copy and performs no writes
- Preview action race while bulk selection is active:
  - prevented by disabling preview mutation actions during bulk selection

## 11. Observability
- Reuse existing LiveView error reporting for failed event handlers.
- Log unexpected bulk validation or persistence failures through the standard Elixir/Phoenix logging path.
- No new analytics events are required for this work item.

## 12. Security & Privacy
- Bulk operations must pass the current actor to `Oli.Delivery.InstructorCustomizations` just like single-row actions.
- Authorization remains server-side.
- The manager must not expose or persist checked-row UI state beyond the current authorized session.

## 13. Testing Strategy
- LiveView tests:
  - `AC-001` through `AC-006` for checkbox state, master-checkbox behavior, CTA rendering, and disabled preview actions
  - `AC-009`, `AC-010`, `AC-011` for modal behavior, normalization, and state-model boundaries
- Elixir tests:
  - `AC-007`, `AC-008`, `AC-009` for the bulk domain operation, atomic validation, and persistence behavior
- Regression tests:
  - verify that load-more still works with checked-row normalization
  - verify that the active query result can be refreshed cleanly without assuming local-only filters

## 14. Backwards Compatibility
- The existing manager route and preview behavior remain intact.
- Single-row remove/restore remains available when there is no active bulk selection.
- No learner-facing or authoring-facing behavior changes.

## 15. Risks & Mitigations
- Risk: backend bulk APIs drift from the existing single-row semantics. Mitigation: implement bulk behavior in the same domain context and reuse the same target validation rules.
- Risk: future URL-param filters require reworking checkbox logic. Mitigation: keep query state and checked-row state separate from the start.
- Risk: the preview card disable treatment is visually inconsistent. Mitigation: keep the disable rule in the preview action contract and verify it against the approved Figma node during UI implementation.

## 16. Open Questions & Follow-ups
- Confirm whether preserving valid checked rows after a successful bulk action provides better UX than clearing them all; default recommendation is to normalize and keep only still-valid shown ids.
- `MER-5624` should own the actual URL-param query contract and the decision to clear checked ids on query changes, but it should not need to redefine the bulk-action semantics from this slice.

## 17. References
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`
- `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager/fdd.md`
