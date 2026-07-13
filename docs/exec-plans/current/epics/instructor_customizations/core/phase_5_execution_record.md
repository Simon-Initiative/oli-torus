# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/core`
Phase: `5 - Oli.Scenarios directives and end-to-end workflows`

## Scope from plan.md
- Add reusable scenario DSL support for instructor activity customizations.
- Route scenario writes through `Oli.Delivery.InstructorCustomizations`.
- Prove practice, graded, page-isolation, and republish workflows without hooks or fixtures.

## Implementation Blocks
- [x] Added `instructor_customization` directive type, parser support, engine dispatch, schema definitions, and handler.
- [x] Added `assert.activity_customization` based on `get_page_exclusion_view/2` and enabled-state predicates.
- [x] Extended `assert.activity_attempt` with `exists` for activity absence checks after realization.
- [x] Preserved explicit `bank-selection` ids in scenario `ActivityProcessor` output so customization scenarios can target stable selection ids.
- [x] Documented the new scenario directive and assertion.

## Scenario Proof
- `test/scenarios/instructor_customizations/page_isolation.scenario.yaml`
  - Excludes an embedded activity and one bank candidate on page A.
  - Proves the same bank candidate remains enabled and realized on page B.
- `test/scenarios/instructor_customizations/republish_preserves_exclusions.scenario.yaml`
  - Excludes one bank candidate.
  - Republishes the page with a new candidate and updates the section.
  - Proves the old exclusion remains and the new non-excluded candidate realizes.
- `test/scenarios/instructor_customizations/graded_attempt_filtering.scenario.yaml`
  - Starts a graded attempt after excluding an embedded activity and a whole bank selection.
  - Proves excluded activities do not produce activity attempts and enabled activities still do.

## Verification
- `mix test test/scenarios/instructor_customizations/instructor_customizations_test.exs`
- `mix test test/scenarios/validation/schema_validation_test.exs test/scenarios/validation/invalid_attributes_test.exs`
- `mix test test/scenarios/scenario_runner_test.exs`
- `mix compile --warnings-as-errors`

## Review Notes
- Security: scenario writes still delegate to the delivery context, preserving authorization and target validation.
- Performance: scenario-only assertions read one page exclusion view and use in-memory predicates.
- Requirements: covers `FR-009`, `AC-020`, `AC-021`, and `AC-022`.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed
- [x] Validation passes
