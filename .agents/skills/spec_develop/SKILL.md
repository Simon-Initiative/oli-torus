---
name: spec_develop
description: Implement one phase from docs/features/<feature_slug>/plan.md using the spec pack as source of truth, with mandatory tests, mandatory self-review-after-tests loop, and spec synchronization when implementation diverges.
examples:
  - "$spec_develop docs/features/gradebook-overrides phase=2"
  - "Implement Phase 1 from docs/features/late-pass-policy/plan.md ($spec_develop)"
  - "Build the enrollment sync worker phase from this feature plan"
when_to_use:
  - "PRD/FDD/plan exist and implementation is requested for a specific phase."
  - "Work requires strict test and validation closure."
when_not_to_use:
  - "Spec pack is missing or incomplete."
  - "Task is low-ceremony prototype work (use $prototype)."
---

## Required Resources
Always load before coding:

- `references/development_checklist.md`
- `references/elixir_best_practices.md`
- `references/typescript_best_practices.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/phase_execution_record_template.md`
- Optional calibration example: `assets/examples/phase_execution_example_docs_import.md`

## Workflow
1. Read `prd.md`, `fdd.md`, `plan.md`, and relevant `design/*.md` for the target phase.
2. Preflight gate: run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` before coding.
3. Hard gate: if preflight validation fails, stop implementation, fix spec docs, and re-run until it passes.
4. Use `assets/templates/phase_execution_record_template.md` as a tracking block while implementing.
5. Implement phase-scoped tasks only; add/update tests with code changes.
6. Run compile/tests and mandatory self-review loop; fix findings.
7. Sync spec docs when implementation diverges.
8. Postflight gate: run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` after implementation and doc updates.
9. Hard gate: if postflight validation fails, the run is not complete; fix docs and re-run until it passes.
10. If validation cannot run, instruct the user to run it and report blockers.

## Validation Gate
- Preflight: execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` before coding.
- Postflight: execute `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` after implementation and spec updates.
- If either validation run fails, stop and fix docs before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Self-Review Requirement
- Run at least one `self_review` round after tests execute.
- Resolve high/medium findings before completion.
- Cap at 3 review/fix rounds.

## Output Contract
- Report implemented phase, key files changed, tests run, and validation status.
