---
name: spec_plan
description: Convert PRD and FDD into a dependency-ordered, phase-based implementation plan in <feature_dir>/plan.md with explicit gates, verification checklists, and parallelization notes.
examples:
  - "$spec_plan docs/features/gradebook-overrides"
  - "$spec_plan docs/epics/authoring-modernization/gradebook-overrides"
  - "Build plan.md from PRD+FDD for docs/epics/grading/late-pass-policy ($spec_plan)"
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

- `references/persona.md`
- `references/torus_spec.md`
- `references/planning_considerations.md`
- `references/approach.md`
- `references/output_requirements.md`
- `references/plan_checklist.md`
- `references/definition_of_done.md`
- `references/validation.md`
- `assets/templates/plan_template.md`
- Optional calibration example: `assets/examples/plan_example_docs_import.md`

## Workflow
1. Resolve `feature_dir` and locate `<feature_dir>/prd.md` and `<feature_dir>/fdd.md`.
   - Supported roots: `docs/features/<feature_slug>` and `docs/epics/<epic_slug>/<feature_slug>`.
   - When applicable (i.e., when this is a feature under an epic), consult and read the epic documentation (`prd.md`, `edd.md`, `plan.md`, etc.) for full context of this feature.
2. If either file is missing, stop and tell the user exactly: `I cannot find both the prd.md and fdd.md files`.
3. Ingest PRD/FDD and extract scope, constraints, non-functional requirements, and coupling points (data model, caches, tenancy, LiveView boundaries).
4. Read PRD/FDD scenario contract (`Oli.Scenarios Recommendation`) and treat it as a planning input.
   - If status is `Required`, scenario tasks must be present in relevant phases.
   - If status is `Suggested`, include at least one explicit scenario task or document why deferred.
   - If status is `Not applicable`, preserve rationale and do not invent scenario tasks.
   - Keep scenario tasks at high-level workflow/capability coverage; do not plan scenario expansion for narrow one-off details.
   - If contract says infrastructure support is `Unsupported` and expansion is required, include an explicit task naming both skills in order:
     - `Use $spec_scenario_expand to add missing scenario infrastructure support`
     - `Then use $spec_scenario to author required scenario tests`
5. Read PRD/FDD LiveView contract (`LiveView Testing Recommendation`) and treat it as a planning input.
   - If status is `Required`, LiveView test tasks must be present in relevant phases.
   - If status is `Suggested`, include explicit LiveView test tasks or document why deferred.
   - If status is `Not applicable`, preserve rationale and do not invent LiveView test tasks.
6. Record unknowns as Clarifications with explicit default assumptions.
7. Derive a bottom-up task list and group into numbered phases.
8. Build dependency graph and topologically order phases; tie-break by highest uncertainty first, then maximal safe parallelism.
9. Ensure tests are first-class tasks in each phase; include commands and pass criteria before advancement.
10. Weave non-functional threads across phases: authz/security, migrations/backfills, caching/invalidation, observability, tenant isolation, feature flag posture when applicable, documentation updates, and performance posture via telemetry/AppSignal.
   - Do not add performance/load/benchmark test tasks to the plan.
11. Review and remove ambiguity before finalizing.
12. Copy section blocks from `assets/templates/plan_template.md` into `<feature_dir>/plan.md` and fill with concrete details.
13. Enforce `references/plan_checklist.md` and `references/definition_of_done.md`.
14. Run `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check plan` immediately after updating `plan.md`.
15. Hard gate: if validation fails, fix `plan.md` and re-run until it passes before proceeding.
16. If validation cannot run, instruct the user to run it before implementation.
17. REQUIREMENTS TRACEABILITY (required):
   - Run `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py <feature_dir> --action verify_plan`.
   - Run `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py <feature_dir> --action master_validate --stage plan_present`.
   - Fail the run if any AC is not at least `verified_plan`.

## Validation Gate
- After updating any spec-pack doc(s), execute `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check plan`.
- If validation fails, fix the doc and re-run before proceeding.
- Execute the command directly when environment access allows; do not merely suggest it.

## Output Contract
- Update file directly: `<feature_dir>/plan.md`.
- Include explicit references to both PRD and FDD paths in the plan.
- Final response: updated path, numbered phases, and parallel tracks.
