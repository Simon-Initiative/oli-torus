# Data Snapshot PRD

Last updated: 2026-02-17
Feature: `data_snapshot`
Epic: `MER-5198`
Primary Jira: `MER-5304` Data Infra: Snapshot Assembler and CSV Reuse Contract
Related docs: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/prd.md`, `docs/epics/intelligent_dashboard/data_oracles/prd.md`, `docs/epics/intelligent_dashboard/data_coordinator/prd.md`, `docs/epics/intelligent_dashboard/data_cache/prd.md`

## 1. Overview

This feature defines the canonical snapshot and projection layer for Intelligent Dashboard and makes it the single data contract consumed by tiles, AI context assembly, and CSV export.

`data_snapshot` is a composition and transform layer. It assembles deterministic scoped snapshots from oracle outputs and derives consumer-oriented projections. It does not run direct analytics queries or implement queue/token/cache policy logic. Exact concrete instructor oracle implementations remain tile-driven; this layer consumes whatever oracle contracts/bindings are active for the scope request.

Prototype alignment:
- Snapshot contract in prototype already includes `scope`, oracle payload/status maps, projection map, and projection-status map.
- Projection-only assembly (`project/4`) from externally supplied oracle results should remain a first-class path.
- Tile-specific joins/categorization and axis rules belong in projection modules, not UI modules.

## 2. Background & Problem Statement

If dashboard UI and CSV export derive data from separate logic paths, metric drift and trust erosion follow. If projection logic is distributed across tiles and export handlers, change cost and correctness risk increase.

The lane needs a single, explicit snapshot contract that:
- composes normalized oracle outputs,
- provides stable projection interfaces,
- supports incremental readiness for UI,
- and reuses the same projection inputs for CSV export.

## 3. Goals & Non-Goals

Goals:
- Define deterministic snapshot contract with metadata, oracle payload envelope, and projection blocks.
- Define explicit projection interfaces for current instructor capabilities.
- Ensure CSV ZIP export is transform-only over snapshot/projections (no independent analytics query path).
- Define deterministic partial/failure semantics for UI consumption and export generation.
- Define clear module boundaries between orchestration (`DataSnapshot`), assembly (`Snapshot.Assembler`), and export adapters (`CsvExport`).

Non-Goals:
- Defining oracle contracts/dependency resolution (`data_oracles`).
- Defining request queueing/token stale suppression (`data_coordinator`).
- Defining cache keying/TTL/eviction/coalescing (`data_cache`).
- Implementing tile UI behavior.

## 4. Users & Use Cases

Users:
- Instructors consuming dashboard insights.
- Instructors exporting dashboard CSV ZIP bundles.
- Engineers extending dashboard capabilities and datasets.

Use cases:
- Scope change produces updated snapshot and projection blocks for incremental tile rendering.
- Export action for current scope reuses the same snapshot/projection semantics shown in UI.
- New capability adds projection and optional dataset mapping without touching tile query code.

## 5. UX / UI Requirements

- UI projection values and CSV values must match for the same scope and time window semantics.
- Incremental hydration should expose deterministic per-capability readiness/error states.
- Export behavior must be deterministic when some projections are unavailable (defined partial/fail policy).
- Users should receive explicit export failure reasons when required projection data is unavailable.

## 6. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | System SHALL assemble a canonical scoped snapshot from oracle result envelopes for a request token and scope context. | P0 |
| FR-002 | System SHALL include snapshot metadata, oracle payload map, oracle status map, and derived projection blocks. | P0 |
| FR-003 | System SHALL provide projection contracts for instructor capability consumers (`summary`, `progress`, `student_support`, `challenging_objectives`, `assessments`, `ai_context`). | P0 |
| FR-004 | System SHALL expose deterministic projection readiness states (`ready`, `partial`, `failed`, `unavailable`) per capability. | P0 |
| FR-005 | System SHALL provide `Oli.InstructorDashboard.DataSnapshot` public API for scoped snapshot/projection retrieval. | P0 |
| FR-006 | System SHALL generate CSV ZIP outputs from snapshot/projections via transform-only adapters. | P0 |
| FR-007 | System SHALL NOT execute direct analytics/oracle queries from CSV export adapters when snapshot/projections are available. | P0 |
| FR-008 | System SHALL define deterministic export dataset inclusion policy when projections are partial or failed. | P0 |
| FR-009 | System SHALL define stable dataset registry mapping CSV datasets to projection requirements and serializers. | P1 |
| FR-010 | System SHALL include contract versioning fields for snapshot schema and projection schema evolution. | P1 |
| FR-011 | System SHALL define explicit one-way boundaries: DataSnapshot may use coordinator/cache APIs; assembler/projection/export modules SHALL remain queryless and policy-agnostic. | P0 |
| FR-012 | System SHALL emit parity-check metadata/fingerprints to support UI/CSV semantic equivalence verification. | P1 |
| FR-013 | System SHALL include extensive automated unit testing for snapshot assembler/projection/export orchestration behavior, and SHALL use mocked or stubbed concrete dependencies (for example oracle-result producers and serializer adapters) where needed to validate end-to-end component interactions in tests. | P0 |

## 7. Acceptance Criteria

- AC-001: Given oracle outputs for scope `S`, snapshot assembly produces deterministic metadata, oracle blocks, and projection blocks.
- AC-002: Given same scope `S`, UI projections and CSV datasets derived from those projections are semantically equivalent for core metrics.
- AC-003: Given export request with valid snapshot/projection state, no independent analytics query path is executed.
- AC-004: Given partial projection readiness, dataset inclusion/exclusion in export follows documented deterministic policy.
- AC-005: Given failed required projection for export, export returns deterministic failure with explicit reason codes.
- AC-006: Given boundary review, assembler/projection/export modules contain no queue/token/cache-policy logic and no direct oracle/query calls.
- AC-007: Given projection schema version update, existing consumers can continue on prior version contract until migrated.
- AC-008: Given snapshot unit test execution, mocked/stubbed concrete dependencies are used where necessary to exercise assembler/projection/export orchestration interactions end-to-end at component boundaries.

## 8. Non-Functional Requirements

Performance:
- NFR-PERF-001: Snapshot assembly p95 <= 700ms for typical scope.
- NFR-PERF-002: Projection derivation p95 <= 300ms for typical scope.
- NFR-PERF-003: CSV ZIP generation p95 <= 5s for typical dataset volume.

Reliability:
- NFR-REL-001: Projection readiness states are deterministic and test-covered.
- NFR-REL-002: Export failure handling is deterministic and non-crashing.

Correctness:
- NFR-COR-001: UI/CSV parity checks for core metrics have zero tolerated mismatches in automated parity suite.

Operability:
- NFR-OPS-001: Snapshot/projection/export latency and failure metrics are emitted with scope metadata.

## 9. Data Model & APIs

No relational schema migration required.

Snapshot contract (notional):
- `snapshot_version`
- `projection_version`
- `request_token`
- `scope` (context type/id + container identity)
- `metadata` (timezone, thresholds, generated_at, config signature)
- `oracles` (payload map by oracle key)
- `oracle_statuses` (ready/failed/stale metadata)
- `projections` (capability map)
- `projection_statuses` (ready/partial/failed/unavailable)

Notional modules and public APIs:

- `Oli.Dashboard.Snapshot.Assembler`
  - `assemble/4 :: context, token, oracle_results, opts -> {:ok, snapshot} | {:error, reason}`

- `Oli.Dashboard.Snapshot.Projections`
  - `derive_all/2 :: snapshot, opts -> {:ok, projection_map, projection_statuses} | {:error, reason}`
  - `derive/3 :: capability_key, snapshot, opts -> {:ok, projection, status} | {:error, reason}`

- `Oli.InstructorDashboard.DataSnapshot`
  - `get_or_build/2 :: scope_request, opts -> {:ok, snapshot_bundle} | {:error, reason}`
  - `get_projection/3 :: snapshot_bundle, capability_key, opts -> {:ok, projection} | {:error, reason}`

- `Oli.InstructorDashboard.DataSnapshot.CsvExport`
  - `build_zip/2 :: snapshot_bundle, export_request -> {:ok, zip_binary, manifest} | {:error, reason}`

- `Oli.InstructorDashboard.DataSnapshot.DatasetRegistry`
  - `datasets_for/1 :: export_profile -> [dataset_spec]`

## 10. Integrations & Platform Considerations

- Consumes oracle outputs from coordinator/runtime path.
- Reuses cache-enabled retrieval via `DataSnapshot` orchestration entry points.
- Provides projection contracts for dashboard tiles and AI downstream features.
- Provides CSV export transform adapters for `MER-5266`.

## 11. Feature Flagging, Rollout & Migration

- No user-facing feature flag required for baseline.
- Rollout strategy:
  1. Introduce snapshot/projection contracts and verify parity against existing views.
  2. Switch dashboard tile consumers to projection contracts.
  3. Switch CSV export path to `CsvExport.build_zip/2` transform-only contract.
  4. Remove legacy per-surface transform divergence.

## 12. Analytics & Success Metrics

- Snapshot assembly latency (`p50/p95/p99`).
- Projection derivation latency by capability.
- Export generation latency and failure rates.
- UI/CSV parity mismatch count (target `0` for gated metrics).
- Projection readiness distribution (`ready`, `partial`, `failed`).

## 13. Risks & Mitigations

- Risk: projection contract churn from rapidly evolving tile requirements.
  - Mitigation: capability-scoped projection modules + contract versioning.
- Risk: export drift from UI semantics.
  - Mitigation: shared projection source + parity tests + fingerprint instrumentation.
- Risk: snapshot layer absorbing runtime/cache policy concerns.
  - Mitigation: explicit boundary FR + code review checklist + module separation.

## 14. Open Questions & Assumptions

Assumptions:
- Current oracle domains in `data_oracles` are sufficient to derive baseline instructor projections.
- Coordinator/cache APIs are stable enough for `DataSnapshot` orchestration integration.
- Exact concrete instructor oracle keys/modules and final payload shapes are finalized in tile implementation stories.

Open questions:
- Should export return partial ZIP with manifest on some projection failures, or fail-closed for all failures in v1?
- Should projection version negotiation be runtime-configurable or deploy-time-only in baseline?

## 15. Timeline & Milestones (Draft)

1. Define snapshot/projection contract structs and assembler.
2. Implement instructor projection modules and readiness semantics.
3. Implement dataset registry and CSV transform adapters.
4. Land parity suite and observability instrumentation.

## 16. QA Plan

- Unit tests:
  - assembler deterministic shape and metadata.
  - projection derivation and readiness statuses.
  - dataset registry mapping and CSV serializer correctness.
  - mocked/stubbed concrete dependencies (oracle-result producers, coordinator/cache facades, serializer adapters) where needed to exercise end-to-end snapshot component interactions.
- Integration tests:
  - end-to-end `DataSnapshot.get_or_build/2` flow with mixed cache/runtime results.
  - UI/CSV parity for representative scopes.
  - deterministic partial/failure export policy behavior.
- Regression tests:
  - no direct query path in export adapter.

## 17. Definition of Done

- FR-001 through FR-013 implemented or explicitly deferred with rationale.
- AC-001 through AC-008 passing.
- Snapshot/projection/export module boundaries are explicit and enforced.
- CSV generation uses transform-only path from snapshot/projection contracts.
- Parity checks and observability metrics are in place for rollout confidence.

Prototype references:
- `lib/oli/instructor_dashboard/prototype/snapshot.ex`
- `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`
- `lib/oli/instructor_dashboard/prototype/tiles/student_support/data.ex`
- `lib/oli/instructor_dashboard/prototype/scope.ex`

## 18. Decision Log

### 2026-02-17 - Capture Prototype Snapshot and Projection Boundaries
- Change: Added explicit prototype alignment for snapshot shape, externally supplied projection assembly, and projection-module ownership of rules/joins.
- Reason: Prototype demonstrated this split is necessary for reusable, incremental data consumption across UI/export.
- Evidence: `lib/oli/instructor_dashboard/prototype/snapshot.ex`, `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`, `lib/oli/instructor_dashboard/prototype/tiles/student_support/data.ex`
- Impact: Strengthens FR-001/FR-002/FR-004/FR-011 interpretation and AC-001/AC-006 review criteria.
