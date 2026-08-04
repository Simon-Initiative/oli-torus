# Course Replication Contracts and Safety - Informal Feature Context

Last updated: 2026-07-27

This feature establishes the shared domain contracts required by the Blueprint and independent Course Copy features in `MER-5824`. Its implementation scope is tracked by `MER-5841`; it is a cross-cutting foundation feature rather than a user-facing workflow.

## Source context

- Epic: `MER-5824` Instructor replication of course features across sections
- Roadmap: `RMAP-127` Instructor replication of course features across sections
- Feature story: `MER-5841` Replication contracts and safety foundation
- Parent context: `../informal.md`
- Lane: Replication Contracts and Safety
- Consuming features: `../blueprint_lifecycle/`, `../blueprint_visibility/`, `../course_copy/`, and `../course_builder_sources/`

## Problem and outcome

Torus needs two replication semantics that look related in the product but are technically different:

- Blueprint Courses maintain a source/child relationship and receive future source updates.
- Course Copy creates a point-in-time snapshot with no continuing relationship.

The implementation must make that distinction durable in the data model and enforce it at context, authorization, synchronization, and copy boundaries. No replication operation may move learner-generated data between sections.

## Scope

- Audit the existing project, resource/revision, publication, section, enrollment, attempt, and authorization models.
- Define Blueprint source, child, access, unlink, and synchronization states.
- Define the invariant that an independent copy has no Blueprint parent/child relationship.
- Define the Blueprint-controlled versus child-editable attribute contract.
- Define the full and selective Course Copy source allowlist and learner-data denylist.
- Define authorization boundaries for discovery, creation, linked-section inspection, enable/disable, and unlink.
- Define operation status, idempotency, ordering, retry, audit, and partial-failure behavior for copy and synchronization.

## Required invariants

- A Blueprint child has at most one active Blueprint source.
- A Course Copy never acquires Blueprint metadata or future synchronization behavior.
- Blueprint synchronization never overwrites child-owned schedule, dates, assessment settings, or section details.
- Neither mechanism copies rosters, enrollments, attempts, progress, grades, submissions, discussions, analytics, or other learner-generated data.
- Locked attributes are enforced on writes and synchronization, not only shown as disabled controls.
- Discovery queries, counts, and relationship rows are authorization-filtered server-side.
- Replayed copy/synchronization operations do not duplicate relationships or corrupt revisions.

## Technical direction

Use existing Oli contexts and Resource/Revision/Publication conventions rather than exposing direct schema access to UI callers. Establish one authoritative domain boundary for relationship state and one for copy/synchronization operations. Keep source classification and authorization reusable by both course-builder and admin queries.

The contract must explicitly address unpublished authoring state, published revisions, deployed sections, deleted children, disabled Blueprints, children at different source versions, stale source selections, and operation retries. If propagation can exceed request time, use a background operation with visible status rather than silently leaving children partially updated.

## Out of scope

- Final course-builder visual design.
- Blueprint enable/disable screens.
- Admin linked-section tables and tags.
- The full Course Copy UI.

## Dependencies and handoff

- No inbound feature dependency; this feature should start first.
- `blueprint_lifecycle/` depends on Blueprint relationship, attribute, authorization, and synchronization contracts.
- `course_copy/` depends on copy allowlists and learner-data exclusions.
- `blueprint_visibility/` and `course_builder_sources/` depend on safe source classification and query contracts.

## Verification expectations

- Domain tests for relationship invariants, copy isolation, propagation boundaries, idempotency, and learner-data exclusion.
- Authorization tests for institution, direct-delivery, instructor, and admin boundaries.
- Database/integration tests proving independent copies have no live relationship and Blueprint children retain expected state.
- Failure tests for stale sources, deleted/unlinked children, retries, and partial operations.

## Open decisions

- Which exact course attributes are Blueprint-controlled?
- Which source state is the canonical initial snapshot and later sync input?
- Are operations synchronous, queued, or resumable?
- How are external LMS/LTI settings, identifiers, dates, and publication state treated?
