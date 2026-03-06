# Approach

## 1) Define the behavior contract
- Identify the business behavior to prove.
- Write 1-3 acceptance checks that can be expressed with scenario `assert` directives.

## 2) Map contract to directives
- Pick the smallest directive sequence that reproduces the behavior.
- Use domain-realistic ordering (authoring -> publish -> delivery -> learner interactions).

## 3) Author YAML first
- Add/update a `.scenario.yaml` file under `test/scenarios/**`.
- Keep directive names and entity names explicit (`project`, `section`, `student_alice`, etc.).
- Prefer `use` for reusable shared setup.
- Validate incrementally after each meaningful YAML edit with `Oli.Scenarios.validate_file/1`.
- Treat schema errors as stop-the-line failures; fix before adding more directives.

## 4) Wire execution in ExUnit
- Run scenario files via `Oli.Scenarios.execute_file/2` or parsed directives via `Oli.Scenarios.execute/2`.
- In new tests, avoid fixture-backed wrappers.
- Fail tests on:
  - any `result.errors`
  - any failed verification in `result.verifications`

## 5) Verify and iterate
- Run targeted tests first.
- Prefer `mix test <new_or_updated_test_module>.exs` for no-fixture execution paths.
- Tighten assertions to verify intended behavior and guard regressions.
- Keep scenario concise by removing directives that do not affect assertions.
- Before finalizing, re-run schema validation on all changed scenario files.
