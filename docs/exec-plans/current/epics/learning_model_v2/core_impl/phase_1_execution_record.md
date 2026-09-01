# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/core_impl`
Phase: `1 - Operational Tables And Ecto Schemas`

## Scope from plan.md

- Add the minimal LKT-AOA operational persistence foundation without backfilling historical
  attempts.
- Add `learning_states`, `prior_activity_part_evidence`, and
  `learning_model_attempt_applications`.
- Remove the obsolete `Oli.Delivery.Attempts.PartAttemptCleaner` runtime/admin surface.
- Prove storage shape, constraints, direct PartAttempt cascade behavior, startup/router
  compatibility, and migration up/down behavior.

## Implementation Blocks

- [x] Core behavior changes
  - Added `Oli.LearningModel.LearningState`.
  - Added `Oli.LearningModel.PriorActivityPartEvidence`.
  - Added `Oli.LearningModel.AttemptApplication`.
  - Removed `Oli.Delivery.Attempts.PartAttemptCleaner`.
  - Removed the cleaner supervisor child from `Oli.Application`.
  - Removed the admin `/part_attempts` route and `OliWeb.Admin.PartAttemptsView`.
- [x] Data or interface changes
  - Added migration `20260824120000_create_learning_model_operational_tables.exs`.
  - `learning_states` uses composite primary key
    `(section_id, user_id, learning_objective_id)`, neutral defaults, standard timestamps,
    non-negative checks, and probability-range checks for `aoa` and `confidence`.
  - `prior_activity_part_evidence` uses composite primary key
    `(section_id, user_id, activity_id, part_id)`, non-empty text `part_id`, and only
    `inserted_at`.
  - `learning_model_attempt_applications` has exactly `part_attempt_id`,
    `learning_model_version`, and `applied_at`; it has no surrogate `id`, `inserted_at`,
    or `updated_at`.
  - Application claims reference `part_attempts.id` with `ON DELETE CASCADE`; no columns or
    update workflow were added to `part_attempts`.
- [x] Access-control or safety checks
  - Removed the admin cleaner surface instead of replacing it.
  - The operational schemas do not expose generic mass-assignment changesets for Section,
    user, activity, objective, or calculated model-state fields. Phase 3 bulk persistence will
    own writes, with database constraints as the enforcement boundary.
- [x] Observability or operational updates when needed
  - Migration uses `SET LOCAL lock_timeout = '5s'` in `up/0` and `down/0`, matching the
    existing data-model migration posture.
  - The new tables are empty at deploy time. The only hot-table DDL risk is bounded FK lock
    acquisition against `part_attempts`.
  - Down migration drops derived operational LKT-AOA state and would require reconstruction
    from the external audit/analytics path if LKT-AOA had already been enabled.

## Test Blocks

- [x] Tests added or updated
  - Added `test/oli/learning_model/operational_storage_test.exs`.
  - Removed obsolete cleaner and admin LiveView tests.
- [x] Required verification commands run
  - `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
  - `mix ecto.migrate`
  - `mix test test/oli/learning_model`
  - `mix ecto.rollback -n 1`
  - `mix ecto.migrate`
  - `mix compile --warnings-as-errors`
  - `mix format --check-formatted`
  - `git diff --check`
  - `rg -n "PartAttemptCleaner|PartAttemptsView|part_attempt_cleaner|/part_attempts" lib test docs/exec-plans/current/epics/learning_model_v2/core_impl`
- [x] Results captured
  - Pre-implementation work-item validation passed.
  - Initial sandboxed `mix ecto.migrate` failed before migration startup because Mix could not
    open its local PubSub TCP socket (`:eperm`). The same command succeeded with approved
    escalation.
  - Migration `up/0` succeeded locally, creating all three tables and constraints.
  - Migration `down/0` succeeded locally, dropping only the three new operational tables.
  - Final migration `up/0` succeeded, leaving the local dev database current.
  - Focused learning-model suite passed after final review hardening: 53 tests, 0 failures.
  - `mix compile --warnings-as-errors` passed.
  - `mix format --check-formatted` passed after formatting the new migration.
  - `git diff --check` passed.
  - Stale-reference scan found no runtime or test references to the removed cleaner; remaining
    matches are intentional documentation statements about its removal.
  - The focused test suite emitted an unrelated existing Inventory recovery sandbox ownership
    log during application startup, but the suite passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - PRD, FDD, informal notes, and `AC-018` now describe direct PartAttempt cascade and the
    intentional cleaner removal.
  - Phase 1 plan tasks are marked complete.
  - Phase 1 AC proof paths were added to `requirements.yml`.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop

- Round 1 findings:
  - Security/Elixir: operational schemas originally exposed generic changesets casting
    Section/user/activity/objective/model-state fields, which conflicted with the planned
    no-ordinary-mass-assignment boundary.
  - Requirements: derived-row cascade proof covered `part_attempts` but not the Section/user/resource
    FK delete rules on `learning_states` and `prior_activity_part_evidence`.
- Round 1 fixes:
  - Removed generic changeset APIs from all three operational schemas; Phase 3 bulk persistence will
    own writes.
  - Added FK delete-rule metadata assertions for all derived tables.
- Round 2 findings (optional):
  - Security, performance, Elixir, and requirements review lenses found no remaining actionable
    Phase 1 issue.
- Round 2 fixes (optional): none.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
