# Data Oracles - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/intelligent_dashboard/data_oracles/prd.md`
- FDD: `docs/epics/intelligent_dashboard/data_oracles/fdd.md`
- Epic context: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/plan.md`

## Scope
Deliver `MER-5301` by implementing shared oracle contracts (`Oli.Dashboard.*`), instructor-specific registry composition (`Oli.InstructorDashboard.*`), prerequisite-aware dependency planning, deterministic validation failures, and migration of covered instructor dashboard consumers away from direct analytics query helpers.

## Non-Functional Guardrails
- Keep dependency/profile resolution deterministic with typed validation failures and stable outcomes.
- Enforce tenant and authorization boundaries before oracle execution context is built.
- Avoid raw PII in telemetry/log metadata from registry and contract layers.
- No schema migration or backfill is introduced in this feature.
- No user-facing feature flag is required; rollout is internal and gated by tests and no-bypass checks.
- Performance benchmarks and latency-threshold testing are out of scope for `MER-5301` and handled in separate tickets.

## Clarifications & Default Assumptions
- Initial instructor consumer keys are capability-centric and may use provisional names until tile stories finalize concrete oracle bindings.
- `Oli.Dashboard.ScopeResolver` reuses existing section hierarchy/container utilities (for example `SectionResourceDepot`) instead of introducing new hierarchy storage.
- Covered no-bypass migration scope for this feature is the instructor dashboard code paths called out in FDD section 3 (`section_analytics` and `instructor_dashboard_live`) plus any newly touched helper modules.
- Runtime orchestration ownership remains in `MER-5302`; this feature provides contracts and planner behavior only.
- Since there is no persistence change, rollback is code-only (module revert) with no data migration rollback path required.

## AC Traceability Targets
- AC-001: Deterministic required/optional dependency resolution for known consumer keys.
- AC-002: Deterministic unknown-consumer validation error.
- AC-003: Deterministic oracle-module lookup and single-module resolution.
- AC-004: Canonical `OracleContext` and contract-compliant oracle result envelopes.
- AC-005: No direct analytics query path for covered dashboard consumers.
- AC-006: Extension workflow allows adding an oracle without changing unrelated consumers.
- AC-007: Shared contracts remain reusable by non-instructor product registries.
- AC-008: Prerequisite oracle planning loads shared prerequisites once and injects payloads into dependents.
- AC-009: Unit tests use mocked/stubbed concrete oracle modules for boundary interaction coverage.

## Phase 1: Shared Contract Foundations
- Goal: Establish the shared contracts and context primitives that all downstream registry/runtime/cache work depends on.
- Tasks:
  - [ ] Implement `Oli.Dashboard.Scope` (`new/1`, `normalize/1`, `container_key/1`, `course_scope?/1`) with deterministic validation errors.
  - [ ] Implement `Oli.Dashboard.ScopeResolver` authorization-aware scope resolution and container validation using existing section/container infra.
  - [ ] Implement immutable `Oli.Dashboard.OracleContext` (`new/1`, `with_scope/2`, `to_metadata/1`) with explicit allowed fields.
  - [ ] Implement shared `Oli.Dashboard.Oracle` behavior and `Oli.Dashboard.Oracle.Result` helpers (`ok/3`, `error/3`, `stale?/1`).
  - [ ] Add module docs/typespecs that codify shared-vs-product boundaries and no inter-oracle direct-calling rule.
- Testing Tasks:
  - [ ] Add unit tests for scope normalization, invalid scope payloads, scope resolver authz checks, and oracle context field validation.
  - [ ] Add unit tests for oracle result envelope shape and metadata sanitization behavior.
  - [ ] Command(s): `mix test test/oli/dashboard/scope_test.exs test/oli/dashboard/scope_resolver_test.exs test/oli/dashboard/oracle_context_test.exs test/oli/dashboard/oracle_result_test.exs`
  - [ ] Pass criteria: all phase tests pass and no existing dashboard tests regress.
- Definition of Done:
  - Shared scope/context/behavior/result modules compile with complete docs and typespecs.
  - Deterministic typed errors exist for invalid scope/context inputs.
  - Security boundary is explicit: resolver rejects unauthorized container scopes before context creation.
- Gate:
  - Gate A passes when contract primitives are stable enough for registry/planner implementation.
- Dependencies:
  - None.
- Parallelizable Work:
  - `Scope` + `OracleContext` implementation can run in parallel with `Oracle.Result` helper work because contracts join only through shared types and tests.

## Phase 2: Registry Contracts, Planner, and Validation
- Goal: Deliver deterministic dependency resolution, module lookup, and prerequisite execution planning with startup/test validation.
- Tasks:
  - [ ] Implement `Oli.Dashboard.OracleRegistry` behavior callbacks (`dependencies_for/2`, `required_for/2`, `optional_for/2`, `oracle_module/2`, `execution_plan_for/2`, `known_consumers/1`).
  - [ ] Implement `Oli.Dashboard.OracleDependencyPlanner` with topological staging, cycle detection, and duplicate/self-reference rejection.
  - [ ] Implement `Oli.Dashboard.OracleRegistry.Validator` for declaration integrity checks and compile/startup validation hook.
  - [ ] Define typed error tuples for unknown consumer, unknown oracle, invalid declaration, and dependency cycle failures.
  - [ ] Expose deterministic dependency profile introspection structures for downstream runtime/cache/snapshot consumers.
- Testing Tasks:
  - [ ] Add unit tests for required/optional resolution ordering determinism and error determinism.
  - [ ] Add planner tests for prerequisite fan-in/fan-out, shared prerequisite single-load semantics, and cycle detection.
  - [ ] Add validator tests covering undeclared oracle keys, missing module bindings, duplicate keys, and invalid profiles.
  - [ ] Command(s): `mix test test/oli/dashboard/oracle_registry_behavior_test.exs test/oli/dashboard/oracle_dependency_planner_test.exs test/oli/dashboard/oracle_registry_validator_test.exs`
  - [ ] Pass criteria: phase tests prove AC-001, AC-002, AC-003, and AC-008 behaviors at contract level.
- Definition of Done:
  - Registry/planner/validator modules compile and pass deterministic behavior tests.
  - Startup/test validation catches invalid declarations before runtime execution.
  - Prerequisite execution plans are stable and acyclic for valid inputs.
- Gate:
  - Gate B passes when planner and validation outputs are stable for product-specific wiring.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Planner implementation and validator implementation can proceed in parallel after behavior signatures are frozen.

## Phase 3: Instructor Registry Composition and Extension Workflow
- Goal: Bind instructor capability consumers to oracle slots/modules using shared contracts while preserving reusable shared boundaries.
- Tasks:
  - [ ] Implement `Oli.InstructorDashboard.OracleRegistry` wrapper APIs (`registry/0`, `dependencies_for/1`, `required_for/1`, `optional_for/1`, `oracle_module/1`, `known_consumers/0`).
  - [ ] Implement `Oli.InstructorDashboard.OracleBindings` for capability/slot mapping to oracle keys/modules with placeholder-friendly defaults.
  - [ ] Add registry bootstrap validation call path for instructor registry declarations.
  - [ ] Document extension workflow: add oracle module, register dependency profile, run validator/tests, and avoid unrelated consumer churn.
  - [ ] Add reusable boundary checks proving shared contracts can support a non-instructor registry without signature changes.
- Testing Tasks:
  - [ ] Add unit tests using mocked/stubbed oracle modules to verify registry resolution and module lookup integration boundaries.
  - [ ] Add contract tests verifying callback conformance (`key/0`, `version/0`, `requires/0`, `load/2`, optional `project/2`) and prerequisite input injection shape.
  - [ ] Add extension safety tests proving adding one oracle to one consumer leaves unrelated consumer profiles unchanged.
  - [ ] Command(s): `mix test test/oli/instructor_dashboard/oracle_registry_test.exs test/oli/instructor_dashboard/oracle_bindings_test.exs test/oli/dashboard/oracle_contract_test.exs`
  - [ ] Pass criteria: phase tests prove AC-004, AC-006, AC-007, and AC-009 at product composition boundaries.
- Definition of Done:
  - Instructor registry and bindings are fully functional on shared contracts with deterministic outputs.
  - Extension workflow is documented and verified by tests.
  - Mock/stub oracle boundary tests are present and stable.
- Gate:
  - Gate C passes when instructor composition is ready for migration of covered consumers.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Documentation of extension workflow can run in parallel with registry/bindings implementation once interfaces are stable.

## Phase 4: No-Bypass Migration for Covered Consumers
- Goal: Remove direct analytics query usage for covered instructor dashboard domains and route them through oracle contract paths.
- Tasks:
  - [ ] Audit covered instructor dashboard consumers for direct query helper usage and map each call site to registry/runtime-facing APIs.
  - [ ] Refactor covered call sites in instructor dashboard modules to consume dependency/profile outputs instead of direct analytics helpers.
  - [ ] Add guardrails (tests and/or lint assertions in targeted modules) preventing reintroduction of direct analytics query calls for covered paths.
  - [ ] Add migration parity checklist for covered domains to verify metric continuity during transition.
  - [ ] Ensure tenant identifiers and authz-scoped context are propagated unchanged through migrated paths.
- Testing Tasks:
  - [ ] Add integration tests that exercise covered consumer flows and assert oracle-path usage (no direct helper fallback).
  - [ ] Add regression tests around unknown consumer/oracle failure propagation to LiveView-facing callers.
  - [ ] Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs test/oli_web/components/delivery/instructor_dashboard/section_analytics_test.exs test/oli/instructor_dashboard/oracle_migration_test.exs`
  - [ ] Pass criteria: AC-005 is demonstrably satisfied for covered domains with green regression tests.
