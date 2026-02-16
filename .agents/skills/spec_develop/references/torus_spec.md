# Torus Spec Context

## Spec-Driven Development Model
Treat each feature as a versioned spec pack under one of:

- `docs/features/<feature_slug>/`
- `docs/epics/<epic_slug>/<feature_slug>/`

- `prd.md`: product requirements and acceptance criteria.
- `fdd.md`: architecture and technical design.
- `plan.md`: phased execution plan and gates.

## Roles and Outputs
- `analyze` updates `prd.md`.
- `architect` updates `fdd.md`.
- `plan` updates `plan.md`.
- `develop` implements plan phases and keeps all spec docs aligned.

## Guardrails
- Assume Torus context: Elixir/Phoenix LiveView, Ecto/Postgres, multi-tenancy, LTI 1.3, WCAG AA, AppSignal telemetry.
- Keep behavior testable and specific; preserve FR/AC traceability.
- Respect roles/permissions, tenant boundaries, performance posture, observability, and migration/rollback constraints.
- If specs conflict with implementation reality, update specs first and then continue implementation.
