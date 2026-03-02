# Approach

Use this implementation sequence:

1. Read spec pack (`prd.md`, `fdd.md`, `plan.md`) and scope to the assigned phase.
2. If a phase selector is provided, implement only that phase.
3. Execute phase tasks in dependency order and keep a running execution record.
4. Implement tests alongside behavior changes.
5. Do not author dedicated performance/load/benchmark tests; implement telemetry/AppSignal instrumentation for performance posture instead.
6. End-of-phase technical gate:
   - `mix compile` with zero warnings.
   - New and affected tests pass.
7. End-of-phase review gate:
   - Run `spec_review` after compile/tests.
   - Fix high/medium findings.
8. If implementation diverges from spec, update `prd.md`/`fdd.md`/`plan.md` accordingly.
9. Run postflight spec validation and do not mark complete until it passes.
