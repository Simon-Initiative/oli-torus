# Learning Model V2 Data Model And Configuration - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/learning_model_v2/data_model/prd.md`
- FDD: `docs/exec-plans/current/epics/learning_model_v2/data_model/fdd.md`
- Detailed decisions: `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`
- Canonical requirements: `docs/exec-plans/current/epics/learning_model_v2/data_model/requirements.yml`

## Scope

Implement the behavior-neutral persistence and configuration foundation for semantic `:naive` and `:lkt_aoa` learning models. The work adds typed shared contracts, safe database fields, explicit Project/template/Section propagation, Revision-owned versioned parameters, lifecycle preservation, project archive round trips, and validated startup coefficients.

This plan does not implement `learning_state`, evidence, proficiency/confidence calculations, Snapshot Worker processing, Metrics dispatch, UI selection, model training/upload workflows, or Authoring Insights. Existing and newly created Projects and Sections remain `:naive` throughout this work item. No feature flag is introduced because no normal product path enables LKT-AOA.

## Clarifications & Default Assumptions

- `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md` remains authoritative for complete payload examples, precedence, and default values; the FDD defines implementation boundaries.
- The shared namespace is `Oli.LearningModel`; fixed external strings are decoded through explicit matching and never dynamic atom creation.
- Project and Section enum storage is string-backed with Ecto defaults and database defaults of `"naive"` plus database check constraints.
- `revisions.learning_model_parameters` is nullable JSONB with no database default or index.
- Caller-supplied activity parameters reject unknown part IDs. Parameters inherited into a new child Revision are reconciled by pruning entries for deleted parts; new parts remain untrained.
- Standard and adaptive part membership use a centralized extractor, reusing `Oli.Activities.AdaptiveParts` where adaptive content requires it.
- Project archive export/import preserves optional `learningModelParameters` on LO and activity resource JSON in addition to Project and Product `learningModelVersion`.
- Global defaults are `gamma: 0.1`, `rho: 1.0`, `recency_decay: 0.9`, and `confidence_saturation: 3.0`. Explicit invalid overrides abort startup and name the offending variable.
- Existing Interop transactions and AppSignal/error reporting remain the operational failure boundary. Add only bounded startup configuration logging; do not add learner or high-cardinality telemetry.
- Jira remains the execution system of record, but no issue key is linked. Associate a ticket before implementation if the delivery process requires one; absence of a key does not alter technical scope.

## Phase 1: Shared Learning-Model Contracts And Startup Configuration

- Goal: Establish pure, typed contracts for model selection, v2 parameter envelopes, validation, activity-part membership, and global application settings before attaching them to Ecto schemas.
- Tasks:
  - [x] Add `Oli.LearningModel.ModelVersion` with the fixed `:naive`/`:lkt_aoa` values, semantic string encoding, and shared archive decoding with caller-supplied missing-value fallback (`FR-001`, `FR-004`, `AC-002`, `AC-011`, `AC-012`).
  - [x] Add the version-neutral `Oli.LearningModel.Parameters` envelope and v2 LO, activity, and part structs using the exact schema/model/parameter-type contract (`FR-005`, `FR-006`, `FR-007`, `AC-013`, `AC-015`, `AC-016`, `AC-019`).
  - [x] Implement `Oli.LearningModel.Parameters.Type` cast/load/dump dispatch for `nil`, typed structs, and canonical maps; reject unsupported schema/model versions and parameter types (`AC-014`, `AC-019`, `AC-020`).
  - [x] Implement centralized validation for required payload fields, finite numbers, resource-type agreement, explicit unknown part IDs, and missing-versus-zero semantics (`AC-015`, `AC-016`, `AC-017`, `AC-018`, `AC-020`).
  - [x] Add a canonical part-ID extraction/reconciliation helper for standard and adaptive activity content; preserve valid inherited entries, prune deleted parts, and leave new parts absent (`AC-017`).
  - [x] Add `Oli.LearningModel.Config` with typed access and pure parsing/validation helpers for all four coefficients (`FR-009`, `AC-025`, `AC-028`, `AC-029`).
  - [x] Declare application defaults under `config :oli, :lkt_aoa`, add the four `LKT_AOA_*` runtime overrides, and emit one bounded effective-configuration startup log (`AC-026`, `AC-027`, `AC-030`).
  - [x] Ensure parsing requires a complete finite number, applies the exact bounds, and raises with only the offending environment-variable name and validation reason.
