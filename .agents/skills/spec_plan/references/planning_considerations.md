# Planning Considerations

Apply these considerations when drafting `plan.md`:

- Input prerequisites:
  - Both `prd.md` and `fdd.md` are required before planning starts.
- Dependency and sequencing:
  - Build a dependency graph and order phases topologically.
  - Prefer early risk burn-down for uncertain/high-impact work.
  - Maximize safe parallelism when dependencies allow.
- Task granularity:
  - Break into small, testable tasks with clear ownership hints and deliverable outcomes.
- Test-first execution:
  - Include test creation/execution tasks in each phase, not just summary verification text.
  - Define commands and pass criteria to advance.
- Non-functional threads:
  - Security/authz, multi-tenant isolation, migration/backfill safety, cache invalidation, observability instrumentation, and documentation updates.
  - Include performance verification work tied to NFR targets.
- Rollout and operations:
  - Include feature flag posture when applicable, rollout/rollback checkpoints, and operational readiness checks.
- Clarity:
  - Convert unknowns into explicit clarifications with default assumptions.
  - Remove ambiguity and ensure every phase has a concrete gate.

Do not include dedicated traffic-simulation test planning in this skill.