- Definition of Done:
  - Covered call sites no longer require direct analytics query helpers.
  - Integration tests fail if direct-query bypass is reintroduced in covered modules.
  - Tenant/authz context remains intact after migration.
- Gate:
  - Gate D passes when migration and no-bypass assertions are green.
- Dependencies:
  - Phase 3.
- Parallelizable Work:
  - Call-site refactors and no-bypass regression test authoring can run in parallel by splitting files/module ownership once migration map is finalized.

## Phase 5: Observability and Release Readiness
- Goal: Finalize telemetry, reliability checks, and operational handoff artifacts for downstream Lane 1 slices.
- Tasks:
  - [x] Implement telemetry emission for registry/contract typed error counters and PII-safe metadata.
  - [x] Add AppSignal metric mapping/documentation for registry outcome and error signals.
  - [x] Confirm documentation clearly states performance validation is deferred to separate tickets.
  - [x] Finalize operational notes: startup validation behavior, rollback posture (code-only), and downstream contract handoff (`MER-5302`/`MER-5303`/`MER-5304`).
  - [x] Update docs to capture final shared/product boundary decisions and extension guidance.
- Testing Tasks:
  - [x] Add telemetry tests for event names, metadata keys, and error tagging semantics.
  - [x] Run full targeted suite and smoke full backend suite.
  - [x] Command(s): `mix test test/oli/dashboard/oracle_observability_test.exs test/oli/instructor_dashboard`
  - [x] Command(s): `mix test`
  - [ ] Pass criteria: telemetry/reliability checks pass and no regressions appear in the full suite.
