# Data Oracles PRD

Last updated: 2026-02-17
Feature: `data_oracles`
Epic: `MER-5198` (Instructor Intelligent Dashboard)
Primary Jira: `MER-5301` Data Infra: Scope/Oracle Contracts and Registry
Related docs: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/prd.md`, `docs/epics/intelligent_dashboard/plan.md`, `docs/epics/intelligent_dashboard/data_coordinator/prd.md`, `docs/epics/intelligent_dashboard/data_cache/prd.md`, `docs/epics/intelligent_dashboard/data_snapshot/prd.md`

## 1. Overview

This feature defines the canonical data-access contract for dashboard consumers by introducing a shared oracle interface, deterministic dependency registry, and normalized scope/context model.

The design must fully encapsulate dashboard queries behind an oracle boundary so tile code, AI consumers, and CSV flows do not run direct analytics queries. The same shared contracts must work across any future dashboard product, while allowing Instructor Dashboard to provide product-specific dependency profiles and binding hooks. Exact concrete instructor oracle modules/keys are intentionally tile-driven and finalized in tile implementation stories.

Prototype alignment:
- Tile dependencies are best expressed as slot maps (`required_oracles/0`, `optional_oracles/0`) and canonicalized by oracle key.
- Oracle modules should not call peer oracles directly; orchestration/runtime resolves dependencies.

## 2. Background & Problem Statement

Current instructor dashboard paths still include direct analytics query calls in UI-oriented modules. This makes query behavior harder to reason about, increases duplication, and creates risk that metrics drift between tiles and downstream consumers.

Lane 1 needs a strict contract layer that makes the oracle the only query entry point for dashboard data domains. Without this layer, downstream work (`data_coordinator`, `data_cache`, `data_snapshot`) cannot enforce deterministic dependency resolution, caching, and snapshot reuse.

## 3. Goals & Non-Goals

Goals:
- Define reusable, dashboard-agnostic core contracts in `Oli.Dashboard.*` for scope normalization, oracle execution context, and oracle behavior.
- Define product-specific composition in `Oli.InstructorDashboard.*` that maps instructor capability consumers to required/optional oracle slots.
- Enforce no direct analytics query usage from tiles/LiveView consumers for covered domains.
- Provide explicit extension guidance for adding new oracle domains without changing existing consumers.

Non-Goals:
- Implementing request queueing/state machine policy (handled by `data_coordinator`).
- Implementing cache tiers, eviction, TTL, or revisit flow policy (handled by `data_cache`).
- Implementing snapshot assembly and CSV transform contracts (handled by `data_snapshot`).
- Delivering tile UI behavior.

## 4. Users & Use Cases

Users:
- Backend engineers implementing dashboard data domains.
- Engineers adding or modifying tile dependencies.
- AI and export feature engineers consuming shared dashboard data contracts.

Primary use cases:
- Resolve dependencies for a consumer (tile/summary/export/AI) to deterministic required + optional oracle keys.
- Execute oracle modules with a canonical `OracleContext` independent of datastore internals.
- Add a new oracle domain and bind it to instructor capability consumer profiles with no LiveView query changes.
- Reuse shared contracts for a future dashboard product by creating a product-specific registry implementation.

## 5. UX / UI Requirements

No direct end-user UI is delivered in this feature.

Developer UX requirements:
- Contracts are explicit in module docs and typespecs.
- Dependency resolution errors are deterministic and actionable.
- Shared-vs-product module ownership is obvious from names and boundaries.

## 6. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | System SHALL define canonical scope structs and normalization rules that support course-level and container-level scope selection. | P0 |
| FR-002 | System SHALL define canonical `OracleContext` for every oracle invocation, including dashboard context type/id, user id, and scope container selection. | P0 |
| FR-003 | System SHALL define a shared oracle behavior contract with stable callbacks (`key/0`, `version/0`, `load/2`, optional `project/2`, optional prerequisite declaration callback) and normalized result envelope semantics. | P0 |
| FR-004 | System SHALL define a shared registry contract for dependency resolution and oracle module lookup. | P0 |
| FR-005 | System SHALL provide an Instructor Dashboard registry implementation scaffold that maps instructor capability consumers to required/optional oracle slots; concrete oracle key/module bindings MAY be provisional in this layer and finalized in tile implementation stories. | P0 |
| FR-006 | System SHALL keep datastore selection internal to oracle modules; consumers SHALL be datastore-agnostic. | P0 |
| FR-007 | System SHALL support deterministic validation errors for unknown consumer keys, undeclared oracle keys, and invalid dependency declarations. | P0 |
| FR-008 | System SHALL enforce a no-bypass rule for covered dashboard domains: tile and LiveView consumers SHALL NOT execute direct analytics queries. | P0 |
| FR-009 | System SHALL define extension workflow for adding an oracle (module + registry wiring + contract tests) without modifying unrelated consumers. | P1 |
| FR-010 | System SHALL include explicit shared-vs-product boundary rules so reusable modules live in `Oli.Dashboard.*` and Instructor-specialized modules live in `Oli.InstructorDashboard.*`. | P0 |
| FR-011 | System SHALL expose deterministic dependency profile introspection to support runtime/caching/snapshot features in downstream stories. | P1 |
| FR-012 | System SHALL support oracle prerequisite dependencies declared in contracts (for example `oracle_capability_b` requires `oracle_capability_a`) and expose a deterministic execution plan where prerequisites load first and their payloads are injected into dependent oracle `load/2` calls. | P0 |
| FR-013 | System SHALL include extensive automated unit testing for oracle contracts/registry/planner behavior, and SHALL use mocked or stubbed concrete oracle modules where needed to validate end-to-end component interactions in tests. | P0 |

## 7. Acceptance Criteria

- AC-001: Given a valid instructor consumer key, when dependencies are resolved, then required and optional oracle keys are deterministic and stable.
- AC-002: Given an unknown consumer key, when dependencies are resolved, then registry returns a deterministic validation error.
- AC-003: Given a valid oracle key, when module lookup is requested, then the registry resolves exactly one implementing module.
- AC-004: Given a canonical `OracleContext`, when an oracle is executed, then it receives only contract-defined context fields and returns contract-compliant success/error envelopes.
- AC-005: Given tile or LiveView consumer code for covered domains, when code is reviewed/tested, then no direct analytics query path is required to obtain dashboard data.
- AC-006: Given a new oracle added through the extension workflow, when integrated into one consumer profile, then unrelated consumer profiles continue to resolve unchanged dependencies.
- AC-007: Given a future non-instructor dashboard product, when it implements a product-specific registry on shared contracts, then no change to shared oracle behavior signatures is required.
- AC-008: Given a dependency graph where multiple oracles require a shared prerequisite oracle, when a scope request is executed, then that prerequisite is loaded once and its payload is provided to each dependent oracle through injected prerequisite inputs.
- AC-009: Given unit test execution for this feature, mocked/stubbed concrete oracle modules are used where necessary to exercise registry resolution, prerequisite planning, and contract execution interactions end-to-end at component boundaries.

## 8. Non-Functional Requirements

Performance:
- NFR-PERF-001: Registry dependency resolution p95 <= 10ms, p99 <= 20ms per request.
- NFR-PERF-002: Registry oracle-module lookup p95 <= 2ms, p99 <= 5ms.
- NFR-PERF-003: Contract-layer validation overhead p95 <= 2ms per call site.
- NFR-PERF-004: Oracle prerequisite plan construction and validation (acyclic ordering) p95 <= 3ms, p99 <= 8ms.

Reliability:
- NFR-REL-001: Invalid declarations fail deterministically with typed errors.
- NFR-REL-002: Registry mappings are immutable at runtime by default (configuration reload requires explicit deploy-time update).

Extensibility:
- NFR-EXT-001: Contract changes are additive/versioned and do not break existing consumers.
- NFR-EXT-002: Product-specific registries can compose shared oracle contracts without forking core behavior definitions.

Security and privacy:
- NFR-SEC-001: Context inputs and dependency declarations are authorization-scoped before oracle execution.
- NFR-SEC-002: Telemetry and logs from this layer must avoid raw PII payload content.

Testability:
- NFR-TEST-001: Unit tests cover scope normalization, registry resolution, lookup validation, and behavior conformance.
- NFR-TEST-002: Integration tests verify instructor consumer profiles resolve and execute via oracle contracts only.

## 9. Data Model & APIs

Data model:
- No relational schema migration is required.
- Core contract structs and registry maps are in-memory runtime constructs.

Notional shared modules and public APIs:

- `Oli.Dashboard.Scope`
  - `new/1 :: map() -> {:ok, t()} | {:error, term()}`
  - `normalize/1 :: t() -> t()`
  - `container_key/1 :: t() -> {:course | :container, integer() | nil}`

- `Oli.Dashboard.OracleContext`
  - `new/1 :: keyword() | map() -> {:ok, t()} | {:error, term()}`
  - `with_scope/2 :: t(), Oli.Dashboard.Scope.t() -> t()`

- `Oli.Dashboard.Oracle` (behavior)
  - `key/0 :: atom()`
  - `version/0 :: non_neg_integer()`
  - `requires/0 :: [oracle_key()]` (optional, default `[]`)
  - `load/2 :: OracleContext.t(), keyword() -> {:ok, payload()} | {:error, reason()}`
  - `# opts includes injected prerequisite payloads, e.g. [inputs: %{oracle_capability_a: payload}]`
  - `project/2 :: payload(), keyword() -> term()` (optional)

