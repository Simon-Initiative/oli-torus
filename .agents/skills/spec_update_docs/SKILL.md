---
name: spec_update_docs
description: Reconcile spec-pack docs after implementation drift by reading changed files/diff context, updating PRD/FDD/plan with explicit decision entries, and running spec validation to green before completion.
examples:
  - "$spec_update_docs docs/features/docs_import"
  - "Sync specs to this branch diff for docs_import and media_ingestion ($spec_update_docs)"
  - "We already coded this. Update PRD/FDD/plan to match reality using changed files list ($spec_update_docs)"
when_to_use:
  - "Implementation has already changed behavior/interfaces/data and docs must be brought back in sync."
  - "Spec validation is failing and the task is to repair spec artifacts rather than write new feature specs."
when_not_to_use:
  - "Net-new feature definition before coding (use $spec_analyze, $spec_architect, $spec_plan)."
  - "Ticket-sized enhancement execution (use $spec_enhancement)."
---

## Required Resources
Always load before editing:

- `references/input_resolution.md`
- `references/drift_mapping.md`
- `references/decision_log.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/decision_entry_template.md`
- Optional calibration example: `assets/examples/decision_entry_example.md`

## Workflow
1. Resolve scope from provided feature slug(s), changed files, or branch diff using `references/input_resolution.md`.
2. Identify affected feature packs and collect evidence of drift from changed code, migrations, APIs, tests, and behavior changes.
3. Update affected docs:
   - `prd.md` for acceptance/scope changes.
   - `fdd.md` for interface, data model, migration, and operational changes.
   - `plan.md` for phase mapping/status changes caused by implementation reality.
4. For every material doc change, append a short decision entry using `references/decision_log.md`.
5. Run `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` for each affected feature slug.
6. Hard gate: if validation fails, fix docs and re-run until green for every affected slug.
7. Report the synchronized docs, key decisions, and validation results.

## Validation Gate
- Mandatory command per slug:
  - `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all`
- This is a hard gate. Do not mark completion while any slug is failing.
- Execute commands directly when environment access allows; do not merely suggest them.

## Output Contract
- Update PRD/FDD/plan files in-place for each affected feature pack.
- Include at least one decision entry for each materially changed spec file.
- Final response must include:
  - Affected slugs.
  - Files updated.
  - Decision summary.
  - Validation pass/fail per slug.
