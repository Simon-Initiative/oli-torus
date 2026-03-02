# Considerations

- TDD-first is mandatory: capture the bug with a failing test before fix.
- Prefer localized changes in existing modules over broad rewrites.
- Keep multi-tenant, role/permission, and auth boundaries intact.
- Preserve operational safety: explicit error handling and telemetry/logging where behavior changes are critical.
- Avoid performance regressions (no query-in-loop patterns or unnecessary extra queries).
- Update docs only when externally visible behavior contracts changed.
- Always make and report a scenario-applicability decision.
- If the bug path is already representable with existing `Oli.Scenarios`, add scenario regression coverage.
- Never use `$spec_scenario_expand` in this workflow; missing scenario infrastructure is out of scope for `$spec_fixbug`.
- Keep scenario bug coverage at high-level existing workflows; do not force scenario paths for narrow UI-detail regressions better covered by unit/LiveView tests.
