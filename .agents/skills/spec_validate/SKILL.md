---
name: spec_validate
description: Validate spec-pack markdown quality for docs/features/<feature_slug> by checking required headings, unresolved TODO markers, acceptance criteria presence, numbered plan phases with Definition of Done, and markdown link integrity.
examples:
  - "$spec_validate docs/features/docs_import"
  - "Validate this spec pack before implementation ($spec_validate)"
  - "Run heading/AC/link checks on docs/features/genai-routing"
when_to_use:
  - "Before handing specs to implementation."
  - "After editing PRD/FDD/plan/design docs."
when_not_to_use:
  - "The task is writing specs from scratch (use spec_* authoring skills first)."
---

## Required Resources
Always load before running checks:

- `references/validation_rules.md`
- `references/link_validation_notes.md`
- `references/definition_of_done.md`
- `assets/templates/validation_report_template.md`
- Optional example: `assets/examples/validation_report_example_docs_import.md`

## Workflow
1. Resolve feature directory (`docs/features/<feature_slug>`).
2. Run validator:
   - `python3 .agents/skills/spec_validate/scripts/validate_spec_pack.py docs/features/<feature_slug> --check all`
3. If needed, run targeted checks (`--check prd|fdd|plan|design`).
4. If network is available and external links matter, re-run with `--check-external-links`.
5. Report findings using `assets/templates/validation_report_template.md` structure.

## Output Contract
- Return pass/fail status and actionable failures.
- If checks cannot run, state exactly why and provide the command for the user to execute.
