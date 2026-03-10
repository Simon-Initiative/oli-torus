---
name: extend_scenario
description: >
  Extends Oli.Scenarios infrastructure when required feature coverage is not yet supported by current directives. Use for adding new directive capabilities, parser/validator/schema support, handler execution paths, and infrastructure tests so downstream scenario tests can be authored via `spec_scenario`.
---

## Purpose
Implement missing `Oli.Scenarios` infrastructure so required scenario-based coverage can be delivered in the same feature stream instead of deferred.

## Required Resources
Always load before expanding:

- `references/persona.md`
- `references/expansion_triggers.md`
- `references/architecture_map.md`
- `references/design_principles.md`
- `references/workflow.md`
- `references/testing_and_validation.md`
- `references/output_requirements.md`

Use templates/examples as needed:

- `assets/templates/expansion_execution_checklist.md`
- `assets/templates/directive_design_template.md`
- `assets/examples/expansion_plan_example.md`

## Hard Guardrails
1. Preserve existing scenario DSL style and naming conventions; do not invent a conflicting mini-language.
2. Keep directives focused on domain-intent commands/declarations and deterministic execution semantics.
3. Add/extend schema, parser, and runtime support together; do not leave partially wired directive support.
4. Do not use fixture/mocking shortcuts to simulate infrastructure behavior in end-to-end scenario coverage.
5. Backward compatibility is mandatory unless explicit spec-approved breaking change is documented.
6. Expand scenario infrastructure at capability/workflow level, not for narrowly scoped one-off feature details.

## When to Invoke This Skill
- PRD/FDD/plan marks scenario coverage as `Required` or `Suggested`, but current directives cannot represent needed workflows.
- Existing directive semantics are insufficient for newly scoped domain operations.
- Feature work would otherwise skip scenario coverage due infrastructure gaps.

## Workflow
1. Confirm the gap:
   - Identify required AC/workflow coverage and show why existing directives cannot express it.
   - Record exact unsupported behavior and expected YAML authoring shape.
2. Design directive extension:
   - Prefer extending an existing directive when semantics align.
   - Introduce new directives only when extension would be ambiguous or overloaded.
   - Follow `references/design_principles.md` and fill `assets/templates/directive_design_template.md`.
   - Ensure proposed expansion represents a reusable high-level action/capability, not a micro-feature toggle.
3. Implement infrastructure end-to-end:
   - `lib/oli/scenarios/directive_types.ex`
   - `lib/oli/scenarios/directive_parser.ex`
   - `lib/oli/scenarios/directive_validator.ex` (as applicable)
   - `lib/oli/scenarios/engine.ex`
   - `lib/oli/scenarios/directives/*_handler.ex` and related ops modules
   - `priv/schemas/v0-1-0/scenario.schema.json`
   - `lib/oli/scenarios/schema.ex` (if validation behavior changes)
4. Update docs and discoverability:
   - `test/support/scenarios/README.md`
   - relevant `test/support/scenarios/docs/*.md`
5. Add infrastructure tests and scenario validation tests:
   - parser/validator tests for new attributes and failure modes
   - handler/runtime tests for success + error paths
   - schema validation expectations where applicable
6. Add representative scenario YAML demonstrating new capability (focused and minimal).
7. Run required validation/test gates from `references/testing_and_validation.md`.
8. If feature specs changed due expansion decisions, sync PRD/FDD/plan contracts before completion.

## Output Contract
Follow `references/output_requirements.md` exactly when reporting completion.
