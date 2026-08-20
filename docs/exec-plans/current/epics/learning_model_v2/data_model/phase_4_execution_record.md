# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/data_model`
Phase: `4`

## Scope from plan.md

- Preserve typed learning-model parameter envelopes through Revision creation, copy-on-write, adaptive duplication, unique-ID recreation, and Project cloning.
- Reconcile inherited activity-part parameters against child content while strictly validating explicit replacements.
- Prove delivery resolves parameters from publication-pinned Revisions rather than mutable authoring HEAD.

## Implementation Blocks

- [x] Core behavior changes
  - `Oli.Resources.create_revision_from_previous/2` now inherits `learning_model_parameters`, honors an explicit replacement or explicit `nil`, and reconciles only inherited activity parameters against the candidate child content.
  - Activity Editor copy-on-write now delegates to the central child-Revision constructor instead of maintaining a partial Revision field map.
  - Activity Editor reconciles implicitly inherited parameters against the final recombined content before persisting an edit; explicit replacements remain strict.
  - Standard embedded-activity/page duplication passes the typed envelope through the activity creation boundary, including nested activity references.
  - Adaptive screen bulk duplication explicitly includes the typed parameter envelope.
- [x] Data or interface changes
  - No schema or migration changed. Parameters remain owned only by exact Revision rows.
  - Unique-ID recreation continues copying the complete loaded Revision struct, and Project cloning continues sharing exact Revision IDs through new `PublishedResource` rows.
- [x] Access-control or safety checks
  - Caller-supplied replacement payloads pass the existing strict Revision changeset validation; inherited payloads alone receive stale-part pruning.
  - Explicit zero remains trained data, explicit `nil` clears inherited data, and newly added parts remain absent/untrained.
- [x] Observability or operational updates when needed
  - No new runtime logging or telemetry is needed for deterministic content-copy behavior.

## Test Blocks

- [x] Tests added or updated
  - Added child-Revision coverage for inherited, replaced, cleared, missing, explicit-zero, stale-pruned, newly untrained, and invalid explicit activity parameters.
  - Added non-empty parameter preservation assertions for adaptive duplication and unique-ID Revision recreation.
  - Added Project clone coverage proving the clone references the exact same parameterized Revision without mutation.
  - Added a publication-resolution integration test proving authoring resolves a newer parameterized Revision while delivery continues resolving the older Revision pinned to its published Section.
  - Added standard page-duplication coverage for top-level and nested parameterized activities.
  - Added a real Activity Editor copy-on-write test proving a deleted part is pruned, a retained coefficient survives, and a new part remains untrained.
- [x] Required verification commands run
  - `mix test test/oli/resources_test.exs test/oli/publishing_test.exs test/oli/clone_test.exs test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/publishing/unique_ids_test.exs test/oli/editing/activity_editor_test.exs test/oli/editing/container_editor_test.exs` — 128 tests, 0 failures.
- [x] Results captured
  - Focused tests prove both typed custom-field dumping through `Repo.insert_all/3` paths and normal changeset persistence.

## Acceptance-Criteria Proof Map

- `AC-017`: `ResourcesTest` test "reconciles inherited parts against child content without training new parts", its strict replacement test, and `ActivityEditingTest` test "copy-on-write edits reconcile inherited parameters with the final activity parts".
- `AC-018`: `ResourcesTest` tests "an explicit replacement takes precedence and preserves zero" and "an explicit nil clears inherited parameters and missing parameters remain nil".
- `AC-021`: the complete `create_revision_from_previous/2 learning-model parameters` test group.
- `AC-022`: `ActivityEditingTest` test "copy-on-write edits reconcile inherited parameters with the final activity parts", `ContainerEditorTest` test "duplicate_page/1 duplicates a page correctly", `AdaptiveDuplicationTest` test "duplicates adaptive screen resources and returns deterministic mappings", `UniqueIdsTest` test "adds unique ids to content revisions in which id's have not already been added to", and `CloneTest` test "clone_project/2 shares exact parameterized published Revisions".
- `AC-023`: `PublishingTest` test "delivery resolves the published Revision after authoring advances".

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No requirement or design decision changed. Phase 4 tasks are marked complete. Review expanded the Activity Editor audit to cover its final-content update boundary and the standard page/activity deep-copy boundary.
- [x] Open questions added to docs when needed
  - No new open question was introduced.

## Review Loop

- Round 1 findings: Elixir and requirements reviews found that standard embedded-activity duplication omitted parameters and that Activity Editor reconciled a copy-on-write child against old rather than final content. Security and performance reviews were clean.
- Round 1 fixes: propagated parameters through standard activity creation/deep copy; reconciled implicit parameters after Activity Editor recombines final content; added direct standard-duplication and copy-on-write regression tests.
- Round 2 findings: Elixir, requirements, security, and performance reviews found no remaining behavioral issue. Requirements review requested that the decisive Activity Editor and Container Editor artifacts be added to the verified AC proof lists.
- Round 2 fixes: added the missing `AC-017` and `AC-022` proof paths to `requirements.yml`; final requirements check was clean.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