- `Oli.Dashboard.OracleRegistry` (behavior)
  - `dependencies_for/2 :: registry(), consumer_key() -> {:ok, dependency_profile()} | {:error, term()}`
  - `required_for/2 :: registry(), consumer_key() -> {:ok, [oracle_key()]} | {:error, term()}`
  - `optional_for/2 :: registry(), consumer_key() -> {:ok, [oracle_key()]} | {:error, term()}`
  - `oracle_module/2 :: registry(), oracle_key() -> {:ok, module()} | {:error, term()}`
  - `execution_plan_for/2 :: registry(), [oracle_key()] -> {:ok, [[oracle_key()]]} | {:error, term()}`

Notional instructor specialization modules:

- `Oli.InstructorDashboard.OracleRegistry`
  - `registry/0`
  - `dependencies_for/1`
  - `required_for/1`
  - `optional_for/1`
  - `oracle_module/1`
- `Oli.InstructorDashboard.OracleBindings`
  - Maps instructor capability keys and oracle slots to concrete oracle module bindings.
  - Concrete bindings are intentionally tile-driven and may start as placeholders in lane-1.
- `Oli.InstructorDashboard.Oracles.*` (tile-delivered modules)
  - Concrete module names and exact callback payload shapes are finalized during tile implementation stories.

