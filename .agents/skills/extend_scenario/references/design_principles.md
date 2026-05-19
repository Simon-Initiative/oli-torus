# Directive Design Principles

## DSL fit and naming
- Prefer verbs that match existing command style (`project`, `section`, `publish`, `assert`, etc.).
- Reuse existing nouns/attribute names where possible (`to`, `from`, `name`, `title`, `ops`).
- Avoid introducing synonyms for existing semantics.
- Add capabilities at workflow granularity; avoid directives/attributes that only serve a single narrow feature variant.

## Composition and determinism
- Keep directives sequential and deterministic.
- Prefer small composable directives over one giant multipurpose directive.
- Ensure behavior remains stable regardless of test execution order outside the scenario file.
- Favor reusable coarse actions (create/update/publish/enroll/attempt/assert) over deeply granular UI-detail-specific controls.

## Backward compatibility
- Adding optional attributes is preferred over changing required existing semantics.
- If introducing a new directive, do not alter behavior of existing directives silently.

## Validation parity (mandatory)
- If parser supports new attributes/directives, schema must support them.
- If schema supports a construct, parser/engine must execute or reject with clear errors.
- Keep parser error messages actionable and explicit.

## Layer boundaries
- Scenario infrastructure should exercise real `Oli` application code paths.
- Avoid `OliWeb` coupling in scenario runtime behavior unless explicitly necessary and documented.
