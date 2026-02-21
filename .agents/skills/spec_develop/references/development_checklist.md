# Development Checklist

- Confirm selected phase tasks and dependencies from formal `plan.md` or informal plan.
- If phase selector input is provided, implement only that phase.
- Implement only the scoped phase; defer extras.
- Update tests in the same change set as behavior changes.
- Run `mix compile` and fix all warnings.
- Run targeted/full new and affected tests and ensure they pass.
- At end of completed phase, run mandatory spec-review loop and fix findings.
- Update PRD/FDD/plan when implementation reality changes.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers in touched files.
