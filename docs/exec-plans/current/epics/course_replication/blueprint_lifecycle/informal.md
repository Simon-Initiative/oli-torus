# Blueprint Lifecycle and Synchronization - Informal Feature Context

Last updated: 2026-07-27

This feature delivers the linked Blueprint Course workflow: making a section a Blueprint, granting access, creating linked child sections, propagating source changes, locking source-controlled settings, and disabling or unlinking the relationship.

## Source tickets

- `MER-5825` Course Blueprints: Rules
- `MER-5826` Enabling Course Blueprints
- `MER-5829` Course Builder: Selecting a blueprint (child-creation behavior)
- Epic context: `../informal.md`
- Parent lane plan: `../plan.md`

## Product outcome

An authorized instructor or administrator can maintain a reusable course foundation while child instructors customize section-specific settings. Blueprint updates flow to linked children without overwriting child-owned settings or learner data.

## Functional scope

- Enable an existing course section as a Blueprint.
- Make the Blueprint discoverable only to users with access.
- Support instructor grants within the instructor's institution or to direct delivery emails.
- Support admin grants by institution, direct delivery, or platform-wide access as permitted by the final authorization model.
- Create a new child section from an authorized Blueprint through course setup.
- Persist the source/child relationship and the baseline/version used for initial and later synchronization.
- Propagate Blueprint-controlled content, notes, discussions, AI recommendations, and cover image according to the final attribute contract.
- Keep temporal settings, assessment settings, and section details child-editable.
- Show locked-state UI and enforce locked writes server-side.
- Keep Blueprint owner/source information visible on the child Manage page.
- Disable a Blueprint with explicit impact confirmation and an option to unlink children.
- Stop updates for unlinked children and expose clear child status messaging.

## Technical guidance

Child creation must be transactional: section creation, initial snapshot, and relationship creation either succeed together or leave no partial relationship. Recheck access at submission time, not only when the course-builder list was rendered.

Synchronization should be ordered, idempotent, retryable, and observable. Preserve child-owned settings and exclude enrollments, rosters, attempts, progress, grades, submissions, discussions, analytics, and all other learner-generated data. Define behavior for unpublished revisions, publications, deployments, stale children, deleted children, disabled sources, and failed updates before implementation.

Keep relationship and authorization behavior behind focused contexts/services. UI components should consume server-derived relationship state and should not implement propagation or permission rules themselves.

## Out of scope

- Independent Course Copy behavior; see `../course_copy/`.
- Linked-child table/count presentation; see `../blueprint_visibility/`.
- Shared course-builder filtering and card layout; see `../course_builder_sources/`.

## Dependencies and handoff

- Hard dependency on `../replication_contracts/`.
- `../blueprint_visibility/` consumes source/child state, unlink state, counts, and authorization-safe queries.
- `../course_builder_sources/` consumes Blueprint eligibility, metadata, and child-creation actions.

## Verification expectations

- Enable/disable and access authorization tests.
- Child creation and initial-sync integration tests.
- Propagation tests proving locked fields update and child-owned fields do not.
- Negative tests proving learner data never propagates.
- Unlink, retry, stale-source, deletion, and failed-sync tests.
- End-to-end instructor/admin workflows with keyboard and screen-reader-accessible controls.

## Open decisions

- Exact Blueprint-controlled attribute list.
- Automatic versus manually triggered synchronization.
- Behavior of disabling without unlinking.
- Repeated enable/disable and re-enable semantics.
- Conflict and publication behavior when source and child states differ.
