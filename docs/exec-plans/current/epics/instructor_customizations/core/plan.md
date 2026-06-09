# Instructor Activity Customization Core - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/core/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/core/fdd.md`
- Requirements: `docs/exec-plans/current/epics/instructor_customizations/core/requirements.yml`
- Informal design: `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`

## Scope
Deliver the `MER-5639` core implementation for section/page-specific instructor activity customization on basic pages. The work includes persistence, centralized context APIs, validation and authorization, delivery-time filtering for new attempts, activity bank candidate review data, stale-row tolerance, and Oli.Scenarios coverage.

The implementation must not mutate authored revisions, publications, or `SectionResource` records. It must not rebuild active or historical attempts. Complete Instructor Preview UI controls, layouts, bulk actions, and filtering remain outside this work item.

## Clarifications & Default Assumptions
- Use `section_page_activity_exclusions` and a row-per-active-exclusion model.
- Use page resource ids rather than revision ids so exclusions survive republishing of the same page resource.
- Use activity resource ids for embedded activity and bank candidate exclusions.
- Use `Oli.Delivery.InstructorCustomizations` as the single domain boundary for validation, authorization, writes, reads, and candidate-count rules.
- Reject a new candidate exclusion when that activity no longer matches the selection's current logic; tolerate already-persisted stale rows during reads and delivery.
- Preserve existing attempt behavior. Customization applies only while creating a new attempt.
- No feature flag is planned. The additive migration begins with no exclusions, preserving existing behavior.
- No stale-row cleanup job or audit trail is planned.
- Decide and document the canonical instructor/admin authorization helper before exposing write APIs. Default toward existing section-instructor and content-admin checks without copying web-layer authorization into callers.
- Add dedicated write telemetry only if a matching local telemetry convention is found during implementation. Explicit errors and test coverage are mandatory either way.
- Confirm the current Instructor Preview owner before adding any preview transport integration. Do not couple the core to `PageDeliveryController.page_preview/2`.

### Requirements Traceability
- Phase 1 covers persistence and page read-model foundations: `FR-001`, `FR-007`, `AC-001`, `AC-002`, `AC-003`, `AC-016`, `AC-018`.
- Phase 2 covers context APIs, validation, authorization, candidate listing, and guardrails: `FR-002`, `FR-005`, `FR-007`, `FR-008`, `AC-004`, `AC-005`, `AC-006`, `AC-010`, `AC-012`, `AC-017`, `AC-019`.
- Phase 3 covers embedded activity and whole-selection realization behavior: `FR-003`, `FR-004`, `FR-006`, `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-013`, `AC-014`, `AC-015`.
- Phase 4 covers selection-local candidate filtering and delivery hardening: `FR-005`, `FR-006`, `FR-008`, `AC-011`, `AC-012`, `AC-013`, `AC-014`, `AC-015`, `AC-019`, `AC-020`.
- Phase 5 covers scenario infrastructure and end-to-end proof: `FR-009`, `AC-020`, `AC-021`, `AC-022`.
- Phase 6 covers final integration, performance, security, observability, and compatibility verification across `AC-001` through `AC-022`.

`AC-003` is intentionally split across phases: Phase 1 proves database uniqueness prevents duplicate active rows, while Phase 2 proves repeated disable operations are idempotent at the context API boundary.

## Phase 1: Persistence And Page Exclusion Read Model
- Goal: establish the additive data model and pure page-level read model used by all later phases.
- Tasks:
  - [x] Add the `section_page_activity_exclusions` migration with section/page scope, exclusion kind, nullable selection id, nullable excluded activity resource id, timestamps, partial uniqueness constraints, and concrete read-path indexes.
  - [x] Add `Oli.Delivery.InstructorCustomizations.ActivityExclusion` with kind-specific changeset validation.
  - [x] Add `Oli.Delivery.InstructorCustomizations.PageExclusions` with MapSet-backed fields for embedded activities, selections, and candidates grouped by selection.
  - [x] Add raw page exclusion listing and a single-query `get_page_exclusion_view/2` projection.
  - [x] Add pure predicates for embedded activities, bank selections, and selection-local candidates.
  - [x] Confirm that persistence does not touch authored revisions, publications, or `SectionResource` records.
- Testing Tasks:
  - [x] Add schema tests for required and forbidden field combinations per exclusion kind.
  - [x] Add database constraint tests proving duplicate exclusions cannot be persisted.
  - [x] Add read-model and predicate tests, including empty and mixed-kind page views.
  - [x] Assert the page view is built from one query for `section_id + page_resource_id`.
  - Command(s): `mix test test/oli/delivery/instructor_customizations`, `mix format`
