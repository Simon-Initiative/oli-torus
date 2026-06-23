# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/core`
Phase: `6 - Integration review, observability, and final verification`

## Scope from plan.md
- Verify cross-cutting requirements for delivery performance, authorization, stale-row tolerance, backwards compatibility, and attempt consistency.
- Reconcile implementation docs and record proof for acceptance criteria.
- Keep the core transport-independent for later Instructor Preview UI work.

## Integration Notes
- No Instructor Preview transport or UI adapter was added in this core slice.
- Future UI/preview integration should confirm the active Instructor Preview owner and remain transport-independent.
- Delivery realization still loads page exclusions once in hierarchy creation and then uses `%PageExclusions{}` in memory through the provider path.
- Phase 2 kept explicit error tuples rather than adding new telemetry events; no new logs/events expose learner data.

## Review Passes
- Security review: no new routes, params-driven SQL, atom creation from user input, secrets, or client-side trust boundary. Scenario writes delegate to `Oli.Delivery.InstructorCustomizations` authorization.
- Performance review: no new queries in delivery loops; candidate filtering uses the already-loaded page exclusion view and temporary selection source.
- Elixir review: public scenario behavior is routed through cohesive handlers/assertions; warnings-as-errors compile passes.
- Requirements review: acceptance criteria are covered by context, provider/lifecycle, controller regression, and scenario tests listed below.

## Verification Commands
- `mix test test/oli/delivery/instructor_customizations`
- `mix test test/oli/delivery/activity_provider_test.exs test/oli/activities/realizer/selection_test.exs`
- `mix test test/oli/delivery/attempts/hiearchy_test.exs test/oli/delivery/attempts/optimized_hiearchy_test.exs test/oli/delivery/attempts/retake_mode_test.exs`
- `mix test test/oli_web/controllers/activity_bank_controller_test.exs`
- `mix test test/scenarios/instructor_customizations/instructor_customizations_test.exs`
- `mix test test/scenarios/validation/schema_validation_test.exs test/scenarios/validation/invalid_attributes_test.exs`
- `mix test test/scenarios/scenario_runner_test.exs`
- `mix compile --warnings-as-errors`

## Acceptance-Criteria Proof Summary
- `AC-001` through `AC-006`: Phase 1 and 2 context/schema tests.
- `AC-007` through `AC-015`: Phase 3 provider and lifecycle tests plus graded/practice scenarios.
- `AC-016` through `AC-018`: Phase 1 read-model/predicate tests and Phase 2 candidate-listing tests.
- `AC-019`: Phase 2 stale-row reads and Phase 4 stale fulfillment tests.
- `AC-020`: Phase 4 provider coverage and `republish_preserves_exclusions.scenario.yaml`.
- `AC-021`: parser/schema/handler tests and `instructor_customization` scenarios.
- `AC-022`: `page_isolation.scenario.yaml`.

## Not Run By Codex
- Manual browser smoke of existing Instructor Preview and "Open as student" flows. This remains a manual QA/developer step because this core slice does not run an interactive browser session.

## Done Definition
- [x] Phase implementation tasks complete
- [x] Automated targeted verification passes
- [x] Review passes complete
- [x] Work-item plan synchronized
- [ ] Manual browser smoke completed
