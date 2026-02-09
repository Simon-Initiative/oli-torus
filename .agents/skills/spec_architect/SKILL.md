---
name: spec_architect
description: Transform a PRD into a practical FDD in docs/features/<feature_slug>/fdd.md with concrete architecture boundaries, interfaces, data impacts, risk controls, and verification strategy for implementation planning.
examples:
  - "$spec_architect docs/features/gradebook-overrides"
  - "Use the PRD to draft docs/features/late-pass-policy/fdd.md ($spec_architect)"
  - "Architect this feature from its prd.md"
when_to_use:
  - "PRD exists and technical design decisions are needed."
  - "Team needs module boundaries and contracts before planning or coding."
when_not_to_use:
  - "PRD is missing (use $spec_analyze)."
  - "Task is direct implementation (use $spec_develop)."
---

## Required Resources
Always load before writing:

- `references/fdd_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/fdd_template.md`
- Optional calibration example: `assets/examples/fdd_example_docs_import.md`

## Workflow
1. Read `docs/features/<feature_slug>/prd.md`.
2. Copy section blocks from `assets/templates/fdd_template.md` into `docs/features/<feature_slug>/fdd.md`.
3. Fill each block with design decisions, signatures/contracts, and operational concerns.
4. Apply `references/fdd_checklist.md` and `references/definition_of_done.md` before finalizing.
5. Run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check fdd` immediately after updating `fdd.md`.
6. Hard gate: if validation fails, fix `fdd.md` and re-run until it passes before proceeding.
7. If validation cannot run, instruct the user to run it and report failures.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check fdd`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `docs/features/<feature_slug>/fdd.md`.
- Final response: updated path, key decisions, unresolved questions.
