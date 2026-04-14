# Concrete Oracles — Implementation Plan

Last updated: 2026-02-24

Context references:
- `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`
- `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`
- `docs/epics/intelligent_dashboard/concrete_oracles/README.md`
- `docs/epics/intelligent_dashboard/plan.md`

## Clarifications & Assumptions
- Scope covers concrete oracle implementation for the instructor dashboard feature slice (`MER-5310`).
- `ProgressBinsOracle`, `ProgressProficiencyOracle`, `StudentInfoOracle`, `ScopeResourcesOracle`, `GradesOracle`, and `ObjectivesProficiencyOracle` ship with stable payload contracts defined in PRD/FDD.
- `GradesOracle` returns per-page aggregate statistics, histogram bins, and page schedule metadata (`available_at`, `due_at`); no per-student grade rows are emitted.
- Initial implementation is Postgres/Ecto-only for all concrete oracles; no ClickHouse execution path is implemented in this feature run.
- Any ClickHouse-backed oracle optimization is explicitly deferred to a post-epic follow-up after baseline Postgres behavior is fully working and validated.
- `GradesOracle` also exposes `students_without_attempt_emails(section_id, resource_id)` as a direct read-through helper for instructor outreach actions.

## Developer Input Contract (FDD + README)
- Required inputs for implementation execution:
  - `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`
  - `docs/epics/intelligent_dashboard/concrete_oracles/README.md`
- Execution rule:
  - For the oracle currently in progress, the developer must use the corresponding README oracle section and FDD together as the implementation contract.
  - If a README detail is missing from FDD/plan or appears to conflict, update docs first, then implement.
- Oracle-to-README section mapping (must be followed):
  - `ProgressBinsOracle` -> `README.md` / `Oracle 1: ProgressBinsOracle`
  - `ProgressProficiencyOracle` -> `README.md` / `Oracle 2: ProgressProficiencyOracle`
  - `StudentInfoOracle` -> `README.md` / `Oracle 3: StudentInfoOracle`
  - `ScopeResourcesOracle` -> `README.md` / `Oracle 4: ScopeResourcesOracle`
  - `GradesOracle` -> `README.md` / `Oracle 5: GradesOracle`
  - `ObjectivesProficiencyOracle` -> `README.md` / `Oracle 6: ObjectivesProficiencyOracle`

## Oracle Sequencing Rule (One Oracle at a Time)
- Implementation order is strictly sequential:
  1. `ProgressBinsOracle`
  2. `ProgressProficiencyOracle`
  3. `StudentInfoOracle`
  4. `ScopeResourcesOracle`
  5. `GradesOracle`
  6. `ObjectivesProficiencyOracle`
- Completion gate per oracle before starting the next:
  - Oracle module implementation complete.
  - Oracle-focused tests added/updated and passing.
  - Payload contract checks for that oracle pass.
  - Any discovered spec drift is reconciled in PRD/FDD/plan.

## Requirements Traceability
- Source of truth: `docs/epics/intelligent_dashboard/concrete_oracles/requirements.yml`
- Plan verification command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/intelligent_dashboard/concrete_oracles --action verify_plan`
- Stage gate command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/intelligent_dashboard/concrete_oracles --action master_validate --stage plan_present`

## Phase Gate Summary
- Gate A (Contract Ready): payload contracts and acceptance criteria are finalized and validated in PRD/FDD.
- Gate B (Core Implementation): all concrete oracle modules are implemented with deterministic scoped outputs and unit tests.
- Gate C (Performance and Rollout): Postgres performance targets and rollout readiness are verified; deferred ClickHouse follow-up is documented.

## Phase 1: Contracts and Query Plan Finalization
### Goals
- Lock oracle payload contracts and per-oracle query strategy for scope, filtering, and deterministic output semantics.
- Confirm aggregate grades payload format and bucket definition for assessments tile consumption.

### Work Items
- Confirm/align oracle contracts in `prd.md` and `fdd.md`.
- Finalize SQL and/or depot query shape for each oracle.
- Define exact grade histogram bucket boundaries: `0-10, 10-20, ... 90-100`.

### Definition of Done
- PRD/FDD validation passes for this feature pack.
- Oracle payload contracts are unambiguous and include all required fields.
- Acceptance criteria map to implementation-ready behaviors.

## Phase 2: Concrete Oracle Implementation
### Goals
- Implement all concrete oracle modules under `Oli.InstructorDashboard.Oracles.*`.
- Ensure payload shapes match contract definitions exactly.

