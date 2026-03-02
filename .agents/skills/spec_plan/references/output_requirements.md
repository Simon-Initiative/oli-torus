# Output Requirements (Plan)

Write `<feature_dir>/plan.md` as a human-readable execution plan.

## Required Structure

- Title
- Scope and guardrails
- Explicit references to:
  - `<feature_dir>/prd.md`
  - `<feature_dir>/fdd.md`
- Scenario testing contract block (status, scope, artifacts, validation commands)
- Include scenario infrastructure support status and expansion requirement in the scenario contract.
- If expansion is required, include explicit skill handoff text: `Use $spec_scenario_expand first, then $spec_scenario`.
- LiveView testing contract block (status, scope, artifacts, validation commands)
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
- If scenario status is `Required`, scenario tasks are mandatory in relevant phases.
- If scenario status is `Suggested`, include scenario tasks or explicitly document defer rationale.
- If scenario status is `Required` and support is `Unsupported`, expansion tasks are mandatory and must explicitly reference `$spec_scenario_expand` before `$spec_scenario`.
- If LiveView status is `Required`, LiveView test tasks are mandatory in relevant phases.
- If LiveView status is `Suggested`, include LiveView test tasks or explicitly document defer rationale.
- Non-functional work must be distributed across phases, not deferred to the end.
- Performance items must be telemetry/AppSignal instrumentation/monitoring tasks; do not include performance/load/benchmark test tasks.
- Unknowns must be captured as clarifications with default assumptions.
- Use plain markdown and avoid unresolved placeholders (`TODO`, `TBD`, `FIXME`).
