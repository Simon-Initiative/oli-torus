# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope`
Phase: `5 - End-To-End Scenarios, Documentation Reconciliation, And Manual QA`

## Scope from plan.md

- Prove both weighted-random scopes through a real authoring, publication, section, enrollment, and delivery workflow.
- Reconcile durable epic documentation and provide reproducible manual QA guidance.

## Implementation Blocks

- [x] Core behavior changes (scenario coverage and stale scenario delivery preparation corrected)
- [x] Data or interface changes (not required)
- [x] Access-control or safety checks (participating/nonparticipating and enrollment isolation covered)
- [x] Observability or operational updates when needed (assignment/exposure evidence checked; manual evidence guidance added)

## Scenario And Manual QA Proof

- `test/scenarios/delivery/ab_testing_delivery_runtime.scenario.yaml` creates real projects, content, publication, three sections, multiple learners, and multiple enrollments without fixtures.
- `test/scenarios/delivery/ab_testing_runtime_hooks.ex` proves explicit intervention scope, default section-and-enrollment scope, canonical reuse across two placements and revisits, distinct placement exposure attribution, nonparticipating fallback, and independent canonical assignments for one user enrolled in two sections.
- The existing scenario `hook` directive was sufficient; no `extend_scenario` infrastructure change was needed.
- `manual_qa.md` records browser setup, persistence/evidence expectations, fallback, concurrency and revisit observations, evidence capture, and cleanup. The automated companion scenario executed successfully; environment-specific browser execution and screenshots remain an open Gate E handoff.

## Acceptance-Criteria Proof

- AC-001, AC-002, AC-008, AC-010: `test/oli/experiments/configuration_test.exs`, `test/oli/experiments/context_test.exs`, and `test/oli_web/live/workspaces/course_author/experiments_live_test.exs`.
- AC-003, AC-004, AC-005, AC-009: `test/scenarios/delivery/ab_testing_delivery_runtime.scenario.yaml`, `test/scenarios/delivery/ab_testing_runtime_hooks.ex`, and `test/oli/experiments/runtime_test.exs`.
- AC-006, AC-011: concurrency and bounded-query cases in `test/oli/experiments/runtime_test.exs`.
- AC-007, AC-012: scenario attribution assertions plus `test/oli/experiments/xapi_attributions_test.exs` and analytics uploader/schema tests.
- AC-013: `test/oli/experiments/persistence_test.exs`.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- Scenario schema validation through `Oli.Scenarios.validate_file/1`: passed.
- `mix test test/scenarios/delivery/ab_testing_delivery_runtime_test.exs`: 1 test, 0 failures.
- Requirements traceability and work-item validation: recorded below after final execution.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no weighted-scope design divergence; Thompson durable docs reconciled)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: security and performance reported no findings. Elixir found an empty-list assertion weakness for second-section exposures. Requirements found missing canonical-scope nonparticipation proof, an incorrect runner path, and an unsupported claim that browser manual QA was complete.
- Round 1 fixes: asserted two second-section exposures, added canonical-scope nonparticipating fallback/no-evidence proof, corrected the runner path, and left browser manual QA and Gate E explicitly incomplete.

## Done Definition

- [ ] Phase tasks complete (browser manual QA evidence remains)
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
