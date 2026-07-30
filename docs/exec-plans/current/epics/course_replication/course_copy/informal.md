# Independent Course Copy - Informal Feature Context

Last updated: 2026-07-27

This feature delivers one-time Course Copy from an instructor's existing course section. It is intentionally independent from Blueprint synchronization.

## Source tickets

- `MER-5831` Course Copy: Rules
- `MER-5832` Course Builder: Selecting a section to copy
- Epic context: `../informal.md`
- Parent lane plan: `../plan.md`

## Product outcome

An instructor can use the current state of an eligible course section as the starting point for a new, independent section. The instructor may copy the entire course or a supported subset of settings, then customize the result without affecting or receiving updates from the source.

## Functional scope

- Define eligible My Course Sections for the current instructor.
- Support full-course point-in-time copying.
- Support selected-settings copying, initially considering content/curriculum, schedule, assessment settings, and Manage settings.
- Create a new independent section with no parent/child or live synchronization relationship.
- Keep source and copy independently editable after creation.
- Exclude rosters, enrollments, attempts, progress, grades, submissions, discussion participation, analytics, and all other learner-generated data.
- Provide clear copy success, validation, stale-source, and failure messaging.

## Technical guidance

Use an explicit source-data allowlist and learner-data denylist. Validate selected categories server-side; do not accept arbitrary client-selected fields. Recheck source eligibility and authorization when the copy request is submitted.

Use existing Resource/Revision/Publication conventions where appropriate, but ensure no Blueprint metadata or source relationship is retained. The operation should be transactional or expose durable operation status and resumable/retryable behavior so partial copies are not presented as valid courses. Define how identifiers, names, dates, integrations, external LMS/LTI settings, publication state, and section metadata are generated or retained.

## Out of scope

- Blueprint source/child synchronization; see `../blueprint_lifecycle/`.
- Shared course-builder filtering and card layout; see `../course_builder_sources/`.

## Dependencies and handoff

- Hard dependency on `../replication_contracts/` for copy boundaries and learner-data exclusion.
- `../course_builder_sources/` consumes the My Course Sections query and copy initiation contract.
- Coordinate terminology and shared card primitives with the Blueprint features without sharing relationship semantics.

## Verification expectations

- Full and selective copy integration tests.
- Tests proving source/copy independence after both are edited.
- Tests proving no learner-generated data crosses the boundary.
- Authorization and eligibility tests for My Course Sections.
- Failure, retry, stale-source, and partial-copy tests.
- Accessible copy modal and keyboard workflow tests.

## Open decisions

- Whether “created by the current instructor” means creator, owner, institution, or permission-based eligibility.
- Exact selective-copy categories and the meaning of content/curriculum.
- Treatment of external integrations, identifiers, dates, and publication state.
- Whether large copies require background operations and progress status.
