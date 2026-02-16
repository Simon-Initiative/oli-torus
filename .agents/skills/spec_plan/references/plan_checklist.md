# Plan Checklist

- Use numbered phase headings (`## Phase <n>:`).
- Every phase must include:
  - Goal
  - Task checklist
  - Testing tasks (tests to write/run plus commands)
  - Definition of Done
  - Gate
- Confirm `prd.md` and `fdd.md` both exist and are referenced.
- Use dependency-ordered phases (topological order).
- Explicitly call out which tasks/phases can run in parallel.
- Capture unknowns as clarifications with default assumptions.
- Identify dependency order and safe parallel work.
- Include non-functional guardrails and rollout assumptions.
- Include non-functional threads in phase tasks: security/authz, tenancy, migrations/backfills, caching/invalidation, observability, performance verification, docs.
- Do not include dedicated traffic-simulation test planning.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers.
