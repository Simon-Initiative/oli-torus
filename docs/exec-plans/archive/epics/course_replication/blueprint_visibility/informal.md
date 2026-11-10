# Blueprint Visibility and Administration - Informal Feature Context

Last updated: 2026-07-27

This feature exposes Blueprint relationships safely and consistently after the underlying lifecycle and relationship contracts exist.

## Source tickets

- `MER-5827` Blueprints: View linked sections
- `MER-5830` Blueprints: Admin records
- Epic context: `../informal.md`
- Parent lane plan: `../plan.md`

## Product outcome

Blueprint owners and administrators can understand where a Blueprint is used, while users only see relationship information and actions allowed by their permissions. Admin course lists consistently distinguish Blueprint Courses, Blueprint Child Courses, and ordinary sections.

## Functional scope

- Display the current number of active linked child sections for a Blueprint.
- Provide a View All action when linked children exist.
- Display linked children in a semantic table.
- Give administrators links to child Manage pages where authorized.
- Give instructors a view-only relationship view; do not make inaccessible child names navigable.
- Exclude unlinked, deleted, or otherwise inactive children from current counts and rows.
- Add consistent text-based Blueprint and Blueprint Child indicators to Project Overview and Template Usage.
- Add Blueprint indicators and filtering to Browse All Course Sections.
- Preserve existing permissions and course functionality while filtering.

## Technical guidance

Use one authorization-filtered relationship query contract for both counts and rows. Apply institution and role checks before returning metadata, not only before generating links. Avoid N+1 authorization/status queries and add bounded loading or pagination for large Blueprints.

Candidate table fields are child title, institution, instructor, last synchronized time, and synchronization status. Align the final columns with Browse All Course Sections. Keep historical audit data even when a child is unlinked, but exclude inactive relationships from current views.

Use shared relationship classification and presentation metadata across all admin surfaces. Tags must communicate meaning through text and accessible semantics rather than color alone.

## Out of scope

- Blueprint enablement, synchronization, or unlink mutation behavior; see `../blueprint_lifecycle/`.
- Course-builder source selection; see `../course_builder_sources/`.

## Dependencies and handoff

- Hard dependency on `../replication_contracts/` and `../blueprint_lifecycle/`.
- Provides relationship/status queries and shared labels to `../course_builder_sources/` where applicable.

## Verification expectations

- Count/table parity tests for linked, unlinked, deleted, and unauthorized children.
- Admin versus instructor link and visibility tests.
- Regression tests for ordinary non-Blueprint sections.
- UI tests for Project Overview, Template Usage, Browse All Course Sections, tags, and filters.
- Accessibility tests for semantic tables, keyboard operation, selected filter state, and dynamic result announcements.

## Open decisions

- Whether Blueprint Child needs a separate admin filter/source row.
- Final linked-table columns and synchronization-status vocabulary.
- Whether instructors may see limited metadata for children they cannot access.
