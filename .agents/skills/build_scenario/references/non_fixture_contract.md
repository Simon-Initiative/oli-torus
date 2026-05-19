# Non-Fixture Contract (Critical)

This skill exists to guarantee real-code-path integration testing through `Oli.Scenarios`.

## Absolute rules
- Do not use factories or fixtures for domain setup that scenarios can express.
- Do not mock/stub domain services, contexts, or persistence in scenario coverage.
- Do not bypass directive handlers with direct DB inserts for projects/sections/enrollments/attempts being tested.

## Forbidden helpers in new scenario tests
- `Oli.Scenarios.TestSupport.execute_with_fixtures/1`
- `Oli.Scenarios.TestSupport.execute_file_with_fixtures/1`
- `Oli.Scenarios.TestHelpers.execute_spec/1`
- `Oli.Scenarios.TestHelpers.execute_yaml/1`
- Fixture-backed runners/macros that delegate to `Oli.Scenarios.TestSupport.*`

## Preferred execution APIs
- `Oli.Scenarios.execute/2`
- `Oli.Scenarios.execute_yaml/2`
- `Oli.Scenarios.execute_file/2`
- ExUnit modules that call `Oli.Scenarios.execute*` directly

## Allowed setup pattern
- Use real application paths:
  - Scenario directives (`project`, `section`, `user`, `enroll`, etc.)
  - Existing author/institution via `Oli.Scenarios.RuntimeOpts.build/1` when needed
  - Minimal real-module setup only when directives cannot express the prerequisite

## Review checklist before finalizing
- Scenario creates required state through directives.
- Assertions validate behavior in YAML, not only in Elixir.
- No fixture/factory/mock calls appear in new/changed scenario test code.
