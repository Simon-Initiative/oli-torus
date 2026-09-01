# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/core_impl`
Phase: `3 - Atomic Bulk Application And Concurrency Safety`

## Scope from plan.md

- Implement the bounded, idempotent PostgreSQL transaction and public semantic dispatch.
- Add the public `Oli.LearningModel.apply_evaluated_attempts/2` boundary.
- Claim evaluated PartAttempts exactly once, initialize/lock learner states, capture evidence,
  replay claimed contributions, and write final states atomically.
- Prove retry, duplicate-input, concurrency, rollback, naive/no-op dispatch, and fixed operational
  query-category behavior.

## Implementation Blocks

- [x] Core behavior changes
  - Added `Oli.LearningModel.apply_evaluated_attempts/2`.
  - Added `Oli.LearningModel.LktAoa.Application`.
  - Added `test/support/learning_model_lkt_aoa_fixtures.ex` for real Section/publication/Revision
    and attempt-group setup.
  - Implemented Section model dispatch: `nil` batches return `:noop`, `:naive` Sections return
    `:skipped`, and `:lkt_aoa` Sections fetch one typed config and invoke the application service.
  - Implemented AttemptGroup validation for Section identity, evaluated lifecycle, immutable GUID,
    activity Revision, part ID, score/out-of fields, and non-null `date_evaluated`.
  - Implemented contribution normalization from exact activity Revisions, including direct objective
    extraction and activity beta extraction.
  - Implemented publication-pinned objective Revision resolution from the AttemptGroup publication.
  - Implemented deterministic in-memory replay and one final state write per affected state.
  - Normalized timestamp values returned by raw state-lock SQL back to UTC `DateTime` values before
    reusing locked state structs in `insert_all`.
- [x] Data or interface changes
  - No schema migrations were added in Phase 3.
  - The transaction uses the Phase 1 operational tables:
    `learning_model_attempt_applications`, `prior_activity_part_evidence`, and `learning_states`.
  - The claim SQL is one parameterized `INSERT ... SELECT ... ON CONFLICT DO NOTHING RETURNING`.
  - State locking is one ordered parameterized SQL query using `unnest` arrays and `FOR UPDATE`.
  - Evidence and final state persistence use set-based `Repo.insert_all/3`.
- [x] Access-control or safety checks
  - The public boundary accepts server-created `%Section{}` and `%AttemptGroup{}` values; no new
    route, controller, LiveView, client parameter, or mass-assignment surface was introduced.
  - Only PartAttempt IDs returned by the database claim may contribute.
  - Duplicate copies of the same PartAttempt inside one input batch are de-duplicated after the
    claim so they cannot double-apply.
  - Missing published objective Revisions are errors; they are not treated as untrained parameters.
  - Impossible parameter/resource mismatches continue to fail through the typed Phase 2 helpers.
- [x] Observability or operational updates when needed
  - Phase 3 does not emit custom telemetry; that remains Phase 6 scope.
  - Source comments document returned-row authority, neutral-insert-before-lock, evidence fan-out,
    and why no external I/O belongs inside the transaction.
  - Query-count coverage captures Repo query telemetry around the operation and proves the same six
    operational query categories for a single-part batch and a multi-part/multi-LO batch.

## Test Blocks

- [x] Tests added or updated
  - Added `test/oli/learning_model/lkt_aoa/application_test.exs`.
  - Added `test/oli/learning_model/lkt_aoa/concurrency_test.exs`.
  - Added `test/support/learning_model_lkt_aoa_fixtures.ex`.
- [x] Required verification commands run
  - `python3 /Users/darren/.agents/skills/harness/harness-validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
  - `mix format lib/oli/learning_model.ex lib/oli/learning_model/lkt_aoa/application.ex test/support/learning_model_lkt_aoa_fixtures.ex test/oli/learning_model/lkt_aoa/application_test.exs test/oli/learning_model/lkt_aoa/concurrency_test.exs`
  - `mix test test/oli/learning_model/lkt_aoa/application_test.exs test/oli/learning_model/lkt_aoa/concurrency_test.exs`
  - `mix test test/oli/learning_model/lkt_aoa`
  - `mix test test/oli/learning_model`
  - `mix compile --warnings-as-errors`
  - `mix format --check-formatted`
  - `git diff --check`
  - `python3 /Users/darren/.agents/skills/harness/harness-validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
- [x] Results captured
  - Pre-implementation work-item validation passed.
  - After an initial application-start table lookup failure for pre-existing `pending_uploads`,
    `MIX_ENV=test mix ecto.migrate` reported migrations already up and a no-start catalog check
    confirmed the table existed; the standalone suite rerun passed.
  - Focused Phase 3 application/concurrency suite passed after timestamp normalization at the raw
    SQL hydration boundary:
    13 tests, 0 failures.
  - Full `lkt_aoa` suite passed after Phase 3 additions: 34 tests, 0 failures.
  - Broader learning-model suite passed after Phase 3 additions: 87 tests, 0 failures.
  - `mix compile --warnings-as-errors` passed.
  - `mix format --check-formatted` passed.
  - `git diff --check` passed.
  - Initial sandboxed `mix format` failed once because Mix could not open its local PubSub TCP
    socket (`:eperm`). The same formatting command succeeded with approved escalation.
  - The broader learning-model suite emitted an unrelated existing Inventory recovery sandbox
    ownership log during application startup, but the suite passed.
  - Post-implementation work-item validation passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - Phase 3 plan tasks are marked complete.
  - Phase 3 AC proof paths were added to `requirements.yml`.
  - `AC-022` was narrowed to the Phase 3 public dispatch boundary while explicitly leaving
    Snapshot Worker call-site integration to Phase 4.
  - `AC-027` is now marked hybrid because the implementation proves one public config fetch in code
    and tests prove the LKT operation uses the public boundary/configured transition path; exact
    call count is not represented as a mockable runtime dependency.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop

- Round 1 findings:
  - Security review: clean. The new boundary accepts server-created structs, uses parameterized SQL,
    introduces no route/client input surface, does not log learner or attempt identifiers, and
    persists only compact derived state/evidence.
  - Performance review: clean after confirming all persistence boundaries are set-based and the
    query-count test proves the same operational query categories for single and bulk batches.
  - Elixir review: one correctness issue found. Raw SQL hydrated `learning_states.inserted_at` and
    `updated_at` as `NaiveDateTime`; reusing the locked structs in `Repo.insert_all/3` failed
    because the schema fields are `:utc_datetime`.
  - Requirements review: found that `AC-022` overclaimed Snapshot Worker call-site integration for
    Phase 3, even though the implementation correctly stops at the public dispatch boundary and the
    plan assigns Worker integration to Phase 4.
- Round 1 fixes:
  - Added UTC timestamp normalization in `Oli.LearningModel.LktAoa.Application.learning_state_from_row/1`.
  - Updated `AC-022` to verify the Phase 3 public boundary and document that Snapshot Worker
    call-site integration remains Phase 4 scope.
- Round 2 findings (optional):
  - Clean after the timestamp normalization fix and rerun verification.
- Round 2 fixes (optional):
  - None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
