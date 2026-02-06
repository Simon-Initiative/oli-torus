---
name: spec_analyze
description: Convert an informal feature idea into a concise, implementation-ready PRD in docs/features/<feature_slug>/prd.md. Use when requirements are ambiguous or missing and the team needs testable FR/AC definitions before architecture or implementation.
examples:
  - "$spec_analyze docs/features/gradebook-overrides"
  - "Create a PRD from this rough feature description in docs/features/late-pass-policy ($spec_analyze)"
  - "Turn these notes into docs/features/content-remix/prd.md"
when_to_use:
  - "A new feature needs a PRD."
  - "Existing PRD lacks clear FR/AC structure."
when_not_to_use:
  - "The task is architecture design (use $spec_architect)."
  - "The task is implementation (use $spec_develop)."
---

## Required Resources
Always load these files before drafting:

- `references/prd_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/prd_template.md`
- Optional calibration example: `assets/examples/prd_example_docs_import.md`

## Workflow
1. Resolve `feature_slug` and open/create `docs/features/<feature_slug>/prd.md`.
2. Start by copying the exact section blocks from `assets/templates/prd_template.md`.
3. Fill sections using user input plus Torus context; keep FR/AC IDs strict and testable.
4. Run `references/prd_checklist.md` and `references/definition_of_done.md` as hard gates.
5. Run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check prd` immediately after updating the PRD.
6. Hard gate: if validation fails, fix `prd.md` and re-run until it passes before proceeding.
7. If validation cannot be run, instruct the user to run it and do not claim the PRD is complete.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check prd`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `docs/features/<feature_slug>/prd.md`.
- Keep the final response short: updated path, key changes, and any open questions.
