# Phase <n> Execution Record

Feature: `<feature_dir>`
Phase: `<n or name>`

## Scope from plan.md
- <phase goal>
- <task subset being implemented>

## Implementation Blocks
- [ ] Backend changes
- [ ] Frontend/LiveView changes
- [ ] Data model/migration changes
- [ ] Authz/tenancy checks
- [ ] Observability updates

## Test Blocks
- [ ] Unit tests added/updated
- [ ] Integration/LiveView tests added/updated
- [ ] Regression checks for changed behavior
- [ ] Commands executed and results captured
- [ ] `mix compile` completed with zero warnings

## Spec Sync
- [ ] PRD/FDD/plan updated when implementation diverged
- [ ] Open questions added to spec docs

## Spec-Review Loop
- Required timing: run after compile/tests pass for this phase.
- Round 1 findings:
- Round 1 fixes:
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [ ] Phase tasks complete
- [ ] Tests pass
- [ ] Compile passes with no warnings
- [ ] End-of-phase spec-review completed
- [ ] Validation checks pass
- [ ] No unresolved high/medium review findings
