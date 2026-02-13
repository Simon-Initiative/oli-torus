# Output Requirements (Plan)

Write `<feature_dir>/plan.md` as a human-readable execution plan.

## Required Structure

- Title
- Scope and guardrails
- Explicit references to:
  - `<feature_dir>/prd.md`
  - `<feature_dir>/fdd.md`
- Clarifications & default assumptions
- Numbered phases (`## Phase N: <name>`)
- Parallelization notes
- Phase gate summary

## Required Content Per Phase

Every phase must include:

- Goal: clear outcome for the phase.
- Tasks: checklist of implementation work items.
- Testing Tasks: explicit test-writing/running tasks and commands.
- Definition of Done: objective completion criteria.
- Gate: pass/fail condition required before next phase.
- Dependencies: prior phases/tasks required before this phase starts.
- Parallelizable work: what can run concurrently and why it is safe.

## Quality Rules

- Plans must be bottom-up and dependency-ordered.
- Tasks must be small enough to be independently implemented and reviewed.
- Testing is mandatory in every phase and must pass before advancement.
- Non-functional work must be distributed across phases, not deferred to the end.
- Unknowns must be captured as clarifications with default assumptions.
- Use plain markdown and avoid unresolved placeholders (`TODO`, `TBD`, `FIXME`).
