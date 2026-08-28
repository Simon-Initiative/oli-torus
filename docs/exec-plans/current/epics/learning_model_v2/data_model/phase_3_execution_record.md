# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/data_model`
Phase: `3`

## Scope from plan.md

- Copy the immediate trusted source's learning-model selection through Project, blueprint, and Section creation and duplication paths.
- Keep existing Sections pinned and ordinary new Projects behavior-neutral at `:naive`.
- Leave Revision lifecycle and archive import/export preservation to Phases 4 and 5.

## Implementation Blocks

- [x] Core behavior changes
  - Added trusted source-aware Project and Section creation helpers. These helpers apply the source model after the ordinary changeset, so caller attributes cannot override the pinned source selection.
  - Publication-based Section creation copies its Project, while product-based Section creation copies the blueprint even when that value differs from the base Project.
  - Project cloning, Project-to-blueprint creation, Section/blueprint duplication, and open-and-free product duplication preserve the immediate source value explicitly.
- [x] Data or interface changes
  - Added `Oli.Authoring.Course.create_project_from_source/2` for trusted Project copies.
  - Added `Oli.Delivery.Sections.create_section_from_source/2`, accepting a loaded Project or Section as the trusted source.
  - No schema, migration, archive, or Revision-parameter interface changed in this phase.
- [x] Access-control or safety checks
  - Source values take precedence over caller maps, including maps that attempt to supply a conflicting supported value.
  - General Project and Section changesets remain unable to mutate model selection; existing Sections receive no write-through when a Project or blueprint later changes.
- [x] Supporting creation paths
  - Updated automation setup, database seeders, focused Section seeders, and scenario Section handlers to use the same source-aware creation boundary when a Project is available.

## Test Blocks

- [x] Tests added or updated
  - Added Project clone coverage for an explicit LKT-AOA source.
  - Added Project-to-blueprint, Project/publication-to-Section, divergent blueprint-to-Section, blueprint duplication, enrollable Section duplication, conflicting-attribute precedence, and post-creation pinning coverage.
- [x] Required verification commands run
  - `mix test test/oli/course_test.exs` — 33 tests, 0 failures.
  - `mix test test/oli/clone_test.exs` — 15 tests, 0 failures.
  - `mix test test/oli/delivery_test.exs` — 16 tests, 0 failures.
  - `mix test test/oli/delivery/sections/blueprint_test.exs` — 25 tests, 0 failures.
  - `mix test test/oli_web/controllers/open_and_free_controller_test.exs` — 4 tests, 0 failures.
  - `mix test test/oli/scenarios/product_test.exs test/oli/scenarios/section_revise_test.exs` — 12 tests, 0 failures.
- [x] Results captured
  - Running all four prescribed test files in one VM produced one pre-existing global browse-order failure: a blueprint created by another async test module sorted ahead of the row expected by `BlueprintTest`. The failing test passed alone, and each prescribed file passed independently.
  - The Delivery suite emitted its existing asynchronous inventory-recovery ownership log but completed with zero failures.

## Scenario Coverage Decision

- The current `Oli.Scenarios` directives cannot set or assert `learning_model_version` without extending the scenario framework, which this phase explicitly excludes.
- Real domain integration tests exercise Project publication, blueprint creation, product deployment, and Section persistence instead. Existing product and Section scenario suites were run to verify the source-aware handler changes.

## Acceptance-Criteria Proof Map

- `AC-003`: `DeliveryTest` tests "copies and pins the Project learning model for a new Section" and "copies the blueprint model even when it differs from its base Project"; `BlueprintTest` test "copies and pins the Project learning model"; `OpenAndFreeControllerTest` test "create section from a Project copies its learning model".
- `AC-004`: `CloneTest` test "clone_project/2 preserves learning model selection"; `BlueprintTest` test "copies the immediate source model and ignores an attrs override" covers both blueprint and enrollable Section duplication.
- `AC-005`: the two Delivery tests and the Project-to-blueprint test mutate the source after creation and assert that the created Section/blueprint remains pinned.
- `AC-006`: Phase 2 schema integration coverage proves ordinary Project creation remains `:naive` and general Project/Section changesets ignore crafted model-selection attributes; Phase 3 adds only trusted source-aware creation functions.
- `AC-007`: Phase 2 migration/schema proof establishes the naive backfill and behavior-neutral defaults; Phase 3 changes only explicit propagation from trusted sources and does not implement proficiency dispatch.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No requirement or design decision changed. Phase 3 plan tasks are marked complete.
- [x] Open questions added to docs when needed
  - No new open question was introduced.

## Review Loop

- Round 1 findings:
  - Elixir found that publication-backed open-and-free creation still used the ordinary Section creation function and would therefore keep the destination default instead of copying an LKT-AOA Project.
  - Requirements found that Phase 3 acceptance criteria were not yet connected to concrete proof paths.
  - Security and performance found no actionable Phase 3 issues.
- Round 1 fixes:
  - Changed the open-and-free publication path to use the trusted loaded Project as its source and added controller-level LKT-AOA propagation coverage.
  - Marked `FR-002`, `FR-003`, and `AC-003` through `AC-007` verified, populated their implementation/test proof paths, and added the named acceptance-criteria proof map above.
- Round 2 findings:
  - Elixir, security, performance, and requirements re-reviews found no remaining actionable Phase 3 findings.
- Round 2 fixes:
  - None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
