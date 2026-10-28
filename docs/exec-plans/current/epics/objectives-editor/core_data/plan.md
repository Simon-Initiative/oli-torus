# MER-5855 LearningObjectiveCoverage Data Source - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/objectives-editor/core_data/prd.md`
- FDD: `docs/exec-plans/current/epics/objectives-editor/core_data/fdd.md`
- Requirements: `docs/exec-plans/current/epics/objectives-editor/core_data/requirements.yml`
- Parent epic plan: `docs/exec-plans/current/epics/objectives-editor/plan.md`
- Jira: `MER-5855` under epic `MER-5784`

## Scope

Implement the read-only authoring coverage data source in `lib/oli/authoring/`, including its compact working-publication projection, normalized in-memory indexes, coverage summaries, page-first details, curriculum scope, and in-memory search projection. Add focused ExUnit/DataCase coverage and operational safeguards. Do not implement the workspace UI, filters, CSV export, activity-bank indexing, or proficiency aggregation.

## Clarifications & Default Assumptions

- The implementation targets the workspace Learning Objectives Editor; the older objectives route is not migrated in this work item.
- The public module boundary is `Oli.Authoring.ObjectiveCoverage`; the exact internal struct names may be selected during Phase 1 but must remain stable for consumer tickets.
- A missing `activity_refs` value is treated as an empty embedded-activity relationship; no page-content fallback is added.
- A missing working publication is returned as an explicit tagged error; multiple working publications are also rejected rather than merged, and valid empty working publications return an empty model with context.
- Curriculum paths are represented with stable node/resource ids, titles, parent ids, and descendant page ids sufficient for `MER-5800` and `MER-5801`; no additional content query is introduced.
- Initial activity coverage includes only static embedded activities referenced from page `activity_refs`; bank-selection coverage is a follow-up.
- No feature flag or migration is required. Telemetry remains aggregate-only and follows `docs/OPERATIONS.md`.
- Required review lenses are security, performance, Elixir, and requirements because this work adds backend query/domain behavior and traceability artifacts.

## Phase 1: Projection Boundary and Normalized Indexes

- Goal: establish the application module, compact working-publication query, row normalization, and core resource lookup/hierarchy indexes.
- Tasks:
  - [x] Add `Oli.Authoring.ObjectiveCoverage` with explicit load/build entry points and tagged errors.
  - [x] Implement one project-scoped Ecto projection joining publications, projects, published resources, and revisions, filtering to the current unpublished publication and non-deleted rows.
  - [x] Select only the required compact fields; explicitly omit page/activity `content` and avoid revision preloads.
  - [x] Normalize nullable objectives, children, activity references, scope, and assessment fields into safe internal row values.
  - [x] Partition objective, page, activity, and container rows and build resource-id lookup maps, parent/child maps, page/activity maps, and curriculum node indexes.
  - [x] Add module documentation describing the snapshot contract and embedded-only scope.
- Testing Tasks:
  - [x] Add pure builder tests for row partitioning, lookup maps, hierarchy relationships, curriculum nodes, malformed optional values, and deterministic ordering. Cover `AC-003` and `AC-008`.
  - [x] Add DataCase/query tests for project and working-publication scope, deleted-row exclusion, selected fields, and revision mapping. Cover `AC-002`.
  - [x] Add a load-contract test showing the application module supplies the model independently of LiveView coverage logic. Cover `AC-001`.
  - Command(s): `mix test test/oli/authoring/objective_coverage_test.exs`
- Definition of Done:
  - The module can load or build a compact scoped model with no content selection and stable core indexes.
  - Phase tests pass and the query shape is reviewable without hidden N+1 reads.
- Gate:
  - Security/performance review confirms project scoping, deleted filtering, no content selection, and one projection before coverage derivation begins.
- Dependencies:
  - PRD, FDD, and requirements are present; no implementation dependency.
- Parallelizable Work:
  - Pure row/model test fixtures can be developed alongside the query, provided both use the same documented row contract.

## Phase 2: Coverage, Details, and Search Projections

- Goal: derive direct/inherited coverage, assessment buckets, page-first detail groups, and normalized search data from Phase 1 indexes.
- Tasks:
  - [x] Flatten page and activity objective maps and build direct page/activity attachment sets.
  - [x] Resolve page `activity_refs` to compact activity summaries and inherit formative/summative classification from the containing page.
  - [x] Implement parent-objective expansion across transitive Sub-Objective relationships with visited-set cycle protection.
  - [x] Deduplicate summary page/activity ids by objective and assessment bucket while preserving page-grouped detail identity.
  - [x] Add model accessors for objective summaries, coverage, details, curriculum page scope, and normalized partial search results.
  - [x] Preserve original titles/slugs/ids alongside normalized search text and match hierarchy metadata.