## 10. Integrations & Platform Considerations

- Integrates with downstream `Oli.Dashboard.OracleRuntime` (`MER-5302`) via registry and oracle behavior contracts.
- Integrates with `Oli.Dashboard.Cache` and `Oli.Dashboard.RevisitCache` (`MER-5303`) through stable oracle keys and versions.
- Integrates with `Oli.Dashboard.Snapshot.Assembler` and `Oli.InstructorDashboard.DataSnapshot` (`MER-5304`) through deterministic dependency profiles.
- Container and hierarchy metadata should leverage existing section resource/hierarchy infrastructure (for example `SectionResourceDepot`) rather than duplicating hierarchy logic.

## 11. Feature Flagging, Rollout & Migration

- No user-facing feature flag is required for this infrastructure slice.
- Rollout is internal and phased:
  1. Add shared contracts and instructor registry.
  2. Introduce provisional instructor capability-to-oracle bindings behind those contracts.
  3. Migrate covered dashboard consumers away from direct query helpers to registry/oracle paths.
- Migration guardrail: maintain parity checks during transition so consumer metrics remain consistent.

## 12. Analytics & Success Metrics

- Registry resolution latency (`p50`, `p95`, `p99`).
- Registry validation error count (unknown consumer, unknown oracle, invalid declaration).
- Oracle contract execution count by `oracle_key` and `dashboard_context_type`.
- Dashboard consumer adoption coverage (`oracle-path requests / total requests`) with target `100%` for in-scope instructor surfaces.