- Testing Tasks:
  - [x] Add focused unit tests for semantic model encoding/decoding, including missing/null fallbacks and invalid external types/values.
  - [x] Add parameter codec tests for LO/activity round trips, nil, explicit zero, unsupported versions, malformed payloads, non-finite numbers, resource mismatch, standard/adaptive part validation, and inherited stale-part pruning.
  - [x] Add configuration tests for defaults, each valid override, complete-parse behavior, all bounds, non-finite inputs, and error messages.
  - [x] Exercise runtime configuration in a subprocess or isolated configuration test so environment mutation cannot leak between ExUnit tests.
  - Command(s): `mix test test/oli/learning_model`, `mix format --check-formatted`
- Definition of Done:
  - Shared modules expose the FDD interfaces, all pure validation behavior is covered, defaults and overrides are deterministic, and no Ecto schema or product UI depends on unfinished contracts.
- Gate:
  - Gate A: Learning-model contract and configuration tests pass; unsupported/malformed values cannot be silently interpreted or defaulted.
- Dependencies:
  - None.
- Parallelizable Work:
  - Model-version codec/configuration and parameter codec/validation can be developed concurrently if module ownership stays separate; merge the common namespace and tests before Phase 2.

## Phase 2: Database Migration And Ecto Schema Integration

- Goal: Persist model selection and Revision parameters safely without changing existing or newly created proficiency behavior.
- Tasks:
  - [x] Add one migration for `projects.learning_model_version`, `sections.learning_model_version`, and nullable `revisions.learning_model_parameters` using the FDD sequence (`FR-001`, `FR-003`, `FR-005`, `AC-001`, `AC-007`, `AC-013`, `AC-014`).
  - [x] Backfill Project and Section nulls to `"naive"`, retain `"naive"` database defaults, enforce non-null, and add check constraints for `"naive"`/`"lkt_aoa"`.
  - [x] Keep Revision JSONB nullable, unindexed, and without a default to avoid historical-row payload rewrites.
  - [x] Add `learning_model_version` Ecto.Enum fields and trusted-only cast support to Project and Section schemas while keeping `analytics_version` independent (`AC-001`, `AC-002`).
  - [x] Add `learning_model_parameters` through `Oli.LearningModel.Parameters.Type` to Revision schema, cast list, and validation pipeline (`AC-013`, `AC-019`, `AC-020`).
  - [x] Keep Project, Section, and database defaults at `:naive`; do not change `default_project/3` to select LKT-AOA and do not expose an authoring/delivery form field (`AC-006`, `AC-007`, `AC-030`).
  - [x] Document and inspect the generated migration plan for lock duration, rewrite risk, check-constraint behavior, and rollback safety.
- Testing Tasks:
  - [x] Add schema tests for valid/invalid enum casts, Ecto defaults, non-null persistence, database check constraints, nullable Revision parameters, and typed Revision load/dump.
  - [x] Test migration behavior against pre-existing Project and Section rows created before the migration boundary when the repository migration-test conventions permit it; otherwise add explicit post-migration SQL assertions and manual migration verification steps.
  - [x] Confirm a standard newly created Project remains `:naive` and ordinary UI payloads cannot select a learning model through general changesets.
  - Command(s): `mix test test/oli/course_test.exs test/oli/sections_test.exs test/oli/resources_test.exs test/oli/learning_model`, `mix ecto.migrate`, `mix format --check-formatted`
- Definition of Done:
  - All existing rows have explicit naive selection, schemas expose only supported values, Revision parameters load as typed values, and the migration adds no unnecessary index/default rewrite.
- Gate:
  - Gate B: Migration review is approved and schema/migration tests prove `AC-001`, `AC-002`, `AC-006`, `AC-007`, `AC-013`, `AC-014`, `AC-019`, and `AC-020`.
- Dependencies:
  - Gate A.
- Parallelizable Work:
  - Project/Section schema tests and Revision schema tests can proceed concurrently after the migration shape and shared types are fixed.

