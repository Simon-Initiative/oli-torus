# Example Expansion Plan (Abbreviated)

## Gap
Feature requires scenario coverage for `<new_domain_behavior>`, but no directive currently supports `<needed_action>`.

## Proposed change
- Extend `<existing_directive>` with `<new_attribute>`
- Add handler behavior in `<relevant_handler>.ex`
- Add schema support in `priv/schemas/v0-1-0/scenario.schema.json`

## File touch list
- `lib/oli/scenarios/directive_types.ex`
- `lib/oli/scenarios/directive_parser.ex`
- `lib/oli/scenarios/engine.ex`
- `lib/oli/scenarios/directives/<handler>.ex`
- `priv/schemas/v0-1-0/scenario.schema.json`
- `test/scenarios/validation/invalid_attributes_test.exs`
- `test/scenarios/directives/<handler>_test.exs`
- `test/scenarios/<domain>/<new_case>.scenario.yaml`
- `test/support/scenarios/docs/<topic>.md`

## Required verification
- `mix compile`
- parser/validator tests
- handler/runtime tests
- schema validation tests
- targeted scenario execution
