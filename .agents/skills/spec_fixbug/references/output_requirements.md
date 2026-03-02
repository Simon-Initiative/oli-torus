# Output Requirements

Provide a concise, PR-ready result:

- `PR title suggestion: <title>`
- `Changes:` bullet list describing regression test and production fix.
- `Verification:` commands/tests run and outcomes.
- `Risk:` short residual risk assessment.

Also include:

- Ticket identifier used.
- Confirmation that test failed before fix and passes after fix.
- Scenario applicability decision (`yes`/`no`) with one-line rationale.
- If `yes`, list scenario files/tests added or updated.
- Explicit confirmation that `$spec_scenario_expand` was not invoked in this run.