### Work Items
- Implement oracles strictly one at a time using the sequence in `Oracle Sequencing Rule`.
- For each oracle, implement `load/2` with section-scoped filtering for enrolled learners.
- For each oracle, read and apply the mapped `README.md` oracle section before coding.
- Implement `GradesOracle` aggregate output per graded page with statistics, histogram bins, and `available_at`/`due_at` enrichment from `SectionResourceDepot`.
- Implement `GradesOracle.students_without_attempt_emails/2` with learner-role filtering and no-attempt semantics.
- Add unit tests for correctness, edge cases, and deterministic output.

### Definition of Done
- All oracle unit tests pass.
- Instructor-only authorization and section scoping are enforced.
- Runtime receives normalized payloads with no contract drift.
- Each oracle cleared its per-oracle completion gate before moving to the next oracle.

## Phase 3: Performance, Parity, and Rollout
### Goals
- Validate latency budgets and ensure safe rollout for grades aggregation path.
- Confirm Postgres-based grades implementation is functionally correct and rollout-ready.

### Work Items
- Run targeted benchmarks for Normal and Large section profiles.
- Add correctness tests for depot metadata enrichment (`available_at`, `due_at`) in aggregate rows.
- Add correctness tests for `students_without_attempt_emails/2` (attempted vs unattempted learners).
- Verify observability metrics/logging for query latency and payload row counts.
- Record explicit deferred ClickHouse optimization note for post-epic execution (not in current implementation scope).

### Definition of Done
- p95 latency targets are met or documented with mitigation actions.
- Rollout notes capture Postgres-only activation strategy and deferred ClickHouse follow-up.

## Decision Log
### 2026-02-24 - Phase 3 Observability + Benchmark Rollout Notes
- Change:
  - Added `GradesOracle` runtime observability for `load/2` and `students_without_attempt_emails/2` using telemetry event `[:oli, :dashboard, :oracle, :execute]` with `duration_ms`, `row_count`, and `payload_size` measurements.
  - Added latency-aware logging for Grades oracle paths (`debug` start, `info` completion, `warning` on slow-path threshold, `error` on failures).
  - Added Phase 3 correctness tests for no-attempt helper edge behavior and telemetry emission shape.
  - Executed synthetic benchmark script in test environment for `Normal` (200 learners) and `Large` (2,000 learners) profiles using Postgres/Ecto execution only.
- Benchmark evidence:
  - Command: `MIX_ENV=test ASDF_ERLANG_VERSION=28.1.1 mix run /tmp/grades_oracle_phase3_bench.exs`
  - Output sample:
    - `profile=normal learners=200 rows=0 runs=30 avg_ms=0.6 p95_ms=0.24 p99_ms=14.67`
    - `profile=large learners=2000 rows=0 runs=30 avg_ms=10.86 p95_ms=0.5 p99_ms=320.05`
- Reason:
  - Phase 3 requires explicit parity verification plus runtime instrumentation for latency/row-count visibility and rollout safety.
- Impact:
  - Grades oracle now emits actionable telemetry and structured logs for ongoing AppSignal/telemetry monitoring.
  - Current benchmark run is synthetic and environment-constrained; p95 is documented, with observed p99 outlier in the Large profile.
  - ClickHouse optimization remains deferred until post-epic hardening, per Postgres-first policy.

### 2026-02-24 - Enforce Postgres-Only Initial Oracle Implementation
- Change: Updated plan assumptions and phase gates to require Postgres/Ecto-only implementation for all initial concrete oracle delivery work.
- Reason: The team wants correctness and stability first across the full oracle set before introducing ClickHouse-specific optimizations.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Current implementation excludes ClickHouse paths; optimization work is deferred until end-of-epic hardening.

### 2026-02-24 - Enforce README-Guided One-Oracle-at-a-Time Execution
- Change: Added explicit developer input contract requiring use of FDD plus mapped README oracle sections, and added strict one-oracle-at-a-time sequencing gates.
- Reason: The feature has critical oracle-specific implementation details in README that must drive execution and review phase-by-phase.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Development runs are now constrained to sequential oracle slices with explicit per-oracle completion criteria and doc-sync requirements.

### 2026-02-19 - Plan Includes Grades No-attempt Email Helper
- Change: Added explicit implementation and verification work for `GradesOracle.students_without_attempt_emails(section_id, resource_id)`.
- Reason: The UI needs an on-demand outreach flow for students who have not attempted a selected graded page.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Phase 2/3 now explicitly require helper implementation and correctness tests alongside aggregate grades delivery.
### 2026-02-19 - Plan Adds Grades Schedule Metadata Enrichment
- Change: Added implementation/test tasks for `available_at` and `due_at` enrichment in `GradesOracle` aggregate rows.
- Reason: Assessments tile needs schedule fields in the same payload as aggregate grade stats for fast render and fewer oracle calls.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Phase 2/3 require depot enrichment wiring and validation of schedule metadata mapping.
