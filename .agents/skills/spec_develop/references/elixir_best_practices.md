# Elixir Best Practices (Spec Develop)

- Keep context boundaries explicit; avoid leaking persistence concerns into LiveViews.
- Prefer `with` and pattern matching for multi-step control flow.
- Keep changeset validation close to schema/domain boundaries.
- Avoid queries in loops; preload or batch where possible.
- Ensure multi-tenant and role checks are explicit and test-covered.
- Add telemetry for new critical flows and failure paths.
- Write regression tests for bug-prone branches.
- Keep migrations online-safe and reversible.
