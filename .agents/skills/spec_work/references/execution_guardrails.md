# Execution Guardrails

After approval, implement directly with strict scope control.

## Guardrails
- Keep changes minimal and ticket-focused; avoid opportunistic refactors.
- Follow Torus and Elixir/Phoenix best practices (authz, tenancy, reliability).
- Preserve backwards compatibility unless ticket explicitly requires breaking behavior.
- Add or update tests for changed behavior.
- If scenario testing is appropriate for the changed workflow, do not skip it:
  - use `$spec_scenario` when existing infrastructure supports it
  - use `$spec_scenario_expand` then `$spec_scenario` when infrastructure support is missing
- Run compile and affected tests before completion.
- Report residual risk and follow-up items clearly.

## Lane Boundaries
- If ticket is a bug/regression, route to `$spec_fixbug`.
- If scope expands into net-new feature discovery, stop and recommend full feature lane (`$spec_analyze` + follow-ons).
- Do not create enhancement markdown artifacts under `docs/` in this lane.
