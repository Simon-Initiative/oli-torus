# Torus Spec Context

## Spec-Driven Development Model
Treat each feature as a versioned spec pack under one of:

- `docs/features/<feature_slug>/`
- `docs/epics/<epic_slug>/<feature_slug>/`

- `prd.md`: product requirements and acceptance criteria.
- `fdd.md`: technical/functional design.
- `plan.md`: delivery sequencing, risks, QA and rollout execution.

## Roles and Outputs
- `analyze` updates `prd.md`.
- `architect` updates `fdd.md`.
- `plan` updates `plan.md`.
- `develop` implements to spec and keeps docs aligned.

## Guardrails
- Assume Torus constraints: Elixir/Phoenix LiveView, Ecto/Postgres, multi-tenant boundaries, LTI 1.3 roles, WCAG AA, AppSignal and telemetry.
- Keep requirements testable and specific (FR IDs and Given/When/Then ACs).
- State assumptions and open questions explicitly.
- Respect role and permission boundaries, tenant isolation, performance posture, observability, and migration/rollback needs.
- If implementation and spec diverge, update spec docs first and keep code aligned to latest `prd.md` and `fdd.md`.
