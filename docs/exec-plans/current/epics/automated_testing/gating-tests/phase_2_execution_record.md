# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/automated_testing/gating-tests`
Phase: `2`

## Scope from plan.md
- Add the core `Oli.Scenarios` infrastructure needed to express advanced gating and scheduling workflows in YAML.
- Implement parser, validator, engine, handler, schema, and time-control changes for `gate`, `time`, `visit_page`, and `assert.gating` shape support.
- Preserve backward compatibility for existing `view_practice_page` scenarios while enabling generalized page-visit behavior.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [ ] Observability or operational updates when needed
Notes:
- Added first-class scenario directive support for `gate`, `time`, and `visit_page`.
- Extended `ExecutionState` and engine routing to store named gates and scenario-local clock state.
- Implemented `GateHandler` to create top-level gates and student exceptions through `Oli.Delivery.Gating.create_gating_condition/1`, then refresh the section gating index.
- Implemented `TimeHandler` and updated `Oli.DateTime` so scenario execution can control clock-dependent schedule evaluation deterministically.
- Implemented `VisitPageHandler` as a generalized learner page-start directive and kept `view_practice_page` backward compatible by delegating to the new visit path.
- Updated schedule gating to use `Oli.DateTime.utc_now()` instead of direct wall-clock calls.
- Added parser, validator, and schema support for `assert.gating` shape validation, but left assertion execution itself for Phase 3. `AssertHandler` currently returns an explicit Phase 3 placeholder error if `assert.gating` is executed.

Key files changed:
- `lib/oli/datetime.ex`
- `lib/oli/delivery/gating/condition_types/schedule.ex`
- `lib/oli/scenarios/directive_parser.ex`
- `lib/oli/scenarios/directive_types.ex`
- `lib/oli/scenarios/directive_validator.ex`
- `lib/oli/scenarios/directives/assert_handler.ex`
- `lib/oli/scenarios/directives/gate_handler.ex`
- `lib/oli/scenarios/directives/time_handler.ex`
- `lib/oli/scenarios/directives/visit_page_handler.ex`
- `lib/oli/scenarios/directives/view_practice_page_handler.ex`
- `lib/oli/scenarios/engine.ex`
- `priv/schemas/v0-1-0/scenario.schema.json`

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured
Tests added or updated:
- `test/scenarios/validation/invalid_attributes_test.exs`
- `test/scenarios/validation/schema_validation_test.exs`
- `test/scenarios/directives/gate_handler_test.exs`
- `test/scenarios/directives/visit_page_handler_test.exs`

Verification:
- `mix test test/scenarios/validation/invalid_attributes_test.exs test/scenarios/validation/schema_validation_test.exs test/scenarios/directives/gate_handler_test.exs test/scenarios/directives/visit_page_handler_test.exs`
- `mix test test/oli/delivery/gating/strategies/schedule_test.exs test/oli/delivery/gating_test.exs`
- `mix test test/scenarios/validation/invalid_attributes_test.exs test/scenarios/validation/schema_validation_test.exs test/scenarios/directives/gate_handler_test.exs test/scenarios/directives/visit_page_handler_test.exs test/oli/delivery/gating/strategies/schedule_test.exs test/oli/delivery/gating_test.exs`

Results:
- Targeted scenario validation and directive tests passed.
- Targeted delivery gating regression tests passed after updating shared time access to tolerate test environments without explicit mock expectations.
- Combined regression slice passed: `59 tests, 0 failures`.
- Test output included an unrelated background `Inventory recovery failed` sandbox ownership log during shutdown. It did not fail the run and did not originate from the changed scenario/gating code paths in this phase.

## Work-Item Sync
- [ ] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
Notes:
- No `prd.md` or `fdd.md` exists for this work item, and Phase 2 stayed aligned with `plan.md`.
- Added this execution record as the durable implementation artifact for the phase.
- The user explicitly instructed that validation gates should be ignored for this and future phases, so no harness validation commands were run as a completion gate.

## Review Loop
- Round 1 findings: No dedicated `harness-review` round was run in this phase.
- Round 1 fixes: N/A
- Round 2 findings (optional): N/A
- Round 2 fixes (optional): N/A
Notes:
- Repository policy normally enables code review, but this phase was completed without a separate harness review pass.
- Residual risk is concentrated in cross-cutting scenario/runtime behavior that was not examined through the dedicated security/performance review checklists.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [ ] Review completed when enabled
- [ ] Validation passes
Notes:
- Phase 2 delivered the planned core scenario infrastructure for gating and deterministic time control.
- Phase 3 remains required to implement executable `assert.gating` behavior.
- Validation gates were intentionally skipped per user instruction.
