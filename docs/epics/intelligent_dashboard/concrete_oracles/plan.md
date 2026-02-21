# Concrete Oracles — Implementation Plan

Last updated: 2026-02-19

Context references:
- `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`
- `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`
- `docs/epics/intelligent_dashboard/concrete_oracles/README.md`
- `docs/epics/intelligent_dashboard/plan.md`

## Clarifications & Assumptions
- Scope covers concrete oracle implementation for the instructor dashboard feature slice (`MER-5310`).
- `ProgressBinsOracle`, `ProgressProficiencyOracle`, `StudentInfoOracle`, `ScopeResourcesOracle`, `GradesOracle`, and `ObjectivesProficiencyOracle` ship with stable payload contracts defined in PRD/FDD.
- `GradesOracle` returns per-page aggregate statistics, histogram bins, and page schedule metadata (`available_at`, `due_at`); no per-student grade rows are emitted.
- `GradesOracle` uses ClickHouse as the preferred execution path, with Postgres fallback for staged rollout/parity validation.
- `GradesOracle` also exposes `students_without_attempt_emails(section_id, resource_id)` as a direct read-through helper for instructor outreach actions.

## Requirements Traceability
- Source of truth: `docs/epics/intelligent_dashboard/concrete_oracles/requirements.yml`
- Plan verification command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/intelligent_dashboard/concrete_oracles --action verify_plan`
- Stage gate command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/intelligent_dashboard/concrete_oracles --action master_validate --stage plan_present`

## Phase Gate Summary
- Gate A (Contract Ready): payload contracts and acceptance criteria are finalized and validated in PRD/FDD.
- Gate B (Core Implementation): all concrete oracle modules are implemented with deterministic scoped outputs and unit tests.
- Gate C (Performance and Rollout): performance targets are verified and ClickHouse/Postgres parity checks pass for grades aggregates.

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
- Implement each oracle `load/2` with section-scoped filtering for enrolled learners.
- Implement `GradesOracle` aggregate output per graded page with statistics, histogram bins, and `available_at`/`due_at` enrichment from `SectionResourceDepot`.
- Implement `GradesOracle.students_without_attempt_emails/2` with learner-role filtering and no-attempt semantics.
- Add unit tests for correctness, edge cases, and deterministic output.

### Definition of Done
- All oracle unit tests pass.
- Instructor-only authorization and section scoping are enforced.
- Runtime receives normalized payloads with no contract drift.

## Phase 3: Performance, Parity, and Rollout
### Goals
- Validate latency budgets and ensure safe rollout for grades aggregation path.
- Confirm ClickHouse-first grades implementation is functionally equivalent to Postgres fallback.

### Work Items
- Run targeted benchmarks for Normal and Large section profiles.
- Add ClickHouse/Postgres parity tests for `GradesOracle` aggregate stats and histogram bins.
- Add correctness tests for depot metadata enrichment (`available_at`, `due_at`) in aggregate rows.
- Add correctness tests for `students_without_attempt_emails/2` (attempted vs unattempted learners).
- Verify observability metrics/logging for query latency and payload row counts.

### Definition of Done
- p95 latency targets are met or documented with mitigation actions.
- `GradesOracle` parity checks pass across primary and fallback execution paths.
- Rollout notes capture activation strategy and fallback behavior.

## Decision Log
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