- Testing Tasks:
  - [x] Test direct versus inherited parent/Sub-Objective counts, duplicate tags, shared Sub-Objectives, and assessment bucket behavior. Cover `AC-004`.
  - [x] Test page-first details, formative/summative activity inheritance, and pages with no activities in a selected bucket. Cover `AC-005`.
  - [x] Test case-insensitive, trimmed, whitespace-normalized partial search across objective, Sub-Objective, page, and activity titles. Cover `AC-006`.
  - Command(s): `mix test test/oli/authoring/objective_coverage_test.exs`
- Definition of Done:
  - All coverage and consumer-facing projections derive from the single Phase 1 model and return deterministic results.
  - Parent summaries include direct and descendant attachments; Sub-Objective summaries remain direct-only.
- Gate:
  - Representative fixture assertions demonstrate correct counts, details, search matches, and no additional database calls after model construction.
- Dependencies:
  - Phase 1 core row and index contract.
- Parallelizable Work:
  - Search tests and detail-shape tests can proceed in parallel after the normalized row shape is fixed.

## Phase 3: Scope Hardening, Observability, and Performance Verification

- Goal: close safety, embedded-only behavior, diagnostics, deterministic resilience, and operational verification for production use.
- Tasks:
  - [x] Exclude banked/standalone activities and document the absence of bank-selection coverage in the returned model contract.
  - [x] Ensure model construction has no write path and safely omits missing activity/objective references.
  - [x] Add bounded telemetry/logging for load/build duration, row counts, and tagged failures without content bodies.
  - [x] Add explicit safeguards for malformed/cyclic hierarchy data and stable finite output.
  - [x] Review query plans and representative model sizes; make only measured compactness improvements within scope.
  - [x] Document the final missing-publication and malformed-data behavior in the FDD or execution record if it differs from the defaults above.
- Testing Tasks:
  - [x] Test embedded-only inclusion, bank-selection/standalone exclusion, and read-only behavior. Cover `AC-007`.
  - [x] Test deleted/out-of-project rows, malformed optional data, cycle protection, repeat-build stability, and sorted output. Cover `AC-008`.
  - [x] Run targeted tests, formatting, and inspect the query for one projection/no N+1 behavior. Cover `AC-009`.
  - Command(s): `mix test test/oli/authoring/objective_coverage_test.exs && mix format --check-formatted`
- Definition of Done:
  - Resilience and operational behavior are covered without expanding into migrations, caches, or bank-selection indexing.
  - Aggregate observability is present or explicitly documented as unnecessary for this request-scoped read model.
- Gate:
  - Targeted tests and formatting pass; security, performance, Elixir, and requirements reviews complete with findings resolved or recorded.
- Dependencies:
  - Phases 1 and 2.
- Parallelizable Work:
  - Telemetry tests and query-plan inspection can run alongside resilience tests after the public load contract is stable.

## Phase 4: Final Integration and Traceability Closure

- Goal: verify the work item and implementation are aligned for downstream UI consumers and close all repository gates.
- Tasks:
  - [x] Run the full relevant authoring/publishing regression targets if Phase 1-3 changes touch shared publishing helpers or existing objective behavior; no shared helpers or existing objective behavior were changed, so no additional regression target was required.
  - [x] Confirm the workspace LiveView remains unchanged unless a minimal consumer wiring change is explicitly added to this work item.
  - [x] Update FDD/PRD assumptions or open questions if implementation choices diverged; no divergence was found.
  - [x] Add implementation references for acceptance criteria where the repository traceability workflow requires them.
- Testing Tasks:
  - [x] Run work-item validation before and after implementation.
  - [x] Run final requirements verification for implementation completion.
  - Command(s): `python3 /Users/raph/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/objectives-editor/core_data --check all`
  - Command(s): `python3 /Users/raph/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/objectives-editor/core_data --action verify_implementation`
- Definition of Done:
  - Implementation, tests, review, documentation, and requirements proof are synchronized.
  - Downstream consumers can use the documented model without adding competing coverage queries.
- Gate:
  - All repository and Harness validation commands pass; no unresolved review findings or planning drift remains.
- Dependencies:
  - Phases 1-3 and required review round.
- Parallelizable Work:
  - Documentation synchronization and final regression selection can occur while review feedback is being consolidated.

## Parallelization Notes

- Phase 1 must precede Phases 2 and 3 because the row/model contract is the shared boundary.
- Pure transformation tests may be written in parallel with query implementation after the row contract is agreed.
- Query, security, and performance review should happen before wiring the model into UI consumers.
- Phase 4 is serial with respect to final review and traceability closure.

## Phase Gate Summary

- Gate A: Phase 1 query and index tests pass; one scoped compact projection is verified.
- Gate B: Phase 2 coverage/detail/search tests pass with correct parent/Sub-Objective semantics.
- Gate C: Phase 3 resilience, embedded-only, observability, formatting, security, and performance checks pass.
- Gate D: Phase 4 work-item validation, requirements verification, regression tests, and review closure pass.
