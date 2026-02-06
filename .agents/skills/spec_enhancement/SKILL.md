---
name: spec_enhancement
description: Execute a ticket-sized enhancement lane by creating a mini spec doc, validating it, routing to existing feature packs when possible, and delivering implementation with design/development gates.
examples:
  - "$spec_enhancement TOR-1234"
  - "Handle this small behavior tweak with spec_enhancement: TOR-8891 add late-pass override audit logging"
  - "Implement this refactor as an enhancement lane item ($spec_enhancement)"
when_to_use:
  - "Small enhancement, refactor, or behavior tweak that needs structure but not full PRD+FDD+plan ceremony."
  - "Work starts from a ticket-sized request and still needs AC, risk, test, and rollout coverage."
when_not_to_use:
  - "Large net-new features that need full feature lane planning (use $spec_analyze, $spec_architect, $spec_plan, $spec_develop)."
  - "Pure defect/regression fixes requiring reproduction-first TDD flow (use $fixbug)."
---

## Required Resources
Always load before running:

- `references/routing.md`
- `references/enhancement_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/enhancement_template.md`
- Optional calibration example: `assets/examples/enhancement_example_torus-1234.md`

## Workflow
1. Parse inputs: ticket key (`<jira-key>`), request text, and optional feature slug override.
2. Resolve destination using `references/routing.md`.
3. Create/update enhancement doc from template:
   - Feature-pack mode: `docs/features/<feature_slug>/enhancements/<jira-key>.md`
   - Mini-pack mode: `docs/work/<jira-key>/enhancement.md`
4. Fill required sections with concise, testable content from `references/enhancement_checklist.md`.
5. Run enhancement-doc validation hard gate from `references/validation.md`.
6. If in feature-pack mode, run full spec-pack validation hard gate from `references/validation.md`.
7. Route implementation:
   - Feature-pack mode: run `spec_design` for the enhancement slice, then run `spec_develop` for implementation.
   - Mini-pack mode: perform design+develop inline using this skill's checklist, because `spec_design` and `spec_develop` are feature-pack scoped.
8. Re-run validation gates after doc updates caused by implementation.

## Validation Gate
- Always run:
  - `python3 .agents/skills/spec_enhancement/scripts/validate_enhancement_doc.py <enhancement_doc_path>`
- Additionally, in feature-pack mode run:
  - `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all`
- If any validation fails, fix docs and re-run before proceeding.
- Execute commands directly when environment access allows; do not merely suggest them.

## Output Contract
- Create/update exactly one enhancement doc for the ticket.
- Report destination mode (`feature-pack` or `mini-pack`), key ACs, implementation status, tests run, and validation status.
- If routing confidence is low, state why mini-pack mode was selected.