- Definition of Done:
  - the migration is additive and reversible
  - one active exclusion per target is enforced by database constraints
  - `%PageExclusions{}` accurately projects all active rows for one section and page
  - `AC-001`, `AC-002`, `AC-003`, `AC-016`, and `AC-018` have targeted automated coverage
- Gate:
  - schema, constraint, query-shape, read-model, and predicate tests pass before write APIs or delivery integration begin
- Dependencies:
  - none
- Parallelizable Work:
  - read-model/predicate implementation and tests can proceed while migration/schema work is being completed once field names are fixed

## Phase 2: Context APIs, Validation, Authorization, And Candidate Review
- Goal: implement the authoritative application boundary for toggles, target validation, candidate listing, and count protection.
- Tasks:
  - [x] Add `Oli.Delivery.InstructorCustomizations` and section normalization helpers for section structs and ids.
  - [x] Select and centralize the canonical instructor/admin-equivalent authorization check for writes.
  - [x] Resolve the current page revision from the section publication and validate that the page is a supported basic page.
  - [x] Implement target validation for embedded activities, whole selections, and bank candidates.
  - [x] Implement idempotent embedded activity and whole-selection enable/disable APIs and semantic exclude/restore wrappers.
  - [x] Implement bank candidate enable/disable APIs and semantic wrappers.
  - [x] Implement transactionally safe candidate-count validation so concurrent disables cannot leave fewer enabled candidates than selection `count`.
  - [x] Implement `get_selection_exclusion_view/3`.
  - [x] Implement `list_bank_selection_candidates/4` using current selection logic and existing activity bank query patterns; annotate candidates with enabled/excluded state and `disable_allowed?`.
  - [x] Return `%PageExclusions{}` after successful writes and explicit error tuples after failures.
  - [x] Tolerate existing stale rows during reads while rejecting new invalid candidate write targets.
  - [x] Decide whether a dedicated customization-write telemetry event matches local conventions; add it here if selected.
- Testing Tasks:
  - [x] Add context tests for every expected error shape, including authorization, missing targets, adaptive pages, and invalid candidates.
  - [x] Add idempotent disable/restore tests for all three exclusion kinds.
  - [x] Add candidate-count tests for active counts above, equal to, and below the selection count.
  - [x] Add concurrency-focused coverage for candidate disables or document and test the selected serialization mechanism.
  - [x] Add candidate listing tests for annotation, action availability, selection-disabled state, and stale rows.
  - [x] Assert successful writes return the refreshed page exclusion view.
  - Command(s): `mix test test/oli/delivery/instructor_customizations`, `mix format`
- Definition of Done:
  - all domain writes and reads are available through one context
  - authorization and validation are not delegated to controllers, LiveViews, or scenario handlers
  - the candidate-count rule cannot be bypassed by normal or concurrent writes
  - `AC-004`, `AC-005`, `AC-006`, `AC-010`, `AC-012`, `AC-017`, and `AC-019` have targeted automated coverage
- Gate:
  - context tests pass, including explicit authorization and count-guardrail cases, before delivery realization consumes exclusions
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - embedded/selection toggle APIs and candidate-listing read work can proceed concurrently after shared page/target resolution helpers are stable

## Phase 3: Embedded Activity And Whole-Selection Delivery Integration
- Goal: apply embedded activity and whole-selection exclusions while creating new basic-page attempts and persist correctly transformed content.
- Tasks:
  - [x] Extend `Oli.Activities.Realizer.Query.Source` with an optional `%PageExclusions{}` field while preserving nil/empty backwards compatibility.
  - [x] Update `Oli.Delivery.Attempts.PageLifecycle.Hierarchy.create/1` to load the page exclusion view once and pass it into activity realization.
  - [x] Update `Oli.Delivery.ActivityProvider` to skip excluded embedded activity references before creating prototypes.
  - [x] Update `ActivityProvider` to skip excluded whole bank selections before parsing, existing-prototype migration, or fulfillment.
  - [x] Generalize transformed-content handling so excluded embedded references are removed even on pages without bank selections.
  - [x] Ensure excluded selections transform to no realized activity references and contribute no score/out-of value.
  - [x] Ensure exclusions win over constraining prototypes when a new attempt would otherwise migrate excluded activities or selections.
  - [x] Preserve current provider behavior when exclusions are nil or empty.
