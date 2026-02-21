# Considerations

- TDD-first is mandatory: capture the bug with a failing test before fix.
- Prefer localized changes in existing modules over broad rewrites.
- Keep multi-tenant, role/permission, and auth boundaries intact.
- Preserve operational safety: explicit error handling and telemetry/logging where behavior changes are critical.
- Avoid performance regressions (no query-in-loop patterns or unnecessary extra queries).
- Update docs only when externally visible behavior contracts changed.