## Phase 3: Project, Template, And Section Propagation

- Goal: Explicitly copy and pin `learning_model_version` through every supported creation and duplication path.
- Tasks:
  - [x] Update Project-to-blueprint creation in `Oli.Delivery.Sections.Blueprint.build_blueprint_attrs/4` to copy the Project value (`FR-002`, `AC-003`).
  - [x] Update Project/publication-to-Section creation in `Oli.Delivery.create_new_section/4` to copy the Project value (`AC-003`).
  - [x] Update blueprint-to-Section creation to copy the blueprint value rather than deriving it from the base Project (`AC-003`, `AC-005`).
  - [x] Update `Oli.Authoring.Clone.clone_project/3` to copy the source Project value (`AC-004`).
  - [x] Audit `Oli.Delivery.Sections.Blueprint.duplicate/3`, open-and-free creation, seed/scenario helpers, and any explicit Section copy maps; make source preservation explicit where current `Map.from_struct/1` behavior is otherwise incidental (`AC-004`).
  - [x] Ensure source Project/template updates never write through to an existing Section and no ordinary Section edit path exposes model mutation (`AC-005`, `AC-030`).
  - [x] Preserve `:naive` for all ordinary new-Project workflows while allowing trusted tests/setup to create explicit `:lkt_aoa` sources (`FR-003`, `AC-006`).
- Testing Tasks:
  - [x] Extend Course, Clone, Delivery, and Blueprint tests for Project-to-blueprint, Project-to-Section, blueprint-to-Section, Project clone, blueprint duplicate, and enrollable Section duplicate behavior.
  - [x] Test a blueprint whose model differs from its base Project and prove the created Section follows the blueprint.
  - [x] Change a Project/blueprint after Section creation and prove the Section remains pinned.
  - [x] Add one scenario-level Project-to-publication-to-blueprint-to-Section propagation test only if current `Oli.Scenarios` directives can express the field setup/assertions without extending the framework; otherwise retain focused domain integration coverage.
  - Command(s): `mix test test/oli/course_test.exs test/oli/clone_test.exs test/oli/delivery_test.exs test/oli/delivery/sections/blueprint_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - Every production creation/duplication entry point copies its immediate source selection explicitly, and existing Section values remain stable after source changes.
- Gate:
  - Gate C: Propagation tests prove `AC-003`, `AC-004`, `AC-005`, and continued staged-rollout behavior under `AC-006`/`AC-007`.
- Dependencies:
  - Gate B.
- Parallelizable Work:
  - Project clone coverage and Delivery/Blueprint propagation can be implemented concurrently after the schema field exists.

## Phase 4: Revision Lifecycle And Publication Preservation

- Goal: Preserve typed parameter envelopes through every Revision copy/duplication path and prove publication-pinned resolution.
- Tasks:
  - [x] Add `learning_model_parameters` to `Oli.Resources.create_revision_from_previous/2`, with caller replacements taking precedence over inherited values (`FR-008`, `AC-021`).
  - [x] Apply inherited activity-part reconciliation against the candidate child content before Revision insertion; use strict validation for explicitly supplied replacement payloads (`AC-017`, `AC-021`).
  - [x] Add the field to `Oli.Authoring.Editing.AdaptiveDuplication.build_revision_row/5` and audit other explicit activity/package Revision row builders (`AC-022`).
  - [x] Verify `Oli.Publishing.UniqueIds.add_revisions/1` preserves the newly loaded schema field through its struct-copy/drop approach and protect that behavior with a regression test (`AC-022`).
  - [x] Verify Project cloning's shared published-Revision references preserve parameters without creating or mutating Revision rows (`AC-022`).
  - [x] Prove publication and delivery resolution use the exact parameterized Revision pinned by `PublishedResource`, not the latest authoring Revision (`AC-023`).
  - [x] Ensure no Publication, Project, Section, or learner-state row duplicates the parameter envelope.
- Testing Tasks:
  - [x] Extend `test/oli/resources_test.exs` for inherited, replaced, missing, explicit-zero, stale-pruned, and newly untrained parameters.
  - [x] Add adaptive duplication and unique-ID recreation tests with non-empty activity parameter maps.
  - [x] Add publication resolution coverage that publishes parameters, creates a newer differing authoring Revision, and resolves the original publication's values.
  - [x] Run clone/duplication regression coverage to ensure no parameter loss or mutation.
  - Command(s): `mix test test/oli/resources_test.exs test/oli/publishing_test.exs test/oli/clone_test.exs test/oli/authoring/editing/adaptive_duplication_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - Child Revisions, adaptive/package copies, Project clones, unique-ID rewrites, and published resolution preserve the correct typed parameter envelope without modifying historical Revisions.
