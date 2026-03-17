# Expansion Workflow

## 1) Gap statement (required)
- Capture:
  - Required workflow/AC needing scenario coverage
  - Current directive limitations
  - Proposed YAML authoring shape

## 2) Design choice (required)
- Choose one:
  - Extend existing directive
  - Add new directive
- Document why alternatives were rejected.

## 3) Implement full chain (required)
- Types -> parser -> validator -> engine -> handler/ops -> schema -> docs -> tests
- Do not stop after parser-only or handler-only changes.

## 4) Test strategy (required)
- Parser/validator negative tests for invalid attrs or directive typos.
- Runtime handler tests for success and failure paths.
- Schema validation coverage for new YAML structures.
- At least one representative `.scenario.yaml` example if behavior is end-user-facing.

## 5) Final gate
- `mix compile`
- targeted scenario parser/handler tests
- targeted scenario validation tests
- any newly affected test suites

If a feature’s plan requires scenario coverage and infrastructure is missing, update the feature’s plan tasks to include this expansion work and then consume new capability with `spec_scenario`.
