# Expansion Triggers

Use `spec_scenario_expand` when at least one is true:

1. Required scenario coverage cannot be expressed with current directives/attributes.
2. Existing directive can express part of workflow but lacks critical operation or assertion shape.
3. Feature would otherwise ship with scenario coverage deferred due DSL/runtime gaps.

Do not use this skill when:

- Existing directives already support the needed behavior (use `spec_scenario`).
- The request is only to author a new scenario file without infrastructure changes.
- The requested coverage is a narrow one-off feature detail that should remain in unit/LiveView/integration test layers.
