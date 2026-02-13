---
name: spec_architect
description: Transform a PRD into a practical FDD in <feature_dir>/fdd.md with concrete architecture boundaries, interfaces, data impacts, risk controls, and verification strategy for implementation planning.
examples:
  - "$spec_architect docs/features/gradebook-overrides"
  - "$spec_architect docs/epics/authoring-modernization/gradebook-overrides"
  - "Use the PRD to draft docs/epics/grading/late-pass-policy/fdd.md ($spec_architect)"
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

- `references/persona.md`
- `references/torus_spec.md`
- `references/focus_areas.md`
- `references/approach.md`
- `references/output_requirements.md`
- `references/fdd_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/fdd_template.md`
- Optional calibration example: `assets/examples/fdd_example_docs_import.md`

## Workflow
1. Resolve `feature_dir` and read `<feature_dir>/prd.md`.
   - Supported roots: `docs/features/<feature_slug>` and `docs/epics/<epic_slug>/<feature_slug>`.
   - When applicable (i.e., when this is a feature under an epic), consult and read the epic documentation (`prd.md`, `edd.md`, `plan.md`, etc.) for full context of this feature.
2. Restate the request in architecture terms: scope, non-goals, constraints, FR/AC success criteria, and NFR targets.
3. Ingest local Torus design docs from `guides/design/**/*.md` and summarize "What we know / Unknowns to confirm".
4. Do lightweight codebase waypointing for relevant contexts, schemas, LiveViews, jobs, caches, supervisors, and telemetry hooks.
5. Capture explicit assumptions and associated risks; proceed without blocking when assumptions are necessary.
6. Run targeted external research for Elixir/Phoenix/OTP patterns when needed; prefer primary sources and record citations in FDD section 17 as `Title | URL | Accessed YYYY-MM-DD`.
7. Copy section blocks from `assets/templates/fdd_template.md` into `<feature_dir>/fdd.md`.
8. Fill each block using `references/focus_areas.md` and `references/output_requirements.md`, including concrete module boundaries, contracts, rollout/rollback, observability, security, and testing.
9. Apply `references/fdd_checklist.md` and `references/definition_of_done.md` before finalizing.
10. Run `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check fdd` immediately after updating `fdd.md`.
11. Hard gate: if validation fails, fix `fdd.md` and re-run until it passes before proceeding.
12. If validation cannot run, instruct the user to run it and report failures.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check fdd`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `<feature_dir>/fdd.md`.
- Final response: updated path, key decisions, unresolved questions.
