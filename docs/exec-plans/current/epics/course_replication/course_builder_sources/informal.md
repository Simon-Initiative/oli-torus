# Course Builder Source Selection - Informal Feature Context

Last updated: 2026-07-27

This feature updates the shared course-builder source-selection experience so instructors can discover and choose ordinary curriculum sources, their own sections for independent copy, and authorized Blueprints without confusing the resulting relationships.

## Source tickets

- `MER-5828` Course Builder UI Updates
- UI integration portions of `MER-5829` Course Builder: Selecting a blueprint
- UI integration portions of `MER-5832` Course Builder: Selecting a section to copy
- Epic context: `../informal.md`
- Parent lane plan: `../plan.md`

## Product outcome

The course builder lets an instructor quickly find an appropriate source and understand what will happen next: Blueprint selection creates a linked child, while My Course Sections selection creates an independent copy.

## Functional scope

- Improve course-card density, layout, spacing, and metadata scanability.
- Add source filters: All Sources, My Course Sections, and Blueprint Courses.
- Preserve Most Recent as the default sort and preserve a user-selected sort while filters change.
- Keep search and sorting scoped to the selected source semantics.
- Add consistent source/type tags such as Blueprint and My Section, with a final decision for Blueprint Child presentation.
- Add accessible Blueprint child-creation and independent-copy initiation actions.
- Show explanatory messaging for linked versus independent creation, permissions, editable settings, and future synchronization.
- Surface server-derived Blueprint source/owner information on the resulting child Manage experience where applicable.

## Technical guidance

Define a normalized, authorization-safe source-card/query contract consumed by all filters. Do not rely on client-side filtering to protect Blueprint names, owners, counts, or statuses. Search and sorting must not create or mutate relationships.

Keep initiation actions semantically distinct even if cards/components are shared. Blueprint cards invoke linked child creation; My Section cards invoke independent copy. The UI must not infer relationship type from visual tags alone.

All filters, sort controls, tabs, cards, and actions need keyboard operation, accessible names, selected states, and focus behavior. Hover text must have a keyboard/focus equivalent. Dynamic result updates should be announced where appropriate. Avoid duplicating relationship or authorization rules in React components.

## Out of scope

- Blueprint relationship and synchronization behavior; see `../blueprint_lifecycle/`.
- Course Copy backend semantics; see `../course_copy/`.
- Admin relationship reporting; see `../blueprint_visibility/`.

## Dependencies and handoff

- Can begin with design/component inventory immediately.
- Soft dependency on `../replication_contracts/` for source classifications, permissions, and safe queries.
- Hard dependency on `../blueprint_lifecycle/` for Blueprint eligibility, child-creation action, and relationship metadata.
- Hard dependency on `../course_copy/` for My Course Sections and copy initiation behavior.

## Verification expectations

- Query/filter tests for source membership, authorization, search, and sort preservation.
- UI tests for all source filters, card tags, actions, and explanatory messages.
- End-to-end tests distinguishing Blueprint child creation from independent Course Copy.
- Accessibility tests for keyboard-only operation, focus, selected state, hover equivalents, and dynamic result announcements.
- Regression tests for ordinary course creation and non-replication sources.

## Open decisions

- Final Blueprint Child tag/filter behavior.
- Exact card metadata and sort options.
- Whether source selection and copy/Blueprint setup are separate steps or share a modal/flow.
- Final relationship messaging and terminology.
