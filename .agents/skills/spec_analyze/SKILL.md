---
name: spec_analyze
description: Convert an informal feature idea into a concise, implementation-ready PRD in <feature_dir>/prd.md. Support feature packs under docs/features/<feature_slug> and epic feature packs under docs/epics/<epic_slug>/<feature_slug>.
examples:
  - "$spec_analyze docs/features/gradebook-overrides"
  - "$spec_analyze docs/epics/authoring-modernization/gradebook-overrides"
  - "Create a PRD from this rough feature description in docs/features/late-pass-policy ($spec_analyze)"
  - "Turn these notes into docs/epics/learning-tools/content-remix/prd.md"
when_to_use:
  - "A new feature needs a PRD."
  - "Existing PRD lacks clear FR/AC structure."
when_not_to_use:
  - "The task is architecture design (use $spec_architect)."
  - "The task is implementation (use $spec_develop)."
---

## Required Resources
Always load these files before drafting:

- `references/persona.md`
- `references/torus_spec.md`
- `references/considerations.md`
- `references/approach.md`
- `references/output_requirements.md`
- `references/prd_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/prd_template.md`
- Optional calibration example: `assets/examples/prd_example_docs_import.md`

## Workflow
1. Resolve `feature_dir` and open/create `<feature_dir>/prd.md`.
   - Supported roots: `docs/features/<feature_slug>` and `docs/epics/<epic_slug>/<feature_slug>`.
   - When applicable (i.e., when this is a feature under an epic), consult and read the epic documentation (`prd.md`, `edd.md`, `plan.md`, etc.) for full context of this feature.
2. Ensure an informal feature description exists. If missing, ask the user to paste or type it before drafting.
3. Restate the feature in product terms: user value, scope, role impacts, constraints, and measurable success signals.
4. Copy the exact section blocks from `assets/templates/prd_template.md`.
5. Fill each section using `references/considerations.md` and `references/output_requirements.md`, keeping requirements concrete and testable.
6. For `## 11. Feature Flagging, Rollout & Migration`, include feature-flag requirements only when the informal description explicitly asks for feature flags or flag-driven rollout. Otherwise include the exact line: `No feature flags present in this feature`.
7. Apply `references/prd_checklist.md` and `references/definition_of_done.md` as hard gates.
8. Run `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check prd` immediately after updating the PRD.
9. Hard gate: if validation fails, fix `prd.md` and re-run until it passes before proceeding.
10. If validation cannot be run, instruct the user to run it and do not claim the PRD is complete.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check prd`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `<feature_dir>/prd.md`.
- Output only the PRD body in markdown (no preamble or roleplay text).
- Keep the final response short: updated path, key changes, and any open questions.