- Testing Tasks:
  - [x] Extend activity provider tests for embedded activity filtering and transformed content on pages with and without selections.
  - [x] Extend activity provider tests for whole-selection filtering, including existing constraining prototypes.
  - [x] Add lifecycle tests proving one page exclusion read is used during new attempt creation.
  - [x] Add practice and graded basic-page tests proving current exclusions apply only to new attempts.
  - [x] Add tests proving existing active and historical attempts remain unchanged after rows change.
  - [x] Run existing provider, hierarchy, and retake-mode regression tests.
  - Command(s): `mix test test/oli/delivery/activity_provider_test.exs`, `mix test test/oli/delivery/attempts/hiearchy_test.exs test/oli/delivery/attempts/optimized_hiearchy_test.exs test/oli/delivery/attempts/retake_mode_test.exs`, `mix format`
- Definition of Done:
  - embedded activity and whole-selection exclusions affect prototypes, transformed content, and out-of values for new attempts
  - attempt consistency and nil/empty exclusion compatibility are preserved
  - `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-013`, `AC-014`, and `AC-015` have targeted automated coverage
- Gate:
  - provider and attempt lifecycle regression suites pass before candidate filtering is layered into selection fulfillment
- Dependencies:
  - Phases 1 and 2
- Parallelizable Work:
  - provider-level filtering tests can be developed alongside lifecycle wiring after the `Source.page_exclusions` contract is fixed

## Phase 4: Selection-Local Candidate Filtering And Republish Hardening
- Goal: apply candidate exclusions to only their matching selections and prove robust behavior across content changes.
- Tasks:
  - [x] Derive a temporary selection source that merges only the current selection's excluded candidate ids into `blacklisted_activity_ids`.
  - [x] Preserve the existing page-wide duplicate-realization blacklist by merging only newly realized activities back into the normal source.
  - [x] Ensure candidate exclusions do not affect another selection on the same page or another page.
  - [x] Ensure stale candidate and selection exclusions do not fail fulfillment or new attempt creation.
  - [x] Ensure page-resource-scoped exclusions survive a new page revision/publication while newly added non-excluded activities remain available.
  - [x] Verify score/out-of and transformed content remain correct after candidate filtering.
- Testing Tasks:
  - [x] Add provider tests with two selections sharing candidate activities to prove selection-local filtering.
  - [x] Add tests proving the existing duplicate-realization behavior remains intact.
  - [x] Add tests for stale candidate/selection rows after selection logic or page content changes.
  - [x] Add republish/new-revision attempt lifecycle coverage preserving old exclusions and rendering new non-excluded activities.
  - [x] Run selection realizer, provider, hierarchy, and retake-mode regression tests.
  - Command(s): `mix test test/oli/activities/realizer/selection_test.exs`, `mix test test/oli/delivery/activity_provider_test.exs`, `mix test test/oli/delivery/attempts/hiearchy_test.exs test/oli/delivery/attempts/optimized_hiearchy_test.exs test/oli/delivery/attempts/retake_mode_test.exs`, `mix format`
- Definition of Done:
  - candidate exclusions are selection-local and cannot leak through the global blacklist
  - stale and republished content behavior is deterministic and non-failing
  - `AC-011`, `AC-019`, and `AC-020` have targeted automated coverage while `AC-012` through `AC-015` remain green
- Gate:
  - all candidate-locality, stale-row, republish, and delivery regression tests pass before scenario infrastructure is finalized
- Dependencies:
  - Phases 1 through 3
- Parallelizable Work:
  - stale-row/republish lifecycle tests can be authored while provider candidate-filtering implementation is underway

## Phase 5: Oli.Scenarios Directives And End-To-End Workflows
- Goal: expose the non-UI behavior through reusable scenario directives and prove realistic authoring-to-delivery workflows.
- Tasks:
  - [x] Use the `extend_scenario` workflow to add directive types, parser/validator/schema support, handlers, and documentation for enabling/disabling embedded activities, whole selections, and bank candidates.
  - [x] Ensure scenario handlers call `Oli.Delivery.InstructorCustomizations` semantic wrappers rather than duplicating validation or persistence logic.
  - [x] Add scenario assertion support based on `get_page_exclusion_view/2` and pure predicates when direct exclusion-state assertions are needed.
  - [x] Use the `build_scenario` workflow to add focused YAML scenarios for practice and graded basic pages.
  - [x] Add a scenario where the same bank candidate is eligible on two pages and excluded only on page A.
  - [x] Add a scenario where a page with an exclusion is republished with a new activity and a new attempt preserves the exclusion while rendering the new activity.
  - [x] Document the new directives in the scenario reference.
- Testing Tasks:
  - [x] Add parser, validator, handler, and schema tests for the new directives.
  - [x] Validate each new scenario YAML file.
  - [x] Run targeted scenarios and the scenario runner regression suite.
  - Command(s): `mix test test/oli/scenarios`, `mix scenarios test/scenarios/instructor_customizations/page_isolation.scenario.yaml`, `mix scenarios test/scenarios/instructor_customizations/republish_preserves_exclusions.scenario.yaml`, `mix test test/scenarios/scenario_runner_test.exs`, `mix format`
