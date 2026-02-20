# Concrete Oracles — PRD

## 1. Overview
Feature Name: Concrete Oracles (Instructor Dashboard)

Summary: Define the concrete, tile-facing oracle contracts and query strategies that power Instructor Intelligent Dashboard tiles with bounded memory and predictable performance. This PRD specifies the per-tile oracle split, scope-aware inputs/outputs, and correctness/performance expectations for progress, proficiency, grades, student info, scope resources, and learning objectives proficiency.

Links: `docs/epics/intelligent_dashboard/overview.md`, `docs/epics/intelligent_dashboard/plan.md`, `docs/epics/intelligent_dashboard/prd.md`, `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/README.md` (authoritative technical direction; FDD should be derived from this)

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Tile implementations need concrete oracle contracts and query plans to avoid ad-hoc analytics queries in UI code.
  - Raw per-student/per-page data can be large in memory for big sections and repeated scope changes.
  - Objective proficiency needs scope filtering without runtime graph traversal across activities/pages.
- Affected users/roles:
  - Instructors (end users), dashboard engineering team (consumers of oracle contracts).
- Why now:
  - The dashboard data lane requires concrete oracle implementations to support upcoming tiles and data snapshots.

## 3. Goals & Non-Goals
- Goals:
  - Provide concrete oracle contracts that are scope-aware, performant, and stable for tile consumption.
  - Keep memory usage bounded by using aggregate bins where possible and raw rows only where needed.
  - Reuse existing data pathways (contained_pages, resource_accesses, resource_summary, contained_objectives, SectionResourceDepot) to avoid new schema work.
  - Preserve consistent semantics for progress (average page progress) and proficiency (resource_summary formula + minimum attempts threshold).
- Non-Goals:
  - Redesigning the dashboard runtime, cache, or data coordinator layers.
  - Introducing new UI or tile behavior changes.
  - Replacing the existing metrics/proficiency formulas or resource summary pipelines.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor (LTI context role `context_learner` filtering for students; instructor role for access).
- Use Cases:
  - Progress tile fetches per-container progress histograms for a unit scope.
  - Proficiency tile fetches per-student progress/proficiency tuples for a scope and bins them client-side for a pie chart.
  - Instructor clicks a proficiency slice to view enrolled student lists with identity details.
  - Assessments tile requests graded page scores for the selected scope.
  - Challenging Objectives tile loads objective proficiency distributions limited to the selected scope.

## 5. UX / UI Requirements
- Key Screens/States:
  - N/A (backend data contracts only).
- Navigation & Entry Points:
  - Invoked by dashboard tile hydration via oracle runtime.
- Accessibility:
  - N/A (no direct UI changes).
- Internationalization:
  - N/A.
- Screenshots/Mocks:
  - None.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Define `ProgressBinsOracle` that returns per-container histogram counts in fixed 10% bins (0..100) for the selected scope and direct child containers. | P0 | Data |
| FR-002 | Define `ProgressProficiencyOracle` that returns per-student tuples `{student_id, progress_pct, proficiency_pct}` for the selected scope (no per-container breakdown). | P0 | Data |
| FR-003 | Define `StudentInfoOracle` that returns enrolled student identifiers and display fields for drilldown lists. | P0 | Data |
| FR-004 | Define `ScopeResourcesOracle` that returns the course title and direct children of the current scope (resource id, type, title) using in-memory depot data. | P1 | Data |
| FR-005 | Define `GradesOracle` that returns graded page ids within scope and per-student grade tuples, filling missing attempts. | P1 | Data |
| FR-006 | Define `ObjectivesProficiencyOracle` that returns objective proficiency distributions for objectives contained within the selected scope. | P0 | Data |
| FR-007 | All oracles must filter to enrolled learners only, excluding instructors and non-enrolled users. | P0 | Data |
| FR-008 | Oracles must accept scope inputs `(section_id, container_type, container_id)` and be deterministic for identical inputs. | P0 | Data |
| FR-009 | Oracles must normalize outputs into stable payload shapes consumable by snapshots and projections. | P0 | Data |
| FR-010 | Oracles must respect existing progress/proficiency formulas and thresholds (progress as average page progress, proficiency as resource_summary formula with minimum-attempt gating). | P0 | Data |

## 7. Acceptance Criteria
- AC-001 (FR-001) — Given a unit scope and its module ids, when `ProgressBinsOracle` executes, then it returns 0..100 bin counts per module with all enrolled students represented (including 0% progress).
- AC-002 (FR-002) — Given a container scope, when `ProgressProficiencyOracle` executes, then it returns one row per enrolled student with `progress_pct` defaulting to 0.0 if missing and `proficiency_pct` set to nil when attempt thresholds are not met.
- AC-003 (FR-003) — Given a section, when `StudentInfoOracle` executes, then it returns unique enrolled student ids with email and names and excludes instructor accounts.
- AC-004 (FR-004) — Given a scope, when `ScopeResourcesOracle` executes, then it returns the course title and direct child items with id, type, and title sourced from the section resource depot.
- AC-005 (FR-005) — Given a scope, when `GradesOracle` executes, then it returns graded page ids within scope and grade tuples for enrolled students, including entries for missing attempts.
- AC-006 (FR-006) — Given a scope, when `ObjectivesProficiencyOracle` executes, then it returns objective proficiency distributions for objectives contained within that scope using `contained_objectives` mappings.
- AC-007 (FR-007, FR-008) — Given identical scope inputs and enrollments, when any oracle executes repeatedly, then the payload shapes and values are deterministic and scoped only to enrolled learners.

