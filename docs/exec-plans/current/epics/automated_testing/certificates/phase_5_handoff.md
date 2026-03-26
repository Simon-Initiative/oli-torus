# Certificate Scenario Handoff

Work item: `docs/exec-plans/current/epics/automated_testing/certificates`

## Delivered Scenario Coverage
- `test/scenarios/certificates/setup_and_section_copy.scenario.yaml`
  - product certificate enablement
  - threshold persistence
  - design-field persistence
  - section copy of product certificate configuration
- `test/scenarios/certificates/student_progress_pending_and_approval.scenario.yaml`
  - zero-state progress
  - note/discussion threshold progress
  - below-threshold scored work
  - pending state
  - instructor deny
  - instructor approve
  - earned state
- `test/scenarios/certificates/distinction.scenario.yaml`
  - earned without distinction
  - later upgrade to distinction
- `test/scenarios/certificates/section_customization_and_updates.scenario.yaml`
  - existing-section certificate snapshot remains stable after later source/product changes
  - new sections adopt later product certificate requirements

## Execution Path
- Runner: `test/scenarios/certificates/certificates_test.exs`
- Execution API: `Oli.Scenarios.execute_file/2`
- Runtime options: `Oli.Scenarios.RuntimeOpts.build()`
- Validation API: `Oli.Scenarios.validate_file/1`

## Why The Runner Is Custom
The shared `Oli.Scenarios.ScenarioRunner` currently routes through a fixture-backed helper. For this lane, the runner intentionally avoids that path so the certificate scenarios satisfy the repository’s non-fixture scenario contract.

## Implementation Order Used
1. `extend_scenario`
   - add reusable certificate directives and assertions
   - update parser, schema, validator, engine, handlers, and docs
2. `build_scenario`
   - author workflow-level certificate YAML scenarios on top of the new DSL
   - add a runner that executes the scenarios through the non-fixture API

## Remaining Coverage Boundary
- Scenario coverage now owns the workflow-level certificate flows.
- Existing non-scenario layers still remain authoritative for:
  - certificate preview fidelity
  - PDF rendering details
  - controller/download behavior

## Follow-on Work
- Phase 4 documentation remains to be completed if the work item should explicitly reconcile manual rows that still rely on non-scenario evidence.
- If the repository wants all scenario suites to follow the non-fixture contract, `test/support/scenarios/scenario_runner.ex` should be updated separately so new suites do not need a custom runner.
- Harness validation for this work item cannot pass until `prd.md`, `fdd.md`, and `requirements.yml` exist or the validation contract is adjusted.

## File Inventory
- `docs/exec-plans/current/epics/automated_testing/certificates/plan.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/phase_1_coverage_contract.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/phase_1_execution_record.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/phase_2_execution_record.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/phase_3_execution_record.md`
- `docs/exec-plans/current/epics/automated_testing/certificates/phase_5_handoff.md`
- `test/scenarios/certificates/setup_and_section_copy.scenario.yaml`
- `test/scenarios/certificates/student_progress_pending_and_approval.scenario.yaml`
- `test/scenarios/certificates/distinction.scenario.yaml`
- `test/scenarios/certificates/section_customization_and_updates.scenario.yaml`
- `test/scenarios/certificates/certificates_test.exs`