- Definition of Done:
  - scenario authors can exercise all three customization targets without hooks, fixtures, factories, mocks, or duplicated business rules
  - page isolation and republish behavior pass through real authoring, publication, section, and attempt workflows
  - `AC-020`, `AC-021`, and `AC-022` have end-to-end scenario proof
- Gate:
  - new scenario directives validate and execute successfully, and the existing scenario runner remains green
- Dependencies:
  - Phases 1 through 4
- Parallelizable Work:
  - directive schema/parser work can begin after Phase 2 context contracts stabilize; final scenario workflows depend on delivery integration from Phases 3 and 4

## Phase 6: Integration Review, Observability, And Final Verification
- Goal: reconcile the implementation with the feature documents, verify cross-cutting requirements, and prepare the core for later UI tickets.
- Tasks:
  - [x] Confirm the active Instructor Preview owner after rebasing onto master. No preview transport code was touched in this core slice; keep future UI integration transport-independent.
  - [x] If this core slice modifies candidate preview transport, keep the controller/LiveView adapter thin and route all reads through the context; do not implement later-ticket UI controls. Not applicable: no preview transport was added or changed.
  - [x] Verify the student attempt hot path performs one customization read and no per-activity/per-selection exclusion queries.
  - [x] Verify authorization behavior for instructors, admin-equivalent actors, unauthorized users, and trusted scenario calls.
  - [x] Verify telemetry or explicit operational error behavior follows the Phase 2 decision and does not expose content or learner data.
  - [x] Run security, performance, Elixir, and requirements review passes using repository review guidance.
  - [x] Reconcile PRD, FDD, requirements, and plan if implementation decisions changed.
  - [x] Record implementation proofs for all acceptance criteria.
- Testing Tasks:
  - [x] Run all targeted context, provider, lifecycle, selection, controller/LiveView-if-touched, and scenario tests.
  - [x] Run formatting and compile checks.
  - [ ] Perform a manual smoke check of existing Instructor Preview and "Open as student" flows, confirming active attempts remain stable and new attempts apply exclusions. Not run by Codex; this requires an interactive browser smoke pass.
  - Command(s): `mix test test/oli/delivery/instructor_customizations test/oli/delivery/activity_provider_test.exs test/oli/delivery/attempts test/oli/activities/realizer/selection_test.exs test/oli/scenarios test/scenarios/scenario_runner_test.exs`, `mix test test/oli_web/controllers/activity_bank_controller_test.exs`, `mix format`, `mix compile --warnings-as-errors`
- Definition of Done:
  - all `FR-001` through `FR-009` and `AC-001` through `AC-022` are implemented and have recorded proof
  - delivery performance, authorization, stale-row tolerance, backwards compatibility, and attempt consistency are verified
  - the core is transport-independent and ready for later Instructor Preview UI tickets
- Gate:
  - targeted automated tests, scenario tests, compile, formatting, required review passes, and manual smoke verification all pass
- Dependencies:
  - Phases 1 through 5
- Parallelizable Work:
  - documentation reconciliation, review passes, and manual smoke preparation can proceed while final low-risk test fixes land

## Parallelization Notes
- Phase 1 migration/schema work and read-model/predicate work can proceed concurrently after the database fields and kind values are agreed.
- Add future reporting or kind-summary indexes only alongside the concrete queries that require them.
- Phase 2 embedded/selection toggles can be developed in parallel with candidate listing, but candidate disable writes must wait for the shared target-resolution and transaction strategy.
- Phase 3 provider tests and lifecycle wiring can proceed concurrently once the `Source.page_exclusions` contract is stable.
- Phase 4 republish/stale-row tests can be prepared while selection-local filtering is implemented.
- Phase 5 scenario DSL support can begin after context APIs stabilize, but end-to-end scenarios depend on delivery behavior being complete.
- Avoid parallel edits to `Oli.Delivery.ActivityProvider` across Phases 3 and 4 unless ownership is coordinated; both phases touch the same traversal and fulfillment state.

## Phase Gate Summary
- Gate A: additive persistence, constraints, single-query page read model, and predicates are correct.
- Gate B: centralized context APIs enforce authorization, validation, idempotency, and candidate-count safety.
- Gate C: embedded activities and whole selections are filtered correctly for new attempts without changing existing attempts.
- Gate D: bank candidate exclusions remain selection-local and survive republishing/content drift safely.
- Gate E: Oli.Scenarios directives and end-to-end workflows prove the non-UI feature behavior.
- Gate F: cross-cutting verification, required reviews, docs reconciliation, and all acceptance-criteria proofs are complete.
