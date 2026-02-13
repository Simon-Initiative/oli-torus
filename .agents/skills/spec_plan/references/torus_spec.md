# Torus Spec Context

## Spec-Driven Development Model
Treat each feature as a versioned spec pack under one of:

- `docs/features/<feature_slug>/`
- `docs/epics/<epic_slug>/<feature_slug>/`

- `prd.md`: product requirements and acceptance criteria.
- `fdd.md`: technical design and architecture decisions.
- `plan.md`: phased execution plan, dependencies, QA, rollout and operational gates.

## Roles and Outputs
- `analyze` updates `prd.md`.
- `architect` updates `fdd.md`.
- `plan` updates `plan.md`.
- `develop` implements and keeps all spec docs in sync.

## Guardrails
- Assume Torus context: Elixir/Phoenix LiveView, Ecto/Postgres, multi-tenancy, LTI 1.3, WCAG AA, AppSignal/telemetry.
- Keep work testable and specific with traceability back to FR/AC.
- Respect role/permission boundaries, tenant isolation, operational safety, and rollback readiness.
- If specs and implementation diverge, update specs first and align execution to latest `prd.md` and `fdd.md`.
