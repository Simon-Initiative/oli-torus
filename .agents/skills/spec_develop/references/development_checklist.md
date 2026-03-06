# Development Checklist

- Confirm selected phase tasks and dependencies from formal `plan.md` or informal plan.
- If phase selector input is provided, implement only that phase.
- Implement only the scoped phase; defer extras.
- Update tests in the same change set as behavior changes.
- If PRD/FDD/plan scenario status is `Required`, add/update scenario tests in this phase where applicable.
- If scenario status is `Suggested`, implement planned scenario tasks or document explicit defer rationale.
- If scenario support is `Unsupported` and expansion is required, run `$spec_scenario_expand` before `$spec_scenario`.
- If PRD/FDD/plan LiveView status is `Required`, add/update targeted LiveView tests for changed UI behavior.
- If LiveView status is `Suggested`, implement planned LiveView tests or document explicit defer rationale.
- Ensure LiveView modules keep business logic out of UI layer; keep domain logic in contexts/services.
- Do not add dedicated performance/load/benchmark tests.
- Satisfy performance requirements with telemetry/AppSignal instrumentation and alert/reporting updates.
- Run `mix compile` and fix all warnings.
- Run targeted/full new and affected tests and ensure they pass.
- At end of completed phase, run mandatory spec-review loop and fix findings.
- Update PRD/FDD/plan when implementation reality changes.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers in touched files.