## 8. Non-Functional Requirements
- Performance & Scale: Oracles should meet p95 <= 300ms (Normal 200 learners) and p95 <= 700ms (Large 2,000 learners) for single-scope execution when uncached; queries must avoid unbounded fan-out.
- Reliability: Oracle execution failures must surface as explicit errors in the oracle result envelope without corrupting cache or snapshot state.
- Security & Privacy: All results must be scoped to the section; only enrolled learners are included; user PII fields are restricted to id, email, and names.
- Compliance: No new accessibility or retention requirements; data handling must align with existing privacy policies.
- Observability: Emit telemetry per oracle execution (duration, row counts, cache hit/miss) for AppSignal dashboards.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None planned. Reuse `resource_accesses`, `resource_summary`, `contained_pages`, `contained_objectives`, `section_resources`, `enrollments`.
- Context Boundaries:
  - `Oli.InstructorDashboard.Oracles.*`, `Oli.Delivery.Metrics`, `Oli.Delivery.Sections`, `Oli.Delivery.Sections.SectionResourceDepot`.
- APIs / Contracts:
  - Oracle inputs: `section_id`, `container_type`, `container_id`, optional `axis_container_ids` for progress bins.
  - Oracle outputs:
    - `ProgressBinsOracle`: `%{bin_size: 10, by_container_bins: %{container_id => %{0 => count, 10 => count, ...}}, total_students: integer}`.
    - `ProgressProficiencyOracle`: `[%{student_id, progress_pct, proficiency_pct}]`.
    - `StudentInfoOracle`: `[%{student_id, email, given_name, family_name}]`.
    - `ScopeResourcesOracle`: `%{course_title, items: [%{resource_id, resource_type_id, title}]}`.
    - `GradesOracle`: `%{page_ids, grades: [%{student_id, page_id, score, out_of}]}`.
    - `ObjectivesProficiencyOracle`: `[%{objective_id, title, proficiency_distribution}]`.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Request all concrete oracles for their section | Must be section instructor or admin with access |
| Student | None | Oracles are instructor-only |
| Admin | Request all concrete oracles | Must be scoped to section and institution |

## 10. Integrations & Platform Considerations
- LTI 1.3: Use LTI role mappings to filter enrolled learners; no new LTI flows.
- GenAI (if applicable): N/A.
- External services: ClickHouse use is optional for future optimization; baseline uses Postgres + in-memory depot.
- Caching/Perf: Oracles participate in dashboard cache layers; avoid per-tile query logic.
- Multi-tenancy: Scope all queries by `section_id` and institution boundaries via standard auth.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Oracle p95 latency per scale profile.
  - Cache hit rate for repeated scope changes.
  - Correctness parity with existing progress/proficiency definitions.
- Events:
  - `oracle.execute` (oracle_name, duration_ms, row_count, cache_hit).

## 13. Risks & Mitigations
- Large-scope performance risk (cross-join for 0% progress bins) -> use two-step strategy or limit SQL cross-join; rely on enrolled student list and post-processing.
- Incomplete objective containment mapping -> depend on `contained_objectives` rebuild on remix; add guardrails for missing mappings.
- Sparse data for proficiency -> preserve minimum-attempt gating and return `nil` proficiency to avoid misleading classifications.

## 14. Open Questions & Assumptions
- Assumptions:
  - Progress histogram bins are fixed at 10% increments with explicit `0, 10, 20, ... 100` buckets.
  - Missing-student progress is injected as `0%` via a lightweight post-processing step when SQL cross-joins are undesirable.
  - No ClickHouse dependency is required for these concrete oracles.
  - `contained_objectives` is maintained and current for section scope filtering.
  - The FDD for this feature should primarily transpose the guidance in `docs/epics/intelligent_dashboard/concrete_oracles/README.md` into the FDD template slots.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- PRD complete and validated.
- FDD updates (if needed) for concrete oracle implementation details.
- Implementation story execution (MER-5310).

## 16. QA Plan
- Automated:
  - Unit tests for each oracle module with fixture data.
  - Metrics/proficiency formula regression tests.
- Manual:
  - Verify progress bins and proficiency pie outputs for representative scopes (course/unit/module).
  - Validate student drilldown lists match enrollment and role filters.
- Performance Verification:
  - Benchmark oracle p95 latency for Normal and Large profiles using pre-seeded sections.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
