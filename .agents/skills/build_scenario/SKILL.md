---
name: build_scenario
description: >
  Author and maintain Oli.Scenarios YAML-driven integration tests for Torus, including new `.scenario.yaml` files and companion ExUnit runners. Use when features or bugs need non-UI integration coverage through real authoring/delivery/student workflows (projects, content edits, publishing, sections, enrollments, learner attempts, assertions), especially when other `spec_*` skills need scenario-based test implementation. Do not use for UI/browser automation or for tests that depend on fixtures/factories/mocks for domain setup.
---

## Purpose
Author deterministic, YAML-driven scenario tests that validate real Torus behavior through `Oli.Scenarios` directives.

The entire purpose of a scenario-driven test is to execute actual application code in an end-to-end integrated test environment. These are the types of integration tests that typically are done using a user interface, maybe driven from a playwright test, but Scenario tests are focused on the underlying non-user interface infrastructure. These Scenario tests are preferred because they execute much, much more quickly and much more robustly than a playwright browser-based test can. The most important constraint in a scenario-based test it is that mock fixtures, uh, fake data can never be used. The entire point is to actually test the application real infrastructure in an automated integration type test.

## Required Resources
Always load before writing scenario tests:

- `references/persona.md`
- `references/approach.md`
- `references/non_fixture_contract.md`
- `references/directive_playbook.md`
- `references/output_requirements.md`

Use templates/examples as needed:

- `assets/templates/scenario_template.scenario.yaml`
- `assets/templates/scenario_test_module.exs`
- `assets/examples/project_to_delivery_workflow.scenario.yaml`

## Hard Guardrails
1. Never use fixtures/factories/mocks to create or bypass the domain state under test.
2. Never call `Oli.Scenarios.TestSupport.execute_with_fixtures/1` or `Oli.Scenarios.TestSupport.execute_file_with_fixtures/1` in new tests.
3. Never call `Oli.Scenarios.TestHelpers` helpers that route through fixture-backed execution for new tests.
4. Drive setup and behavior through scenario directives and real application modules (`Oli.Scenarios`, directive handlers, domain contexts).
5. Prefer assertions in YAML (`assert` directive) before adding Elixir-side assertions.
6. Schema validation is mandatory while authoring:
   - Validate the target scenario file after each meaningful edit.
   - Do not continue building on an invalid YAML scenario file.
7. Finalization is blocked unless the new/updated scenario file passes schema validation and parser validation.
8. Keep scenario scope at high-level workflow behavior; do not encode narrowly scoped one-off feature minutiae as new scenario constructs.

## Workflow
1. Identify the target behavior and minimum realistic workflow to reproduce it.
2. Choose scenario file location:
   - Extend an existing focused scenario suite directory when behavior fits.
   - Create a new directory under `test/scenarios/` only when introducing a new domain slice.
3. Author or update `.scenario.yaml` with only required directives, in execution order.
4. Incremental validation loop (required after each meaningful YAML edit):
   - Run schema validation for the target file:
     - `mix run -e 'path = "test/scenarios/.../file.scenario.yaml"; case Oli.Scenarios.validate_file(path) do :ok -> IO.puts("schema ok"); {:error, errors} -> IO.inspect(errors, label: "schema_errors"); System.halt(1) end'`
   - If schema errors exist, fix them immediately before adding more directives.
5. Parser validation check (required before test execution):
   - Run a targeted scenario execution test for the changed file/module so parser-level errors surface early.
   - Fix parser/runtime errors before continuing scenario expansion.
6. Prefer reusable setup with `use` directive for shared baseline flows.
7. Add/adjust ExUnit runner module:
   - Use `Oli.Scenarios.execute_file/2` directly (no fixture wrappers).
   - Keep failure output readable (errors + failed verifications).
8. Run targeted test command(s) for the changed scenario coverage.
9. If failures require hooks, implement minimal hook functions that still preserve real code-path validation.
10. Final validation gate before completion:
   - Re-run schema validation for all changed scenario files.
   - Re-run affected tests.

## Directive Strategy
- Baseline authoring flow: `project` -> `manipulate`/`edit_page`/`create_activity` -> `publish`.
- Delivery flow: `section` -> `enroll` -> `view_practice_page` -> `answer_question` -> `assert`.
- Reuse and composition: `use`, `clone`, `remix`, `customize`, `update`.
- Validation first: add `assert structure/resource/progress/proficiency` near each major transition.
- Prefer coarse workflow coverage (capability-level) over exhaustive micro-feature permutations.

## Output Contract
Follow `references/output_requirements.md` when reporting completion.
