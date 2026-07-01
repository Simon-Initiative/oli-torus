# Data Snapshot - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/intelligent_dashboard/data_snapshot/prd.md`
- FDD: `docs/epics/intelligent_dashboard/data_snapshot/fdd.md`
- Epic context: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/plan.md`

## Scope
Deliver `MER-5304` by implementing canonical snapshot and projection contracts in `Oli.Dashboard.Snapshot.*` and `Oli.InstructorDashboard.DataSnapshot.*`, enforcing queryless transformation boundaries, enabling capability-level incremental readiness for dashboard consumers, and delivering transform-only CSV export reuse from the same scoped snapshot/projection bundle.

## Non-Functional Guardrails
- Keep strict one-way boundaries: `DataSnapshot` may orchestrate through coordinator/cache APIs; assembler/projection/export modules remain queryless and policy-agnostic.
- Preserve tenant/context isolation by requiring normalized, authorized scope/context metadata on every snapshot build/read path.
- Emit PII-safe telemetry and AppSignal-aligned metrics for assembly/projection/export outcomes and status distribution.
- No relational schema migration or backfill is introduced; rollback posture is code-only.
- No user-facing feature flag is required for baseline rollout; rollout is gated by regression checks.
- No dedicated performance/load/benchmark testing is included in `MER-5304`; performance posture is enforced through telemetry/AppSignal instrumentation and monitoring.

## Clarifications & Default Assumptions
- Default export policy for v1 is `fail_closed` when a required projection is `failed`; optional datasets may be skipped only when explicitly configured in registry policy.
- Projection version negotiation is deploy-time contract management in baseline (not runtime negotiated per request).
- Concrete instructor oracle keys/modules are finalized by tile stories, and this feature consumes active registry bindings without hard-coding tile-owned query behavior.
- `DataSnapshot.get_or_build/2` relies on stable coordinator/cache interfaces from `data_coordinator`/`data_cache`; if those interfaces change, adapters in this feature are updated without changing assembler/projection contracts.
- Because there is no persistence change, operational rollback is module/config revert plus cache warmup monitoring only.

## AC Traceability Targets
- AC-001: Deterministic assembly produces consumable ready projections without global readiness barrier.
- AC-002: UI projections and CSV datasets remain semantically equivalent for shared metrics.
- AC-003: Export path executes transform-only logic and does not trigger independent analytics queries.
- AC-004: Partial readiness follows deterministic dataset inclusion/exclusion policy.
- AC-005: Required projection failures produce deterministic export failure reason codes.
- AC-006: Boundary checks enforce no queue/token/cache-policy logic and no direct oracle/query calls in assembler/projection/export.
- AC-007: Contract versioning supports prior projection schema compatibility during migration windows.
- AC-008: Unit/integration tests use mocked or stubbed concrete dependencies where needed at component boundaries.

## Phase Gate Summary
- Gate A (after Phase 1): Contract structs/versioning and boundary guardrails are stable and test-covered.
- Gate B (after Phase 2): Assembler/projection derivation semantics and incremental readiness behavior are deterministic.
- Gate C (after Phase 3): `DataSnapshot` orchestration integration is stable with cache/coordinator boundaries and tenant guards.
- Gate D (after Phase 4): Transform-only CSV export and deterministic partial/failure policies are verified.
- Gate E (after Phase 5): Observability/docs/regression checks are complete and release-ready.

## Phase 1: Snapshot Contracts and Boundary Foundations
- Goal: Establish canonical snapshot/projection contracts, versioning fields, and hard boundary rules required by all downstream work.
- Tasks:
  - [x] Implement `Oli.Dashboard.Snapshot.Contract` structs/types for snapshot bundle, projection payloads, and status enums (`ready`, `partial`, `failed`, `unavailable`).
  - [x] Implement version metadata fields (`snapshot_version`, `projection_version`) and compatibility helpers for additive schema evolution.
  - [x] Define reason-code taxonomy for projection and export failures, including deterministic mapping rules used by downstream modules.
  - [x] Add boundary guardrails in shared docs/typespecs/tests proving assembler/projection/export modules do not call queue/token/cache-policy or direct oracle/query APIs (AC-006).
  - [x] Enforce scope/context metadata requirements on contract constructors so tenant/context identity is always explicit.
- Testing Tasks:
  - [x] Add unit tests for contract shape, enum validation, version compatibility helpers, and deterministic reason-code mapping.
  - [x] Add boundary tests asserting prohibited module dependencies/calls in snapshot transformation modules.
  - [x] Command(s): `mix test test/oli/dashboard/snapshot/contract_test.exs test/oli/dashboard/snapshot/boundary_test.exs`
  - [x] Pass criteria: AC-006 references are present and Phase 1 tests pass without regressions.
- Definition of Done:
  - Contract modules compile with complete typespecs/docs and deterministic validation failures.
  - Version fields and compatibility helpers are test-covered.
  - Boundary protections and tenant/context identity requirements are explicit and verified.
- Gate:
  - Gate A passes when contract and boundary primitives are stable for assembler/projection implementation.
- Dependencies:
  - External prerequisite: lane-level contract outputs from `data_oracles` and cache/coordinator public interfaces are available.
- Parallelizable Work:
  - Contract/version helper implementation can run in parallel with boundary-test authoring once module names and behaviors are frozen.

## Phase 2: Assembler and Projection Derivation Core
- Goal: Build deterministic snapshot assembly and capability-scoped projection derivation with no global readiness barrier.
- Tasks:
  - [x] Implement `Oli.Dashboard.Snapshot.Assembler.assemble/4` and oracle-envelope merge helpers for deterministic snapshot construction (AC-001).
  - [x] Implement `Oli.Dashboard.Snapshot.Projections.derive_all/2` and `derive/3` with per-capability readiness status emission and explicit partial/failure metadata.
  - [x] Implement instructor capability projection modules under `Oli.InstructorDashboard.DataSnapshot.Projections.*` (`summary`, `progress`, `student_support`, `challenging_objectives`, `assessments`, `ai_context`).
  - [x] Ensure ready capabilities are emitted immediately and not blocked by unrelated projection readiness (AC-001).
  - [x] Add projection-level telemetry/AppSignal-friendly measurements for duration, status, and reason-code distribution.
- Testing Tasks:
  - [x] Add unit tests for deterministic assembly output and projection status transitions (`ready`, `partial`, `failed`, `unavailable`).
  - [x] Add unit tests for mixed oracle completeness ensuring ready projections are consumable without global barrier.
  - [x] Add projection module tests using mocked/stubbed oracle payload envelopes where needed for boundary interactions (AC-008).
  - [x] Command(s): `mix test test/oli/dashboard/snapshot/assembler_test.exs test/oli/dashboard/snapshot/projections_test.exs test/oli/instructor_dashboard/data_snapshot/projections_test.exs`
  - [x] Pass criteria: AC-001 and AC-008 behaviors are proven with deterministic passing tests.
- Definition of Done:
  - Assembler and projection core APIs are implemented with deterministic outcomes.
  - Incremental per-capability readiness semantics are test-verified.
  - Projection observability events are emitted with privacy-safe metadata.
- Gate:
  - Gate B passes when assembly/projection behavior is stable for orchestration and export integration.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Instructor capability projection module implementation can run in parallel with assembler merge helper work after shared contract shapes are fixed.

## Phase 3: DataSnapshot Orchestration and Consumer Integration
- Goal: Implement `DataSnapshot` orchestration APIs that consume coordinator/cache outputs and expose snapshot/projection retrieval to dashboard consumers.
- Tasks:
  - [x] Implement `Oli.InstructorDashboard.DataSnapshot.get_or_build/2` orchestration path using coordinator/cache interfaces without embedding queue/token/cache policy logic (AC-006).
  - [x] Implement `Oli.InstructorDashboard.DataSnapshot.get_projection/3` for capability-specific retrieval with deterministic error tuples and reason codes.
  - [x] Propagate normalized scope/context metadata and enforce authorization/tenant identity invariants through orchestration entry points.
  - [x] Add request-scoped memoization hooks (ephemeral only) where needed to avoid duplicate derivations in a single request lifecycle.
  - [x] Update integration docs for consumer handoff to tile/LiveView and CSV callers, including feature-flag posture (`none`) and rollback posture.
- Testing Tasks:
  - [x] Add integration tests for cache-hit, cache-miss, and mixed runtime/oracle completion paths producing stable snapshot bundles.
  - [x] Add tests for tenant/context isolation and authz propagation at orchestration entry points.
  - [x] Add regression tests that assert no queue/token/cache-policy behavior leaks into snapshot modules (AC-006).
  - [x] Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/data_snapshot_test.exs test/oli/instructor_dashboard/data_snapshot/orchestration_boundary_test.exs`
  - [x] Pass criteria: orchestration tests pass and boundary checks remain green.
