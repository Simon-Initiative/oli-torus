# Torus Spec Context

## Spec-Driven Development Model
Treat each feature as a versioned "spec pack" under one of:

- `docs/features/<feature_slug>/`
- `docs/epics/<epic_slug>/<feature_slug>/`

- `prd.md`: problem, goals, users, scope, FRs, ACs.
- `fdd.md`: system design, architecture boundaries, interfaces, data impacts, observability, rollout.
- `plan.md`: milestones, tasks, sequencing, risk controls, QA and rollout execution.

## Roles and Outputs
- `analyze` updates `prd.md`.
- `architect` updates `fdd.md`.
- `plan` updates `plan.md`.
- `develop` implements to spec and keeps all docs current.

## Guardrails
- Assume Torus platform constraints: Elixir/Phoenix LiveView, Ecto/Postgres, multi-tenancy, LTI 1.3, WCAG AA, AppSignal and telemetry.
- Keep requirements testable and specific (FR IDs, Given/When/Then ACs).
- Make assumptions explicit and list open questions.
- Respect role/permission boundaries, tenant isolation, performance posture, observability, and migration/rollback constraints.
- If code and spec conflict, update the spec first; implementation must follow the latest `prd.md` and `fdd.md`.

## Workflow Gates
- Analyze finalizes `prd.md`.
- Architect finalizes `fdd.md`.
- Plan finalizes `plan.md`.
- Develop implements and verifies against acceptance criteria and telemetry expectations.
