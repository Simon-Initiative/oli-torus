# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/data_model`
Phase: `2`

## Scope from plan.md

- Persist Project and Section model selection and optional typed Revision parameters.
- Keep defaults behavior-neutral and leave propagation, lifecycle copying, and Interop changes to later phases.

## Implementation Blocks

- [x] Core behavior changes
  - Added explicit semantic model selection to Project and Section schemas while keeping `analytics_version` independent.
  - Added optional typed learning-model parameter persistence and Revision-aware validation.
- [x] Data or interface changes
  - Added one migration covering `projects.learning_model_version`, `sections.learning_model_version`, and `revisions.learning_model_parameters`.
  - Project and Section expose narrowly scoped `trusted_learning_model_changeset/2` functions for later propagation/import phases; general UI-facing changesets do not cast the field.
- [x] Access-control or safety checks
  - Database non-null and check constraints reject missing or unsupported model selections.
  - Ecto enums reject unsupported values, and Revision changesets reject invalid envelopes, resource-type mismatches, and unknown activity parts.
  - General Project and Section changesets explicitly ignore crafted `learning_model_version` input.
- [x] Observability or operational updates when needed
  - No runtime telemetry was required. Migration lock acquisition is bounded by a transaction-local five-second `lock_timeout`.

## Test Blocks

- [x] Tests added or updated
  - Added 13 database-backed schema/migration integration tests.
  - Covered enum values, trusted casting, ordinary-payload rejection, Ecto defaults, ordinary Project creation, database defaults/nullability/check constraints, nullable unindexed JSONB, typed LO/activity persistence, explicit zero, nil, mismatch, unknown parts, and unsupported envelopes.
  - Hardened the Phase 1 startup-log test so it explicitly raises and restores the test Logger level.
- [x] Required verification commands run
  - `mix test test/oli/learning_model/schema_integration_test.exs` — 13 tests, 0 failures.
  - `mix test test/oli/course_test.exs test/oli/sections_test.exs test/oli/resources_test.exs test/oli/learning_model` — 156 tests, 0 failures in the final run.
  - `mix compile --warnings-as-errors` — passed.
  - `mix format --check-formatted` — passed at final verification.
  - `git diff --check` — passed at final verification.
- [x] Results captured
  - The developer reset applied the migration successfully to the local environment.
  - Post-migration SQL assertions prove both selection columns are non-null with `naive` defaults, have the expected check constraints, and contain no null rows.
  - SQL catalog assertions prove Revision parameter storage is nullable JSONB without a default or index.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No requirement changed. `plan.md` now clarifies that schema cast support is trusted-only and marks Phase 2 complete.
- [x] Open questions added to docs when needed
  - No new blocking question was introduced.

## Migration Safety Review

- The migration remains transactional. A lock timeout rolls the entire attempt back, after which deployment may retry safely when table activity is lower.
- Adding constant defaults to the small Project and Section tables is metadata-only on the supported PostgreSQL release. The explicit null updates preserve the required backfill semantics.
- Setting non-null and validating check constraints may scan and briefly lock Project and Section tables; these are much smaller than learner-attempt and Revision tables.
- Adding nullable `revisions.learning_model_parameters` without a default or index is a metadata-only catalog change and does not rewrite historical Revision rows. It still requires an `ACCESS EXCLUSIVE` lock, whose acquisition is bounded to five seconds.
- No concurrent index build is needed because neither field is queried by coefficient content or used as a new lookup key.
- Rollback removes the constraints and all three columns. It is structurally safe but intentionally discards any model selection or parameter data written after deployment; production rollback must therefore occur before enabling later write paths or must first preserve that data externally.
- This repository has no migration-boundary test convention that replays a migration over seeded legacy rows inside ExUnit. The completed clean migration plus post-migration catalog/data assertions are the documented Phase 2 proof path.

## Review Loop

- Round 1 findings:
  - Elixir/security/requirements: general Project and Section changesets made model selection mass-assignable through ordinary form payloads.
  - Performance: the `revisions` DDL lock could wait indefinitely and queue application traffic.
  - Security residual: parameter envelopes have no cardinality or part-ID length cap.
  - Requirements/process: migration safety and legacy-row proof needed explicit documentation.
- Round 1 fixes:
  - Removed model selection from general changesets, introduced documented trusted-only changesets, and added negative mass-assignment tests.
  - Added a five-second transaction-local `lock_timeout` in both migration directions and documented retry/rollback behavior.
  - Completed the migration-safety and post-migration verification record above.
  - Did not invent a parameter-size restriction: requirements review confirmed that any cap changes the approved non-empty-string/cardinality contract and needs a separate approved design update.
- Round 2 findings:
  - Elixir, performance, security, and requirements re-reviews found no remaining actionable Phase 2 findings.
  - Parameter payload size remains a documented residual contract decision, not an implementation defect under the current requirements.
- Round 2 fixes:
  - None required by the completed Round 2 lenses.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
