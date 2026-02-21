---
name: spec_requirements
description: Manage deterministic FR/AC traceability in <feature_dir>/requirements.yml across PRD, FDD, PLAN, and implementation proof artifacts.
examples:
  - "$spec_requirements docs/features/gradebook-overrides --action init_from_prd"
  - "$spec_requirements docs/features/gradebook-overrides --action capture"
  - "$spec_requirements docs/features/gradebook-overrides --action capture --bulk-file requirements_capture.yml"
  - "$spec_requirements docs/features/gradebook-overrides --action verify_fdd"
  - "$spec_requirements docs/features/gradebook-overrides --action verify_plan"
  - "$spec_requirements docs/features/gradebook-overrides --action verify_implementation"
  - "$spec_requirements docs/features/gradebook-overrides --action master_validate --stage implementation_complete"
when_to_use:
  - "requirements.yml must be initialized, validated, or promoted through traceability stages."
  - "A deterministic machine-enforced requirements gate is needed."
when_not_to_use:
  - "The task is drafting PRD/FDD/plan content itself."
---

## Required Resources
Always load before running:

- `references/schema.md`
- `references/stages.md`

## Workflow
1. Resolve `feature_dir` under `docs/features/<feature_slug>` or `docs/epics/<epic_slug>/<feature_slug>`.
2. Select an action mode:
   - `init_from_prd`: one-time extraction from an existing inline `prd.md`; fails if `requirements.yml` already exists. After `requirements.yml` is created and validated, inline FR/AC lines are removed from `prd.md`, and requirement sections are replaced with `Requirements are found in requirements.yml`.
   - `capture`: for active PRD authoring; bulk append/edit FR/AC entries in `requirements.yml` and validate the full document. Preferred usage is `--bulk-file`.
   - `validate_structure`: validate schema, IDs, status/proof rules, FR-derived status, and duplicate/orphan constraints.
   - `verify_fdd`: require explicit AC/FR references in `fdd.md`, append `fdd` proofs, promote ACs to `verified_fdd` when eligible.
   - `verify_plan`: require AC references in `plan.md`, append `plan` proofs, promote ACs to `verified_plan` when eligible.
   - `verify_implementation`: scan tests for `@ac "AC-###"` annotations, append `test` proofs, promote ACs to `verified` when eligible.
   - `master_validate`: enforce structural and stage gates, validate proof refs/targets, verify unknown AC annotations, and fail on unmet status minimums.
3. Run:
   - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py <feature_dir> --action <action> [--stage <stage>] [--bulk-file <path>]`
4. For `master_validate`, provide `--stage`:
   - `fdd_only`
   - `plan_present`
   - `implementation_complete`
5. Treat non-zero exit as a hard gate failure; do not continue until fixed.

## Validation Gate
- Execute the script directly; do not report completion without running it when environment allows.
- Use `master_validate` with the appropriate stage before claiming readiness.

## Output Contract
- Primary artifact: `<feature_dir>/requirements.yml`.
- Final response: action executed, status summary, and any blocking errors.