- Definition of Done:
  - Observability events and metrics are in place and privacy-safe.
  - Performance validation ownership is explicitly deferred to separate tickets.
  - Documentation and operational handoff are complete for downstream data-infra stories.
- Gate:
  - Gate E passes when all targeted tests and full regression suite are green and all phase artifacts are complete.
- Dependencies:
  - Phase 4.
- Parallelizable Work:
  - Telemetry instrumentation and documentation updates can run in parallel.

## Parallelisation Notes
- Phase 1 can split into two tracks after interface sketch: `Scope`/`ScopeResolver` and `OracleContext`/`Oracle.Result`.
- Phase 2 can split into planner and validator tracks after registry behavior signatures are set.
- Phase 3 can split into instructor registry wiring and extension-doc/test track once shared contracts are stable.
- Phase 4 can split by module ownership for migration and by test ownership for no-bypass guardrails.
- Phase 5 can split telemetry/docs and release-readiness checks, but final gate requires both tracks to converge before release readiness.

## Phase Gate Summary
- Gate A (after Phase 1): Shared contract primitives and security-scoped context creation are stable.
- Gate B (after Phase 2): Deterministic registry/planner/validator behavior is proven by tests.
- Gate C (after Phase 3): Instructor composition and extension workflow are verified with stubbed boundary tests.
- Gate D (after Phase 4): Covered consumers are migrated and no-bypass checks are enforced.
- Gate E (after Phase 5): Observability, documentation, and full regression checks are complete.