- Definition of Done:
  - `DataSnapshot` orchestration APIs are stable and deterministic.
  - Tenant/authz scope handling is verified by tests.
  - Consumer integration documentation is updated for downstream tiles/export callers.
- Gate:
  - Gate C passes when orchestration behavior is stable and boundary-safe for export integration.
- Dependencies:
  - Phase 2.
  - External dependency: stable cache facade/coordinator APIs from `data_cache` and `data_coordinator`.
- Parallelizable Work:
  - Authz/tenant isolation tests can run in parallel with request-scope memoization and docs updates once orchestration API signatures are frozen.

## Phase 4: Dataset Registry and Transform-Only CSV Export
- Goal: Deliver deterministic transform-only CSV ZIP generation from snapshot/projection contracts with explicit partial/failure behavior.
- Tasks:
  - [x] Implement `Oli.InstructorDashboard.DataSnapshot.DatasetRegistry` mapping export profiles to dataset specs (`required_projections`, `optional_projections`, `serializer_module`, `failure_policy`).
  - [x] Implement `Oli.InstructorDashboard.DataSnapshot.CsvExport.build_zip/2` and serializer adapters using snapshot/projection inputs only (AC-003).
  - [x] Enforce deterministic dataset inclusion/exclusion rules for partial projection states (AC-004).
  - [x] Enforce deterministic fail-closed behavior with explicit reason codes when required projection data is unavailable (AC-005).
  - [x] Ensure UI/CSV semantic equivalence remains covered through shared snapshot/projection contracts and deterministic transform tests (AC-002).
