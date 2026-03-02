# Testing and Validation Gates

Run these gates for any infrastructure expansion.

## Required commands (adapt paths to touched files)
1. Compile:
   - `mix compile`
2. Parser/validator tests:
   - `mix test test/scenarios/validation/invalid_attributes_test.exs`
   - `mix test test/scenarios/validation/schema_validation_test.exs`
3. Touched directive/handler tests:
   - `mix test test/scenarios/directives/<relevant_test>.exs`
4. Touched scenario suites:
   - `mix scenarios <path/to/scenario.scenario.yaml>`
5. Schema validation loop while authoring YAML:
   - `mix run -e 'path = "test/scenarios/.../file.scenario.yaml"; case Oli.Scenarios.validate_file(path) do :ok -> IO.puts("schema ok"); {:error, errors} -> IO.inspect(errors, label: "schema_errors"); System.halt(1) end'`

## Completion criteria
- New directive syntax is accepted by schema and parser.
- Invalid syntax fails with clear parser/schema errors.
- Runtime behavior passes success and failure tests.
- Existing scenario suites in touched domain remain green.
