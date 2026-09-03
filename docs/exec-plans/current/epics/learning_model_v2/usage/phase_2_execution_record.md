# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/usage`
Phase: `2 - Extract the Naive Provider and Implement LKT-AOA Objective Reads`

## Scope from plan.md

- Establish the naive provider's shared objective primitives without changing production consumers.
- Implement canonical, set-based LKT-AOA direct and effective-parent objective reads.
- Preserve evidence/confidence fields and add bounded, identifier-free provider telemetry.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Implemented:

- Added `Oli.Delivery.Proficiency.Naive` as owner of the legacy raw objective tuple, first-attempt formula, evidence gate, and inclusive naive bucket boundaries.
- Added `Oli.Delivery.Proficiency.LktAoa` with one set-based `learning_states` query for requested learner/objective identities and selected fields only.
- Added effective-parent derivation from requested SectionResources, attempt-count weighting, a three-total-attempt gate, and deterministic SectionResource-ID precedence.
- Added one bounded provider telemetry span per operation, including success, returned-error, and exception metadata without Section, learner, objective, or attempt identifiers.
- Added source documentation for the naive-only tuple, model boundary difference at `0.4`, direct versus parent evidence rules, derived parent state, and parent weighting.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- Phase 2 Gate B command: 52 tests, 0 failures.
- `mix format` and `mix format --check-formatted` on changed Elixir/test files: passed.
- `mix compile --warnings-as-errors`: passed.
- `git diff --check`: passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

The plan and FDD now distinguish Gate B provider primitives from AC-008's complete heterogeneous Metrics-adapter migration, which remains in the already-planned Phase 5 consumer work. No new open question was introduced.

## Review Loop

- Round 1 findings:
  - Security: no findings.
  - Performance: telemetry allocated and traversed a flattened estimate list, LKT loaded full state structs and all course objectives, and naive empty requests queried PostgreSQL.
  - Elixir: telemetry assumed every success was a nested estimate map; LKT objective resolution was course-wide.
- Round 1 fixes:
  - Count telemetry results in one pass and support both canonical estimate and aggregate maps.
  - Select only used state fields, add a bounded requested-objective depot resolver, and skip empty naive/LKT reads.
- Round 2 findings:
  - The bounded child resolver merged SectionResource-ID and resource-ID namespaces, permitting integer collisions.
  - Depot resolution latency sat outside telemetry; direct/parent query scaling and failure telemetry needed stronger proof.
  - Phase 2 documentation overstated AC-008 closure even though production consumer adapters are planned for Phase 5.
- Round 2 fixes:
  - Preserve SectionResource-ID precedence with a collision regression test.
  - Include resolution in the provider span, add small-versus-large direct/parent query assertions, and cover returned-error and exception telemetry.
  - Reconcile Gate B and Gate E traceability for staged naive compatibility work.
- Round 3 finding:
  - Canonical naive estimates did not directly exercise all evidence and bucket boundaries even though the compatibility string bucketer did.
- Round 3 fix:
  - Add canonical-provider tests for missing state, score suppression below three first attempts, exact `0.4`/`0.8`, and adjacent Medium/High values.
- Final re-review:
  - Security, performance, Elixir, and requirements: no remaining findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
