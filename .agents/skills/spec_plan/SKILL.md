---
name: spec_plan
description: Convert PRD and FDD into a dependency-ordered, phase-based implementation plan in docs/features/<feature_slug>/plan.md with explicit gates, verification checklists, and parallelization notes.
examples:
  - "$spec_plan docs/features/gradebook-overrides"
  - "Build plan.md from PRD+FDD for docs/features/late-pass-policy ($spec_plan)"
  - "Generate phased implementation tasks with parallelizable work called out"
when_to_use:
  - "PRD and FDD are ready and delivery planning is needed."
  - "Work must be split into safe phases and gates."
when_not_to_use:
  - "PRD/FDD are missing (use $spec_analyze / $spec_architect first)."
  - "Task is direct coding (use $spec_develop)."
---

## Required Resources
Always load before drafting:

- `references/plan_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/plan_template.md`
- Optional calibration example: `assets/examples/plan_example_docs_import.md`

## Workflow
1. Read PRD and FDD for the target feature.
2. Copy section blocks from `assets/templates/plan_template.md`.
3. Build numbered phases with dependency order and explicit verification per phase.
4. Enforce `references/plan_checklist.md` and `references/definition_of_done.md`.
5. Run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check plan` immediately after updating `plan.md`.
6. Hard gate: if validation fails, fix `plan.md` and re-run until it passes before proceeding.
7. If validation cannot run, instruct the user to run it before implementation.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check plan`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `docs/features/<feature_slug>/plan.md`.
- Final response: updated path, numbered phases, and parallel tracks.
