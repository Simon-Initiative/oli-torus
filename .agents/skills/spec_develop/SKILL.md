---
name: spec_develop
description: Implement one phase from <feature_dir>/plan.md using the spec pack as source of truth, with mandatory tests, mandatory spec-review-after-tests loop, and spec synchronization when implementation diverges.
examples:
  - "$spec_develop docs/features/gradebook-overrides phase=2"
  - "$spec_develop docs/epics/authoring-modernization/gradebook-overrides phase=2"
  - "Implement Phase 1 from docs/epics/grading/late-pass-policy/plan.md ($spec_develop)"
  - "Build the enrollment sync worker phase from this feature plan"
when_to_use:
  - "PRD/FDD/plan exist and implementation is requested for a specific phase."
  - "Work requires strict test and validation closure."
when_not_to_use:
  - "Spec pack is missing or incomplete."
  - "Task is low-ceremony prototype work (use $spec_prototype)."
---

## Required Resources
Always load before coding:

- `references/persona.md`
- `references/torus_spec.md`
- `references/approach.md`
- `references/coding_guidelines.md`
- `references/output_requirements.md`
- `references/development_checklist.md`
- `references/elixir_best_practices.md`
- `references/typescript_best_practices.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/phase_execution_record_template.md`
- Optional calibration example: `assets/examples/phase_execution_example_docs_import.md`

## Workflow
1. Read `prd.md`, `fdd.md`, `plan.md`, and relevant `design/*.md` for the target phase.
   - If any of `prd.md`, `fdd.md`, or `plan.md` is missing, stop and report that required spec-pack inputs are missing.
   - When applicable (i.e., when this is a feature under an epic), consult and read the epic documentation (`prd.md`, `edd.md`, `plan.md`, etc.) for full context of this feature.
2. Determine scope from inputs:
   - `$1`: required feature directory (`docs/features/<feature_slug>` or `docs/epics/<epic_slug>/<feature_slug>`).
   - `$2`: optional phase selector; when present, implement only that phase.
3. Preflight gate: run `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all` before coding.
4. Hard gate: if preflight validation fails, stop implementation, fix spec docs, and re-run until it passes.
5. Use `assets/templates/phase_execution_record_template.md` as a tracking block while implementing.
6. Implement phase-scoped tasks only; add/update tests with code changes.
7. End-of-phase technical gate (required):
   - Run `mix compile` and fix all warnings.
   - Run new/affected tests and ensure they pass.
8. End-of-phase review gate (required):
   - Run at least one `spec_review` round after compile/tests pass for that phase.
   - Fix high/medium findings before marking phase complete.
9. Sync spec docs when implementation diverges.
10. Postflight gate: run `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all` after implementation and doc updates.
11. Hard gate: if postflight validation fails, the run is not complete; fix docs and re-run until it passes.
12. If validation cannot run, instruct the user to run it and report blockers.

## Validation Gate
- Preflight: execute `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all` before coding.
- Postflight: execute `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all` after implementation and spec updates.
- If either validation run fails, stop and fix docs before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Spec-Review Requirement
- Run at least one `spec_review` round at the end of each completed phase, after compile/tests execute.
- Resolve high/medium findings before completion.
- Cap at 3 review/fix rounds.

## Output Contract
- Report implemented phase, key files changed, compile/test commands run, spec-review rounds/findings, and validation status.