- Gate:
  - Gate D: Lifecycle tests prove `AC-017`, `AC-018`, `AC-021`, `AC-022`, and `AC-023` across changeset and bulk-copy paths.
- Dependencies:
  - Gate B. Phase 3 is not a code dependency, but Gate C should complete before final integration to avoid overlapping copy-path edits.
- Parallelizable Work:
  - Resource copy/reconciliation and publication-resolution tests can proceed concurrently; coordinate any shared factory/helper changes.

## Phase 5: Project Archive Preservation And Legacy Compatibility

- Goal: Preserve exact Project/template model selection and supported LO/activity parameter envelopes across export/import, including deterministic legacy fallbacks and invalid-input failures.
- Tasks:
  - [x] Add encoded `learningModelVersion` to `_project.json` in `Oli.Interop.Export.create_project_file/1` (`FR-004`, `AC-008`).
  - [x] Add each blueprint Section's own encoded `learningModelVersion` to `_product-<id>.json` without deriving from its Project or adding queries (`AC-009`).
  - [x] Decode Project selection through `ModelVersion.decode_archive/2` with `:naive` fallback and pass it through a trusted archive-specific Project creation boundary (`AC-010`, `AC-011`, `AC-012`).
  - [x] Decode Product selection with the imported Project value as fallback, add it to `new_product_attrs`, and copy it through an archive-specific Blueprint creation boundary (`AC-010`, `AC-011`, `AC-012`).
  - [x] Export optional canonical `learningModelParameters` on LO and activity resource JSON from already-loaded Revisions (`FR-008`, `AC-024`).
  - [x] Decode and validate LO/activity parameter envelopes before objective/activity `Repo.insert_all/3`; attach actionable resource/file context to failures and roll back ingest (`AC-015`, `AC-016`, `AC-020`, `AC-024`).
  - [x] Keep absent parameter properties as `nil`; preserve explicit stored `0.0`; do not reuse or overwrite generic objective `parameters` (`AC-014`, `AC-018`).
  - [x] Confirm no per-Product or per-resource query/preload is added to export.
