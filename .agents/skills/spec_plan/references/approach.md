# Approach

Follow this method to produce `plan.md`:

1. Ingest and align:
   - Read PRD and FDD.
   - Extract scope, constraints, and hidden coupling points.
   - Record clarifications and default assumptions.
2. Build work breakdown:
   - Derive small, testable tasks.
   - Group tasks into phases and map dependencies.
3. Sequence by dependency and risk:
   - Topologically sort phases.
   - Break ties by highest uncertainty first, then by maximizing parallel tracks.
4. Thread verification through execution:
   - Add tests as explicit tasks in each phase.
   - Add command-level verification and phase gate criteria.
5. Ensure non-functional coverage:
   - Security, tenancy, data safety, observability, caching, migration, rollout, and docs.
6. Final ambiguity pass:
   - Resolve vague items before finalizing.
