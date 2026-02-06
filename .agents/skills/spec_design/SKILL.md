---
name: spec_design
description: Produce a slice-level detailed design doc at docs/features/<feature_slug>/design/<slice_slug>.md by mapping slice responsibilities, interfaces, edge cases, and tests to PRD/FDD acceptance criteria.
examples:
  - "$spec_design docs/features/gradebook-overrides slice=late-penalty-ui"
  - "Design phase 2 in detail for docs/features/late-pass-policy ($spec_design)"
  - "Create a detailed design doc for the enrollment-sync slice"
when_to_use:
  - "PRD/FDD exist and one implementation slice needs deeper design."
  - "A plan phase needs concrete signatures and edge-case handling before coding."
when_not_to_use:
  - "Task is feature-level architecture (use $spec_architect)."
  - "Task is immediate implementation (use $spec_develop)."
---

## Required Resources
Always load before writing:

- `references/design_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/design_slice_template.md`
- Optional calibration example: `assets/examples/design_slice_example_media_ingestion.md`

## Workflow
1. Read PRD/FDD (and plan if relevant) for the target feature.
2. Copy section blocks from `assets/templates/design_slice_template.md`.
3. Fill the doc for exactly one slice with AC mapping, signatures, data flow, and tests.
4. Apply `references/design_checklist.md` and `references/definition_of_done.md`.
5. Run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` immediately after updating the design doc.
6. Hard gate: if validation fails, fix the spec docs and re-run until it passes before proceeding.
7. If validation cannot run, instruct the user to run it before implementation.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `docs/features/<feature_slug>/design/<slice_slug>.md`.
- Final response: updated path, AC coverage list, open questions.