- Testing Tasks:
  - [x] Add direct export JSON assertions for Project, Product, LO, and activity properties.
  - [x] Add modern full round trips for `:lkt_aoa`, a Product value differing from its Project, LO/activity envelopes, multiple activity parts, and explicit zero.
  - [x] Add legacy archives with neither selection property, a Project property but no Product property, null values, and absent resource parameters.
  - [x] Add invalid explicit selection type/value, unsupported envelope version, resource-type mismatch, non-finite coefficient, and unknown activity-part cases; assert actionable rollback errors.
  - [x] Add a query-count assertion and code inspection proving Product/resource export remains set-based.
  - Command(s): `mix test test/oli/interop/export_test.exs test/oli/interop/ingest_test.exs test/oli/interop/ingest/scalable_ingest_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - Export/import faithfully preserves all in-scope model data, legacy archives remain importable under documented precedence, invalid explicit data never silently defaults, and export query behavior is unchanged.
- Gate:
  - Gate E: Interop tests prove `AC-008` through `AC-012`, `AC-014` through `AC-016`, `AC-018`, `AC-020`, and `AC-024`.
- Dependencies:
  - Gates B, C, and D.
- Parallelizable Work:
  - Export encoding/tests and ingest decoding/tests can proceed concurrently once archive property names and shared codecs are fixed; integrate them before round-trip tests.

## Phase 6: Integrated Verification, Operational Review, And Handoff

- Goal: Verify the complete data-model slice as one behavior-neutral change and prepare it for review and later `core_impl`/`usage` consumers.
- Tasks:
  - [x] Run all targeted suites from prior phases together and fix cross-boundary regressions.
  - [x] Run the broader relevant authoring, delivery, Resources, Publishing, and Interop test directories as risk warrants.
  - [x] Execute a clean migration on representative existing data and verify every Project/Section is non-null `:naive`, both check constraints hold, and historical Revisions remain readable.
  - [x] Manually export/import a Project with a divergent Product and populated LO/activity parameters; inspect archive JSON and imported records.
  - [x] Start the application with defaults, representative overrides, and one invalid override; confirm effective startup logging and controlled startup failure (`AC-025` through `AC-029`).
  - [x] Confirm no normal authoring or delivery UI exposes model selection and no runtime/per-Project coefficient editor exists (`AC-006`, `AC-030`).
  - [x] Confirm existing proficiency behavior remains naive and no `learning_state`, evidence, Snapshot Worker, Metrics, or Insights implementation entered this PR (`FR-003`, `AC-007`).
  - [x] Run formatting, compilation, requirements traceability, and work-item validation gates.
  - [x] Review the final diff using `.review/elixir.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md`; record any Jira association in the PR/work item without inventing a ticket.
  - [x] Document the stable interfaces needed by the later `core_impl` and `usage` work items: Section dispatch field, publication-pinned parameter access, cold-start semantics, and `Oli.LearningModel.Config.fetch!/0`.
- Testing Tasks:
  - [x] Run all relevant backend tests with intentional application logs captured according to repository test policy.
  - [x] Run `mix compile --warnings-as-errors` in the appropriate test environment.
  - [x] Run Harness requirements and work-item validators after implementation proof paths are populated.
  - Command(s): `mix test test/oli/learning_model test/oli/course_test.exs test/oli/clone_test.exs test/oli/delivery_test.exs test/oli/delivery/sections/blueprint_test.exs test/oli/resources_test.exs test/oli/publishing_test.exs test/oli/interop`, `mix format --check-formatted`, `mix compile --warnings-as-errors`, `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/learning_model_v2/data_model --action master_validate --stage implementation`, `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/data_model --check all`
- Definition of Done:
  - `FR-001` through `FR-009` and `AC-001` through `AC-030` have automated or documented hybrid proof, migrations are production-safe, all selected review lenses are clean, and later chunks can consume stable typed contracts without reinterpreting JSON or inferring model selection.
- Gate:
  - Gate F: All automated and manual verification passes; no blocking security, performance, requirements, migration, compatibility, or observability finding remains.
- Dependencies:
  - Gates A through E.
- Parallelizable Work:
  - Manual archive/configuration checks, requirements proof reconciliation, and review-lens preparation can run concurrently after the integrated automated suite passes.

## Parallelization Notes

- Phase 1's model-version/config work can run independently from parameter structs/codec work, but their shared namespace and error conventions must be reconciled before Gate A.
- After Gate B, Phase 3 propagation and most of Phase 4 lifecycle work are safe to run concurrently because they primarily touch different modules. Coordinate `Blueprint` and shared test-helper edits.
- Phase 5 export and ingest halves can run concurrently after codecs and archive names are fixed. Full round-trip tests are the integration point.
- Do not parallelize multiple migrations that alter the same tables, or multiple implementations of parameter validation. One migration sequence and one validator must remain authoritative.
- Avoid broad factory/seeder changes merely to force explicit LKT-AOA values. Defaults should continue producing naive records; targeted tests should opt in explicitly.

## Phase Gate Summary

- Gate A: Shared codecs, typed parameter contracts, part reconciliation, and startup configuration are complete and unit-tested.
- Gate B: Production-safe columns, backfills, constraints, Ecto fields, and typed Revision persistence are complete.
- Gate C: All Project/template/Section creation and duplication paths explicitly propagate and pin model selection.
- Gate D: Revision creation, bulk-copy/duplication, cloning, and publication resolution preserve parameters correctly.
- Gate E: Project archive export/import preserves selection and parameters with exact legacy/error semantics and no query regression.
- Gate F: Integrated tests, migration/configuration checks, formatting, compilation, requirements validation, and required review lenses pass.
