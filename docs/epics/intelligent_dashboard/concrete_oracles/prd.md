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
  - Assessments tile requests per-graded-page aggregate score statistics and score-distribution histograms for the selected scope.
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
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

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
    - `StudentInfoOracle`: `[%{student_id, email, given_name, family_name, last_interaction_at}]`.
    - `ScopeResourcesOracle`: `%{course_title, items: [%{resource_id, resource_type_id, title}]}`.
    - `GradesOracle`: `[%{page_id, available_at, due_at, score_stats: %{minimum_pct, median_pct, mean_pct, maximum_pct, standard_deviation_pct}, histogram_bins: %{0 => count, 10 => count, 20 => count, 30 => count, 40 => count, 50 => count, 60 => count, 70 => count, 80 => count, 90 => count}, total_scored_students}]`.
    - `ObjectivesProficiencyOracle`: `[%{objective_id, title, proficiency_distribution}]`.
  - Additional `GradesOracle` read-through API:
    - `students_without_attempt_emails(section_id, resource_id) -> {:ok, [email]} | {:error, reason}`.
    - This helper is separate from the aggregate grades payload and is invoked only for explicit instructor email actions.
  - StudentInfoOracle `last_interaction_at` derivation:
    - `last_interaction_at` is populated from `Oli.Delivery.Sections.Enrollment.updated_at` for the student + section enrollment row.
    - This is valid because the existing course-navigation tracking updates enrollment state (including `most_recently_visited_resource`) on page visits, which updates the enrollment `updated_at` timestamp.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Request all concrete oracles for their section | Must be section instructor or admin with access |
| Student | None | Oracles are instructor-only |
| Admin | Request all concrete oracles | Must be scoped to section and institution |

## 10. Integrations & Platform Considerations
- LTI 1.3: Use LTI role mappings to filter enrolled learners; no new LTI flows.
- GenAI (if applicable): N/A.
- External services: Recommend `GradesOracle` as the first ClickHouse-backed concrete oracle because page-level statistical aggregations and histogram binning are a strong fit for ClickHouse performance characteristics; keep a Postgres fallback path during rollout.
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
- Grades aggregation compute cost on large sections -> prefer ClickHouse execution path for `GradesOracle`; validate parity against Postgres fallback in tests.
- Grades metadata enrichment drift risk -> source `available_at` and `due_at` from `SectionResourceDepot` in-memory data to avoid extra DB reads and keep schedule values aligned with section resources.
- No-attempt email lookup correctness risk (false positives/negatives) -> enforce learner-role + enrollment filters and verify no-attempt semantics against `resource_accesses` attempt presence in tests.

## 14. Open Questions & Assumptions
- Assumptions:
  - Progress histogram bins are fixed at 10% increments with explicit `0, 10, 20, ... 100` buckets.
  - Missing-student progress is injected as `0%` via a lightweight post-processing step when SQL cross-joins are undesirable.
  - `GradesOracle` should preferentially execute via ClickHouse for page-level aggregates and histogram bins; Postgres fallback remains acceptable while ClickHouse rollout is staged.
  - `contained_objectives` is maintained and current for section scope filtering.
  - `StudentInfoOracle.last_interaction_at` uses `Enrollment.updated_at`, which reflects the latest course page interaction because `most_recently_visited_resource` updates that enrollment row on page visits.
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
  - `GradesOracle` tests for `available_at`/`due_at` enrichment from `SectionResourceDepot` without additional DB lookups.
  - `GradesOracle.students_without_attempt_emails/2` tests for role filtering, enrollment filtering, and no-attempt correctness.
- Manual:
  - Verify progress bins and proficiency pie outputs for representative scopes (course/unit/module).
  - Validate student drilldown lists match enrollment and role filters.
  - Verify assessments tile receives per-page aggregate statistics and fixed 10-bin score histograms.
- Performance Verification:
  - Benchmark oracle p95 latency for Normal and Large profiles using pre-seeded sections.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)

## 18. Decision Log
### 2026-02-19 - Grades Oracle Switched to Aggregate Payload
- Reason: Assessment tile requirements need distribution/statistical summaries per graded page rather than raw learner rows to drive histogram and summary rendering.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Acceptance criteria now validate aggregate outputs and histogram bins for `GradesOracle`; implementation should prioritize ClickHouse for this oracle with Postgres fallback during rollout.
### 2026-02-19 - Grades Oracle Added No-attempt Email Read-through
- Reason: UI requires an on-demand action to email students who have not attempted a selected graded page; this should not bloat the main aggregate payload.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Implementation must include a direct query helper with learner-role filtering and no-attempt semantics verification.
### 2026-02-19 - Grades Payload Includes Availability and Due Dates
- Reason: Assessments tile renders schedule metadata alongside aggregate statistics and should receive all required fields from one oracle payload.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: `GradesOracle` implementation must perform in-memory metadata enrichment for each graded page record without introducing extra DB reads.
