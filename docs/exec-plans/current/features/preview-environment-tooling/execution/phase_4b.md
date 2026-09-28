# Phase 4B Execution Record

## Scope

Phase 4B replaces the Phase 4 `simulate_progress` contract with a small fixed-profile course
simulator. The implementation retains authentic learner lifecycles, deterministic seeded variation,
fast and paced modes, native activity coverage, development/preview seed entry points, and a
dedicated seeding runtime.

## Implemented

- Added shared `LearnerActions` and `Responses` boundaries for real visit, evaluate, hint, reset,
  save, and finalize behavior across the five supported native activity types.
- Added four fixed behavior profiles with course reach, activity participation, initial correctness,
  practice/assessment attempt counts, and simple per-attempt improvement.
- Added count-based cohort assignment, enrollment validation, a 100-learner cap, normal task-stream
  fast concurrency with slight deterministic action delays, and one concurrent worker per admitted
  learner in paced mode.
- Added realistic fixed timing distributions and a small `Pacing` module that sleeps directly in
  learner workers during paced mode.
- Added one deterministic UUIDv5 DataShop identifier per learner/section simulation.
- Changed rerun behavior to skip and report learners with existing section history.
- Kept compact aggregate results and unsupported-content warnings.
- Retained `Oli.Seeding.Runtime`, development `mix seed`, and preview `bin/seed`.

## Removed During Simplification

- `ProgressSimulation.Limits`, `ActionRunner`, `Bounds`, and `Reporter`.
- Per-action supervised tasks, cumulative active-work timeouts, action budgets, token-bucket rates,
  and simulator backpressure polling.
- Central paced scheduling, retained-wait memory benchmarks, rich progress/lag telemetry, course
  content envelopes, ETS sharing, and content fingerprints.
- Profile versions, arbitrary behavior/timing overrides, explicit-user cohorts, objective
  remediation, and learning-state machinery.
- Multi-session DataShop rotation and lower-level directive session state.
- Cooperative cancellation tokens, signal translation, partial interruption summaries, and
  simulator cleanup. The foreground VM now exits directly when terminated.
- Existing-history rejection and any proposed resume/reconciliation behavior.

## Automated Evidence

- Focused parser, policy, response, session, pacing, runtime, CLI, and directive coverage passes:
  `78 tests, 0 failures`.
- The broader scenario validation/directive regression suite passes: `135 tests, 0 failures`.
- The complete backend regression suite passes: `26 doctests, 8,981 tests, 0 failures`
  (`75 excluded`).
- The canonical progress scenario passes against real delivery/evaluation/grading lifecycles,
  including all five native activity types, both multi-input modes, practice retries/hints, repeated
  assessments, and per-attempt improvement.
- Existing-history skip behavior is covered with a mixed population in which fresh learners
  continue, and failed directives retain their structured simulation result for CLI reporting.
- Parser/schema parity covers the explicit 100-learner boundary. A small architecture-invariant
  test covers default fast concurrency with slight action delays, concurrent paced learner journeys,
  and the absence of simulator-owned Oban, limiter, per-action runner, or cancellation dependencies.
- JSON schema parses successfully and `mix compile` succeeds without simulator warnings after
  formatting.

## Review Evidence

- Elixir review identified result loss on the handler error path and parser/schema cap drift; both
  were corrected and covered. Its follow-up found nested `use` propagation also needed the new
  error-state tuple; the include handler now preserves the summary and restores parent include
  context, with a failing included-scenario regression test.
- Requirements review identified stale migration guidance, interruption/history failure semantics,
  Phase 4B gate language, and automated-versus-hybrid proof classification; all were reconciled.
- Performance review identified quadratic page indexing and repeated assessment-settings reads;
  traversal now iterates the selected prefix directly, passes the current page through assessment
  retries, and reuses settings across retries.
- Performance suggestions to restore an action limiter, ETS course sharing, content bounds, or a
  paced coordinator per learner were not adopted because they contradict the approved small fixed
  learner-worker design and defer optimization until observed need.
- Security review found no authorization, scoping, exposure, or worker-lifecycle regression.

## Deferred Phase 8 Hybrid Checks

- Run a staged copy through preview `bin/seed` next to a preview server.
- Observe a longer paced run, then terminate the foreground command and verify that the VM and
  learner workers stop while the server remains healthy and committed data remains visible.

See `docs/exec-plans/current/features/preview-environment-tooling/execution/phase_4b_manual_qa.md`
for commands and expected observations. These checks are part of Phase 8 integrated verification
and do not block the Phase 4B implementation gate.
