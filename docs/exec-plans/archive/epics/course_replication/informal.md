# Course Replication - Informal Source Context

Last updated: 2026-07-27

This document captures the Jira source material for the course replication epic. It is intentionally informal working context for later PRD, FDD, design, and implementation planning.

## Source tickets

- Roadmap: [`RMAP-127`](https://eliterate.atlassian.net/browse/RMAP-127) - Instructor replication of course features across sections
  - Type: Minor Epic
  - Status: Design
  - Priority: Medium
  - Roadmap intent: restore the legacy ability to configure a course section once and reuse it across multiple sections or semesters, reducing instructor time spent repeating setup work.
  - KPI: meaningful reduction in the time instructors spend replicating settings across course sections.
- Delivery epic: [`MER-5824`](https://eliterate.atlassian.net/browse/MER-5824) - Instructor replication of course features across sections
  - Type: Epic
  - Status: Analyzing
  - Priority: Medium
- Child stories: `MER-5825` through `MER-5833`, plus `MER-5841` (listed below).

`MER-5841` was added as the shared technical foundation for the replication contracts and safety work identified while decomposing the epic.

RMAP-127 describes the user problem, but does not prescribe one mechanism. MER-5824 currently contains two related mechanisms:

1. Blueprint Courses: a continuing source/child relationship with selective synchronization.
2. Course Copy: a one-time point-in-time snapshot with no continuing relationship.

These mechanisms must be presented as different choices. A copied course must never accidentally become a Blueprint child, and a Blueprint child must not be represented as an ordinary independent copy.

## Product outcome

An instructor who teaches the same course in multiple sections should be able to avoid rebuilding the same course repeatedly. Depending on the intended relationship, they should be able to either:

- create a linked child section from an authorized Blueprint Course and receive future source updates; or
- create an independent section from an existing section's current state and customize it without future synchronization.

The experience should make the relationship, permissions, editable/locked settings, and learner-data boundaries explicit before and after creation.

## Workstream A: Blueprint Courses

### Blueprint rules - `MER-5825`

Define and implement the core Blueprint relationship and synchronization rules.

- An existing course can be designated as a Blueprint Course.
- A Blueprint can be the source for one or more child course sections.
- Authorized edits to the Blueprint propagate to associated child sections.
- Child sections inherit Blueprint updates while retaining section-specific settings.
- Child instructors may edit temporal settings (schedule/dates), assessment settings, and section details.
- Blueprint-controlled child settings remain locked, including course content, notes, course discussions, AI recommendations, and cover image. The UI must visibly communicate locked state.
- Student enrollments may exist in a Blueprint Course, but learner-specific data is never propagated.
- Child sections keep independent rosters and learner data.
- Blueprint synchronization must not overwrite child schedules, dates, assessment settings, section details, rosters, progress, grades, submissions, discussions, analytics, or other learner-generated data.
- Child edits to locked content cannot override the Blueprint.

This work needs a precise attribute-level contract. The ticket leaves open which existing course attributes can technically be locked and which must remain editable; engineering should audit the current resource, publication, section, settings, and authorization models before implementation.

### Enable/disable and access - `MER-5826`

Add the controls and authorization model for making an existing section a Blueprint.

- An instructor or admin can enable an existing course section as a Blueprint.
- An enabled Blueprint becomes discoverable in the course builder only to users with access.
- Instructor access grants are limited to the instructor's institution or explicitly supplied delivery emails.
- Admin access may be granted by institution, direct delivery, or platform-wide.
- The Blueprint owner's contact information is available to linked child sections.
- Disabling a Blueprint requires an explicit confirmation explaining the consequences.
- Disabling must allow the user to choose whether to unlink child courses.
- Unlinked children stop receiving future Blueprint updates and should see clear status messaging.
- Access changes must not expose a Blueprint to unauthorized users.
- Enabling/disabling must not silently change ownership or child course data.

The access model needs to be enforced server-side, not only through course-builder filtering. It should be scoped for institution tenancy and direct-delivery permissions, and should prevent information leakage through counts, search, or linked-section views.

### Create a child from a Blueprint - `MER-5829`

Extend course creation so an instructor can choose an authorized Blueprint as the source for a new linked section.

- Blueprint Courses are searchable and sortable through the existing course-builder flow.
- Selecting a Blueprint displays explanatory messaging: the new section is linked, future Blueprint updates propagate, and section-specific temporal, assessment, and detail settings remain customizable.
- The Blueprint card provides an accessible equivalent of the “Create New Section from Blueprint” action.
- Completing course setup creates a new child linked to the selected Blueprint.
- The child receives Blueprint content and locked settings and remains eligible for future updates.
- The Blueprint itself is not modified.
- Child edits to editable settings do not propagate back to the Blueprint.
- A child cannot remove or alter its displayed Blueprint source information.
- The child Manage page identifies the source Blueprint, Blueprint owner name, and owner email.
- Users cannot create children from Blueprints they cannot access.

Creation should be transactional: either the section and relationship are created consistently, or the user receives a recoverable error with no partial relationship. The snapshot/initial-sync behavior at creation must be defined, including how current publication state, settings, and later source revisions are selected.

### View linked sections - `MER-5827`

Give Blueprint owners and administrators visibility into downstream usage.

- A Blueprint displays the current number of linked child sections.
- When children exist, a “View All” action opens a linked-sections table.
- The table lists all currently linked, non-deleted children.
- Administrators can link to each child's Manage page.
- Instructors receive a view-only list; child names are not links when the instructor lacks permission to access those sections.
- Counts and table contents update as children are linked, unlinked, or deleted.
- Non-Blueprint courses do not show Blueprint child information.

The table's exact columns remain open. Candidate fields include child course title, institution, instructor, last synchronized time, and synchronization status, likely aligned with Browse All Course Sections.

### Admin records and filtering - `MER-5830`

Make Blueprint relationships legible anywhere administrators inspect course sections.

- Add consistent, text-based indicators for Blueprint Courses and Blueprint Child Courses.
- Show the indicators on Project Overview and Template Usage.
- Add a Blueprint indicator and filter to Browse All Course Sections.
- The filter supports at least All Course Sections and Blueprint Courses; the child-course representation needs a final product decision.
- Filtering changes only displayed results and does not alter course data or permissions.
- Non-Blueprint sections do not receive Blueprint tags.

The “Blueprint”/“Blueprint Child” labels should not rely on color alone and should use one shared representation across admin surfaces.

## Workstream B: independent Course Copy

### Copy rules - `MER-5831`

Implement the one-time snapshot semantics.

- A user can create a new course from an existing course's current state.
- The new course is a complete point-in-time snapshot of the source content/settings selected by the copy flow.
- The new course is independent immediately after creation.
- Later source changes do not propagate to the copy.
- Copy changes do not affect the source.
- No parent/child or other live relationship is retained.
- Never copy rosters, progress, grades, submissions, discussion participation, analytics, or any other learner-generated data.

The copy operation needs an explicit allowlist of source data and a denylist of learner-owned data. It should use existing resource/revision and publication conventions without copying attempts or section-scoped student records. Failure handling should avoid creating a partially copied section.

### Select a section and copy behavior - `MER-5832`

Expose independent copies in the course builder.

- Add a My Course Sections source tab containing sections created by the current instructor.
- The list supports the existing search and selection behavior.
- Selecting a section opens a modal with two choices: copy the entire course or copy selected settings only.
- The selected-settings path should support at least content/curriculum, schedule, assessment settings, and Manage settings, subject to the final copy allowlist.
- Course cards expose an accessible “Copy Course Section” action.
- Creation uses a point-in-time snapshot and produces a new unlinked section.
- The copied section can be customized independently.
- Sections not created by the current instructor are not shown in My Course Sections.
- The flow cannot include learner data or create a live source relationship.

The UI should distinguish My Course Sections from Blueprint Courses even when the same course-builder screen lists both.

## Shared course-builder UI - `MER-5828`

Update the course selection experience to support both source types without confusing their semantics.

- Increase card density and improve metadata scanability.
- Add source filters: All Sources, My Course Sections, and Blueprint Courses.
- Preserve the existing sort behavior, defaulting to Most Recent.
- Changing filters must not reset the selected sort order.
- Add consistent course-type tags: Blueprint and My Section, with a final decision needed for Blueprint Child display.
- Do not show an inapplicable tag.
- Search and sorting must operate within the selected source semantics and must not modify relationships.

All filters, sort controls, cards, tabs, and card actions must support keyboard use and expose selected state. Dynamic list changes should be announced where appropriate. Hover text must always have a keyboard and screen-reader equivalent.

## Closed or removed child scope

`MER-5833` - “Blueprints: Child section” is currently `Closed Won't Do` and has no description or acceptance criteria returned by Jira. It should not be treated as additional implementation scope unless product reopens or replaces it. Its apparent intent is covered by `MER-5825` and `MER-5829`.

## Cross-cutting engineering work

The stories describe user-facing outcomes but leave the implementation seams open. Planning should cover at least the following:

- Data model for Blueprint status, source/child relationship, access grants, unlink state, synchronization state, and audit timestamps.
- Clear distinction between a Blueprint relationship and an independent copy; enforce invariants at the database and context layers.
- Authorization for enabling, discovering, creating from, viewing, disabling, unlinking, and managing Blueprint relationships across instructors, admins, institutions, and direct delivery grants.
- Initial copy/snapshot behavior and ongoing Blueprint synchronization, including ordering, retries, idempotency, partial-failure recovery, and stale/deleted/unlinked children.
- Attribute-level propagation and lock enforcement in authoring and delivery paths. Locked state must be enforced on writes, not only rendered in the UI.
- Learner-data isolation: rosters, enrollments, attempts, grades, submissions, discussions, analytics, and other student-generated records must never cross either copy or Blueprint boundaries.
- Course builder query/filter APIs that avoid leaking inaccessible Blueprint metadata and preserve search/sort behavior.
- Admin and instructor linked-section queries that apply authorization to both counts and rows.
- User-facing messaging for creation, initial sync, later sync, disable/unlink, inaccessible sources, failures, and stale relationships.
- Auditability for Blueprint enable/disable, access changes, child creation, synchronization, and unlinking.
- Background processing if propagation can exceed a normal request; expose status and recoverable failures rather than silently leaving children inconsistent.

## Verification expectations

Tests should cover both happy paths and the negative boundaries in the tickets.

- Context/domain tests for copy allowlists, Blueprint propagation, locked versus editable attributes, unlinking, idempotency, and learner-data exclusion.
- Authorization tests for institution boundaries, direct delivery grants, admin versus instructor capabilities, inaccessible sources, linked-section counts, and Manage links.
- Database/integration tests proving independent copies have no live relationship and Blueprint children have the expected relationship and sync state.
- End-to-end course-builder tests for filters, search, sorting, source cards, copy modal, Blueprint creation, and clear relationship messaging.
- Admin UI tests for Project Overview, Template Usage, Browse All Course Sections, tags, filters, counts, and linked-section tables.
- Accessibility tests for keyboard-only operation, focus management, dialog semantics, semantic tables, selected states, accessible labels, and dynamic announcements.
- Failure tests for partial copy, failed initial sync, failed later propagation, deleted/unlinked children, disabled Blueprints, and retry behavior.
- Regression tests confirming existing course creation, publication/deployment, permissions, and learner records are unaffected for ordinary non-Blueprint courses.
- Scenario/integration coverage for an instructor creating multiple sections from one source, customizing allowed settings independently, updating Blueprint-controlled content, and confirming that student data stays isolated.

## Product and technical decisions still needed

- Is the intended first release both Blueprint synchronization and independent Course Copy, or should the minor epic be phased with one mechanism first?
- Which exact course attributes are Blueprint-controlled, and which remain editable in children?
- What does a Blueprint update mean for unpublished authoring content, published revisions, deployed sections, and children at different publication states?
- Is synchronization automatic, manually triggered, or queued with visible status? What happens when a child has local conflicts or a source update fails?
- Can a course be enabled and disabled as a Blueprint repeatedly? What happens to existing children and historical relationship data?
- Does disabling without unlinking freeze existing children, hide the source, or preserve a future re-enable path?
- What access-grant management UI and notification/audit behavior are required?
- What fields appear in the linked-child table, and should instructors ever see names or metadata for children they cannot access?
- For Course Copy, which settings are selectable in the partial-copy modal, and what does “content/curriculum” include?
- Which source sections qualify as “created by the current instructor” (ownership, creator, institution, or permission-based definition)?
- How are duplicate names, course identifiers, dates, integrations, and external LMS/LTI settings handled during copy or child creation?
- What scale and latency require background jobs, progress indicators, or resumable operations?

## Definition of done for the epic

The epic is complete when an authorized instructor can discover the intended source, understand whether they are making a linked Blueprint child or an independent copy, create the new section successfully, and manage it according to the selected relationship. Blueprint updates must propagate only within the defined locked boundary, independent copies must remain independent, and no learner-generated data may cross either boundary. Admins and instructors must be able to identify and inspect relationships within their permissions, while all core flows are covered by automated authorization, integration, UI, and accessibility tests.