## 13. Risks & Mitigations

- Risk: contracts overfit current instructor tile set.
  - Mitigation: shared behavior + product-specific registries and consumer keys.
- Risk: partial migration leaves hidden direct-query bypasses.
  - Mitigation: explicit no-bypass requirement, code audit checks, and integration tests.
- Risk: registry drift between declared dependencies and actual oracle availability.
  - Mitigation: startup validation and contract tests for every declared oracle key.

## 14. Open Questions & Assumptions

Assumptions:
- Instructor dashboard capability domains defined in the current lane PRDs are sufficient for initial oracle coverage.
- `Oli.Dashboard.*` modules are net-new and can be introduced without conflicting existing namespaces.
- Runtime features (`data_coordinator`, `data_cache`, `data_snapshot`) will consume these contracts without redefining them.
- Exact concrete instructor oracle keys/modules and final payload shapes are intentionally deferred to tile implementation stories.

Open questions:
- Consumer keys will be capability-centric (for example `:student_support_summary`) so multiple tiles can consume the same capability contract.
- Decision: v1 remains strictly per-oracle `load/2` (no batch-load callback in this phase).

## 15. Timeline & Milestones (Draft)

1. Shared contracts: scope, context, oracle behavior, registry behavior.
2. Instructor registry and initial dependency profiles.
3. Instructor oracle module scaffolding and contract tests.
4. Consumer migration away from direct query paths.
5. Observability instrumentation and rollout validation.

## 16. QA Plan

- Unit tests:
  - scope normalization and validation
  - oracle context validation
  - registry dependency, module resolution, and prerequisite execution-plan validation
  - deterministic error semantics
- Unit test methodology:
  - use mocked/stubbed concrete oracle modules where needed to drive end-to-end component interaction tests across registry/planner/contract boundaries.
- Contract tests:
  - each instructor oracle implements behavior callbacks and typed result envelope
- Integration tests:
  - representative instructor consumers resolve dependencies and execute through registry/oracle paths
  - direct-query bypass checks for covered flows

## 17. Definition of Done

- FR-001 through FR-013 implemented or explicitly deferred with rationale.
- AC-001 through AC-009 passing.
- Shared and instructor-specific boundaries are documented and reflected in module layout.
- Covered instructor dashboard consumers use oracle contract paths with no direct analytics query bypass.
- PRD/FDD references remain aligned with lane PRDs/FDDs, epic EDD, and lane plan.

Prototype references:
- `lib/oli/instructor_dashboard/prototype/tile.ex`
- `lib/oli/instructor_dashboard/prototype/tile_registry.ex`
- `lib/oli/instructor_dashboard/prototype/oracle.ex`

## 18. Decision Log

### 2026-02-17 - Align Oracle PRD With Prototype Dependency Declarations
- Change: Added explicit prototype alignment for slot-based dependency declarations and no direct oracle-to-oracle calling.
- Reason: Prototype implementation validated this pattern as the most consistent dependency contract for tile-driven composition.
- Evidence: `lib/oli/instructor_dashboard/prototype/tile.ex`, `lib/oli/instructor_dashboard/prototype/tile_registry.ex`, `lib/oli/instructor_dashboard/prototype/oracle.ex`
- Impact: Tightens interpretation of FR-005/FR-012 without changing feature scope.
