# Oli.Scenarios Architecture Map

Use this file map to implement expansions in the correct order.

## Core runtime surfaces
- Public API: `lib/oli/scenarios.ex`
- Directive structs/types: `lib/oli/scenarios/directive_types.ex`
- YAML parsing + allowlist validation: `lib/oli/scenarios/directive_parser.ex`
- Validator helpers: `lib/oli/scenarios/directive_validator.ex`
- Execution dispatch: `lib/oli/scenarios/engine.ex`
- Handlers: `lib/oli/scenarios/directives/*_handler.ex`
- Shared operations:
  - `lib/oli/scenarios/ops.ex`
  - `lib/oli/scenarios/section_ops.ex`
  - `lib/oli/scenarios/structure_assertions.ex`

## Schema validation surfaces
- Scenario schema: `priv/schemas/v0-1-0/scenario.schema.json`
- Schema validator module: `lib/oli/scenarios/schema.ex`
- Schema resolver registry: `lib/oli/utils/schema_resolver.ex`

## Testing surfaces
- Parser validation tests: `test/scenarios/validation/invalid_attributes_test.exs`
- Schema validation tests: `test/scenarios/validation/schema_validation_test.exs`
- Directive/handler tests: `test/scenarios/directives/**/*_test.exs`
- Scenario YAML suites: `test/scenarios/**/*.scenario.yaml`
- Single-scenario runner: `test/run_single_scenario.exs`
- Scenario runner utility: `test/support/scenarios/scenario_runner.ex`

## Documentation surfaces
- Main scenarios guide: `test/support/scenarios/README.md`
- Directive docs: `test/support/scenarios/docs/*.md`

## Skill integration surfaces
- Scenario authoring skill: `.agents/skills/spec_scenario/SKILL.md`
- Upstream workflow contracts:
  - `.agents/skills/spec_analyze/assets/templates/prd_template.md`
  - `.agents/skills/spec_architect/assets/templates/fdd_template.md`
  - `.agents/skills/spec_plan/assets/templates/plan_template.md`