- Testing Tasks:
  - [x] Add registry mapping tests proving dataset requirements and failure policies are deterministic.
  - [x] Add export tests that assert no independent analytics query path is executed and only transform inputs are consumed (AC-003).
  - [x] Add tests for partial inclusion policy and required-failure reason-code behavior (AC-004, AC-005).
  - [x] Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/dataset_registry_test.exs test/oli/instructor_dashboard/data_snapshot/csv_export_test.exs`
  - [x] Pass criteria: AC-002, AC-003, AC-004, and AC-005 are proven by passing targeted tests.
- Definition of Done:
  - Dataset registry and CSV export modules are deterministic and transform-only.
  - Partial/failure policies are explicit, test-covered, and consistent with product assumptions.
  - AC-002 equivalence coverage is present through transform-only export tests and shared contracts.
- Gate:
  - Gate D passes when export behavior and no-query guarantees are verified.
- Dependencies:
  - Phase 3.
- Parallelizable Work:
  - Dataset registry implementation and serializer adapter development can run in parallel after projection contract signatures are stable.

## Phase 5: Observability and Release Readiness
- Goal: Complete telemetry/AppSignal posture, requirements traceability, and final release gates.
- Tasks:
  - [x] Remove runtime equivalence-comparison instrumentation from snapshot/export flows and docs while preserving AC-002 contract/test coverage.
  - [x] Finalize telemetry events for assembly/projection/export outcomes, including status and reason-code dimensions without raw PII.
  - [x] Add AppSignal metric mapping/documentation for snapshot readiness distribution and export failure taxonomy.
  - [x] Confirm no schema migration/backfill work was introduced and record operational rollback checklist.
  - [x] Update feature docs (`prd`/`fdd` decision log only if needed) with final boundary, policy, and rollout decisions.
- Testing Tasks:
  - [x] Update telemetry/export tests for event names and metadata keys after runtime equivalence-comparison removal.
  - [x] Run targeted suite for snapshot/orchestration/export modules and a full backend regression pass.
  - [x] Command(s): `mix test test/oli/dashboard/snapshot test/oli/instructor_dashboard/data_snapshot`
  - [x] Command(s): `mix test`
  - [x] Pass criteria: targeted and full suites pass; AC-002 equivalence coverage remains green.
- Definition of Done:
  - Observability is complete and privacy-safe with no runtime equivalence-comparison instrumentation.
  - Documentation and operational readiness notes are synchronized with implementation.
  - Final regression gate is green and release handoff is complete.
- Gate:
  - Gate E passes when observability, documentation, and regression requirements are fully satisfied.
- Dependencies:
  - Phase 4.
- Parallelizable Work:
  - Telemetry/AppSignal documentation updates can run in parallel with export telemetry test updates before final regression execution.

## Parallelisation Notes
- Phase 1 is the root gate.
- After Gate A, Phase 2 starts and can split between assembler core and instructor projection module tracks.
- After Gate B, Phase 3 starts; orchestration wiring and security/tenant test tracks can proceed concurrently.
- After Gate C, Phase 4 starts; dataset registry and CSV serializer tracks run in parallel and converge for policy tests.
- Phase 5 starts after Gate D; observability/docs and regression tracks can run in parallel until final gate convergence.
