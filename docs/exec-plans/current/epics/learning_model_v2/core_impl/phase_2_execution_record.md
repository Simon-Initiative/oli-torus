# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/core_impl`
Phase: `2 - Pure Contribution Normalization And Transition Math`

## Scope from plan.md

- Implement deterministic, independently testable LKT-AOA model math and input normalization before
  introducing transactional persistence.
- Normalize part-attempt contributions from activity/objective metadata without a Repo dependency.
- Extract typed beta parameters from pinned Revision data with documented `0.0` cold-start behavior.
- Replay contributions per learner/objective state by `date_evaluated ASC, attempt_guid ASC`.
- Keep runtime configuration explicit by passing `Oli.LearningModel.Config` into pure logic.

## Implementation Blocks

- [x] Core behavior changes
  - Added `Oli.LearningModel.LktAoa.Contribution`.
  - Added `Oli.LearningModel.LktAoa.Transition`.
  - Added `Oli.LearningModel.LktAoa.BatchResult`.
  - Implemented direct-objective extraction for legacy list and per-part map Summary shapes.
  - Implemented same-evidence mapping consistency validation so one activity part cannot be
    associated with conflicting objective sets inside a batch.
  - Implemented binary outcome semantics from `score == out_of`; partial credit is treated as
    incorrect and xAPI success is intentionally not used.
  - Implemented confidence breadth fanout from newly inserted evidence keys to every targeted
    learner/objective state.
- [x] Data or interface changes
  - No database schema changes were introduced in Phase 2.
  - `Contribution` is the internal typed representation used by later persistence work.
  - `BatchResult` is aggregate-only and intentionally excludes learner IDs, attempt GUIDs,
    responses, and parameter payloads so it is safe for worker control flow and telemetry.
- [x] Access-control or safety checks
  - Phase 2 code is pure and does not introduce routes, authorization boundaries, mass-assignment
    paths, SQL, or external writes.
  - Activity and learning-objective beta extraction requires typed `Oli.LearningModel.Parameters`
    envelopes and verifies the Revision resource type before using parameter payloads.
  - Missing parameter envelopes and missing activity-part entries resolve to the documented
    cold-start `0.0`; impossible resource/payload mismatches return controlled errors.
- [x] Observability or operational updates when needed
  - No telemetry is emitted in Phase 2. `BatchResult` defines the bounded aggregate shape that
    Phase 3/6 worker code can use for telemetry without leaking learner- or attempt-level data.
  - Source comments document predict-before-outcome ordering, stable logistic forms, direct-objective
    scope, deterministic tie breaking, and the intentional absence of cross-job chronology repair.

## Test Blocks

- [x] Tests added or updated
  - Added `test/oli/learning_model/lkt_aoa/transition_test.exs`.
  - Added `test/oli/learning_model/lkt_aoa/contribution_test.exs`.
- [x] Required verification commands run
  - `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
  - `mix format lib/oli/learning_model/lkt_aoa/contribution.ex lib/oli/learning_model/lkt_aoa/transition.ex lib/oli/learning_model/lkt_aoa/batch_result.ex test/oli/learning_model/lkt_aoa/contribution_test.exs test/oli/learning_model/lkt_aoa/transition_test.exs`
  - `mix test test/oli/learning_model/lkt_aoa/transition_test.exs test/oli/learning_model/lkt_aoa/contribution_test.exs`
  - `mix test test/oli/learning_model`
  - `mix compile --warnings-as-errors`
  - `mix format --check-formatted`
  - `git diff --check`
  - `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
  - `rg -n "Repo|Application\\.get_env|Application\\.fetch_env|System\\.get_env|System\\.fetch_env|insert_all|update_all|transaction" lib/oli/learning_model/lkt_aoa test/oli/learning_model/lkt_aoa`
- [x] Results captured
  - Pre-implementation work-item validation passed.
  - Focused Phase 2 suite passed: 21 tests, 0 failures.
  - Focused learning-model suite passed after Phase 2 additions: 74 tests, 0 failures.
  - `mix compile --warnings-as-errors` passed.
  - `mix format --check-formatted` passed.
  - `git diff --check` passed.
  - Final work-item validation passed.
  - Pure-boundary scan found no Repo/config/env/runtime writes in Phase 2 logic; the only match is
    the module comment documenting that boundary.
  - The broader learning-model suite emitted an unrelated existing Inventory recovery sandbox
    ownership log during application startup, but the suite passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - Phase 2 plan tasks are marked complete.
  - Gate B now states that Phase 2 proves contribution normalization for `AC-012`, while the
    public collection-oriented operation remains Phase 3 scope.
  - Phase 2 AC proof paths were added to `requirements.yml`.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop

- Round 1 findings:
  - Security review: no findings. Phase 2 adds no routes, authorization boundaries, SQL, external
    I/O, mass-assignment paths, secrets, or learner/attempt-level telemetry output.
  - Performance review: no findings. Phase 2 adds pure in-memory normalization and per-state replay;
    no queries, query loops, unbounded task fanout, hot delivery reads, or new indexes are involved.
  - Elixir review: no findings. Modules are cohesive, typed, documented, and return controlled errors
    for expected invalid contribution/parameter shapes.
  - Requirements review: no findings. Phase 2 proofs cover the completed pure transition and
    contribution-normalization criteria without claiming Phase 3 transactional/public-operation scope.
- Round 1 fixes:
  - None required.
- Round 2 findings (optional):
  - Not needed.
- Round 2 fixes (optional):
  - None.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
