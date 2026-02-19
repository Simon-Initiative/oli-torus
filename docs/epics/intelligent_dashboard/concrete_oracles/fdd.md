# Concrete Oracles — Functional Design Document

## 1. Executive Summary
This FDD defines the concrete oracle implementations that power Instructor Intelligent Dashboard tiles with bounded memory and deterministic query behavior. It derives its technical direction from `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, which should be treated as authoritative implementation guidance. The design introduces six concrete oracles under `Oli.InstructorDashboard.Oracles.*` for progress bins, progress+proficiency raw tuples, student info, scope resources, grades, and objectives proficiency. These oracles are read-only, scope-aware, and execute within the shared oracle runtime defined by the `data_oracles` feature, returning normalized payloads for snapshot and projection layers. Progress is computed as average page progress using `resource_accesses` and `contained_pages`; proficiency is computed from `resource_summary` with minimum-attempt gating. Scope filtering uses `contained_pages` for page containment and `contained_objectives` for objective containment, with `SectionResourceDepot` providing fast in-memory resource and hierarchy reads. The progress bins oracle uses fixed 10% buckets from 0..100 and fills missing students with 0% in a post-processing step to avoid heavy cross-joins. Grades now return per-page aggregate statistics, fixed 10-bin score distributions, and per-page `available_at`/`due_at` metadata from `SectionResourceDepot` instead of per-student raw rows; this is the recommended first concrete oracle to execute via ClickHouse. No new schema changes or feature flags are required for this slice. The primary risks are large-scope query costs and stale objective containment mappings; both are mitigated by existing containment tables and bounded payload shapes. Observability is provided via per-oracle telemetry of duration, row counts, and cache hit metadata.

## 2. Requirements & Assumptions
- Functional Requirements:
  - FR-001: ProgressBinsOracle returns per-container histogram counts in fixed 0..100 (10% increment) bins.
  - FR-002: ProgressProficiencyOracle returns per-student `{student_id, progress_pct, proficiency_pct}` tuples scoped to the selected container.
  - FR-003: StudentInfoOracle returns enrolled student identity fields and `last_interaction_at` for drilldowns.
  - FR-004: ScopeResourcesOracle returns course title and direct child items for the current scope from `SectionResourceDepot`.
  - FR-005: GradesOracle returns graded pages in scope and per-page aggregate score statistics with fixed 10% histogram buckets plus `available_at`/`due_at` metadata, without per-student raw rows.
  - FR-006: ObjectivesProficiencyOracle returns proficiency distributions for objectives contained within the selected scope.
  - FR-007: All oracles filter to enrolled learners only.
  - FR-008: Oracles accept `(section_id, container_type, container_id)` scope and are deterministic for identical inputs.
  - FR-009: Oracles return stable payload shapes for snapshot/projection consumption.
  - FR-010: Oracles reuse existing progress/proficiency formulas and thresholds.
  - FR-011: GradesOracle provides a direct read-through function `students_without_attempt_emails(section_id, resource_id)` for instructor email actions.
- Non-Functional Requirements:
  - p95 <= 300ms (Normal) and p95 <= 700ms (Large) for uncached single-scope execution.
  - Errors are surfaced in oracle envelopes without corrupting cache or snapshots.
  - PII exposure is limited to student id, email, given/family name.
  - Telemetry includes per-oracle duration and row counts.
- Explicit Assumptions:
  - Progress histogram bins are fixed at 10% increments with explicit `0, 10, 20, ... 100` buckets.
  - Missing-student progress is injected as `0%` via a lightweight post-processing step when SQL cross-joins are undesirable.
  - `GradesOracle` should preferentially execute via ClickHouse because percentile/statistical aggregation and histogram binning are well-suited to ClickHouse.
  - A Postgres fallback implementation is acceptable during staged ClickHouse rollout but must match payload semantics exactly.
  - `contained_objectives` is maintained and current for scope filtering.
  - `StudentInfoOracle.last_interaction_at` is sourced from `Oli.Delivery.Sections.Enrollment.updated_at` per student enrollment within the section.
  - This source is valid because existing page-visit tracking updates enrollment state (including `most_recently_visited_resource`), which updates `Enrollment.updated_at`.
  - This FDD primarily transposes the technical guidance from `concrete_oracles/README.md` into the FDD template.

## 3. Torus Context Summary
- What we know:
  - `resource_accesses` is the authoritative store for page progress and grades (attempt hierarchy rooted at ResourceAccess). See `guides/design/attempt.md`.
  - `contained_pages` provides container -> page containment and is used by `Metrics.progress_for/3` for average progress (sum progress / page_count). See `lib/oli/delivery/metrics.ex`.
  - `resource_summary` holds aggregate attempt counts and powers proficiency calculations in `Metrics.proficiency_per_student_across/2`.
  - `contained_objectives` is rebuilt on remix via `Sections.rebuild_contained_objectives/1` and provides container -> objective mappings.
  - `SectionResourceDepot` is the in-memory cache for section resources, including containers, pages, and objectives.
  - Prototype oracles exist under `lib/oli/instructor_dashboard/prototype/oracles/*` but are mock-data driven.
- Unknowns to confirm:
  - Final concrete oracle key/module bindings in the Instructor registry once tile stories finalize.
  - Exact oracle output shape normalization used by snapshot/projection layers (percent ranges confirmed here as 0..100 for bins).
  - Any additional indexes needed for `contained_objectives` or `resource_summary` queries on large sections.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.Oracles.ProgressBins`
  - Input: section + scope + axis container ids (direct children).
  - Computes per-student progress per container (average page progress), then bins into 0..100 buckets.
  - Injects missing students with 0% via roster comparison post-processing.
- `Oli.InstructorDashboard.Oracles.ProgressProficiency`
  - Input: section + scope.
  - Runs two queries: progress across scope and proficiency across scope.
  - Merges by student id into `{student_id, progress_pct, proficiency_pct}` payload.
- `Oli.InstructorDashboard.Oracles.StudentInfo`
  - Input: section id.
  - Returns enrolled learner identity fields (id, email, given/family name) and `last_interaction_at`.
  - `last_interaction_at` is read from `Enrollment.updated_at` for the student's enrollment in the section.
- `Oli.InstructorDashboard.Oracles.ScopeResources`
  - Input: section + scope.
  - Uses `SectionResourceDepot.get_delivery_resolver_full_hierarchy/1` to return direct children of the scope and course title.
- `Oli.InstructorDashboard.Oracles.Grades`
  - Input: section + scope.
  - Determines graded pages in scope and returns one aggregate record per graded page.
  - Each record includes `available_at`, `due_at`, `minimum_pct`, `median_pct`, `mean_pct`, `maximum_pct`, `standard_deviation_pct`, and fixed histogram counts for 10% ranges (`0-10` through `90-100`).
  - `available_at` and `due_at` are enriched from `SectionResourceDepot` for each graded page (no additional DB read for schedule metadata).
  - No per-student raw grades are returned by this oracle.
  - Exposes helper: `students_without_attempt_emails/2` for on-demand retrieval of enrolled learner emails with no attempts on a specific graded page.
- `Oli.InstructorDashboard.Oracles.ObjectivesProficiency`
  - Input: section + scope.
  - Uses `Sections.get_section_contained_objectives/2` to scope objective ids, fetches objective titles via depot, then calls `Metrics.objectives_proficiency/3` to compute distributions.

All concrete oracles implement the shared `Oli.Dashboard.Oracle` behavior and are bound through the Instructor registry from the `data_oracles` feature.

### 4.2 State & Message Flow
1. Oracle runtime constructs `OracleContext` with `section_id`, scope, and user identity.
2. Runtime calls `load/2` on each oracle with injected prerequisite inputs (none for this slice).
3. Oracle queries run as read-only DB calls (plus depot reads) and normalize payloads.
4. Post-processing fills missing students where needed (0% progress, nil proficiency for insufficient attempts); grades are already aggregate per page.
5. Payloads return to runtime for caching and snapshot assembly.

### 4.3 Supervision & Lifecycle
- No new supervised processes are introduced in this feature.
- Oracles are stateless modules executed within the oracle runtime’s Task supervision.
- Failures remain isolated to the executing oracle; the runtime handles error envelopes and cache behavior.

### 4.4 Alternatives Considered
- Return raw per-student per-page progress and bin client-side: rejected due to large memory footprint for large sections and repeated scopes.
- SQL cross-join of students x containers for zero-progress bins: rejected as a default path due to worst-case query size; retained as an optional strategy if needed.
- ClickHouse for `GradesOracle` aggregations: recommended as the primary execution path due to high-cardinality aggregate workloads (median, standard deviation, histogram buckets) and expected lower latency for large sections.

## 5. Interfaces
### 5.1 HTTP/JSON APIs
- None. Oracles are internal runtime modules.

### 5.2 LiveView
- None. LiveView consumes snapshots; no direct LiveView events or assigns added here.

### 5.3 Processes
- `Oli.Dashboard.Oracle` behavior callbacks:
  - `key/0 :: atom()`
  - `version/0 :: non_neg_integer()`
  - `requires/0 :: [oracle_key()]` (expected `[]` for these oracles)
  - `load/2 :: OracleContext.t(), keyword() -> {:ok, payload} | {:error, reason}`
- Concrete oracle payloads (summarized):
  - ProgressBins: `%{bin_size: 10, by_container_bins: %{container_id => %{0 => count, 10 => count, ...}}, total_students: integer}`
  - ProgressProficiency: `[%{student_id, progress_pct, proficiency_pct}]`
  - StudentInfo: `[%{student_id, email, given_name, family_name, last_interaction_at}]`
  - ScopeResources: `%{course_title, items: [%{resource_id, resource_type_id, title}]}`
  - Grades: `[%{page_id, available_at, due_at, score_stats: %{minimum_pct, median_pct, mean_pct, maximum_pct, standard_deviation_pct}, histogram_bins: %{0 => count, 10 => count, 20 => count, 30 => count, 40 => count, 50 => count, 60 => count, 70 => count, 80 => count, 90 => count}, total_scored_students}]`
  - ObjectivesProficiency: `[%{objective_id, title, proficiency_distribution}]`
- Additional Grades helper API:
  - `students_without_attempt_emails(section_id, resource_id) :: {:ok, [String.t()]} | {:error, term()}`

## 6. Data Model & Storage
### 6.1 Ecto Schemas
- No migrations planned.
- Read-only usage of: `ContainedPage`, `ResourceAccess`, `ResourceSummary`, `ContainedObjective`, `Enrollment`, `SectionResource`.

### 6.2 Query Performance
- Progress bins:
  - Query `contained_pages` for `page_count` per container.
  - Join `resource_accesses` by page_id and user_id, group by student/container.
  - Post-process with roster to include 0% rows.
- Progress+Proficiency:
  - Progress query mirrors `Metrics.progress_for/3` with container filter.
  - Proficiency query mirrors `Metrics.proficiency_per_student_across/2` with `resource_summary` and contained pages filter.
- StudentInfo:
  - Query enrollments joined to users for learners in section, selecting identity fields plus `Enrollment.updated_at AS last_interaction_at`.
  - `last_interaction_at` tracks the latest course page interaction because enrollment updates include `most_recently_visited_resource`, which touches `updated_at`.
- Grades:
  - Preferred path: ClickHouse query grouped by graded page, computing normalized score percentages (`score / out_of * 100`) and aggregate metrics per page.
  - Aggregate fields: `min`, `quantile(0.5)` (median), `avg` (mean), `max`, `stddevPop`.
  - Histogram fields: fixed bucket counts for lower bounds `{0, 10, 20, ..., 90}` computed from normalized percentage.
  - Fallback path: Postgres aggregation query (or staged rollups) that emits the identical payload contract when ClickHouse is unavailable.
  - Metadata enrichment: hydrate `available_at` and `due_at` for each `page_id` from `SectionResourceDepot` section resources; this is in-memory and avoids extra DB reads.
  - No-attempt email helper query: enrollments + users (learner role + enrolled status) left joined to page attempts/accesses; return emails where no attempt exists for `(section_id, resource_id, user_id)`.
- Objectives proficiency:
  - Fetch objective ids from `contained_objectives` then call `Metrics.objectives_proficiency/3`.
- Index expectations (verify):
  - `contained_pages(section_id, container_id)`
  - `resource_accesses(section_id, resource_id, user_id)`
  - `resource_summary(section_id, resource_id, user_id)`
  - `contained_objectives(section_id, container_id)`

## 7. Consistency & Transactions
- Read-only queries; no explicit transactions required.
- Oracle outputs are eventually consistent with `resource_accesses` and `resource_summary` updates.
- Missing or stale summary data yields `nil` proficiency, not misleading values.

## 8. Caching Strategy
- Caching is handled by dashboard runtime layers; oracles must be deterministic and cache-safe.
- Cache keys are composed of `oracle_key + version + section_id + scope`.
- Oracles return stable payloads for a given input; post-processing uses the same enrolled roster for determinism.

## 9. Performance and Scalability Plan
### 9.1 Budgets
- p95 <= 300ms (Normal 200 learners) and p95 <= 700ms (Large 2,000 learners) for uncached single-scope execution.
- Payload sizes bounded by: per-container bins, per-student tuples for progress/proficiency, and per-page aggregate rows for grades.

### 9.3 Hotspots & Mitigations
- Large cross-joins for 0% progress: mitigate with post-processing roster merge.
- Large container with many pages: use `contained_pages` and `section_resources.contained_page_count` to avoid repeated counts.
- Large `resource_summary` IN subqueries: mitigate by using a contained pages subquery and validating indexes.

## 10. Failure Modes & Resilience
- DB timeout or query failure: return error envelope; do not crash runtime.
- Empty container (no pages): guard with `NULLIF` or max(1) page counts to avoid divide-by-zero.
- Missing `contained_objectives` entries: return empty objective list and log a warning.

## 11. Observability
- Emit telemetry for each oracle execution:
  - Event: `[:oli, :dashboard, :oracle, :execute]`
  - Measurements: `duration_ms`, `row_count`, `payload_size`
  - Metadata: `oracle_key`, `section_id`, `container_id`, `cache_hit`
- Log warnings for slow queries (p95 threshold) and missing containment mappings.

## 12. Security & Privacy
- Oracles are instructor/admin-only; enforce section authorization via existing context checks.
- Student data exposure limited to identity fields required for drilldowns.
- All queries are scoped by `section_id` and filtered to enrolled learners.

## 13. Testing Strategy
- Unit tests:
  - Progress bins: correct binning, 0% injection, container scoping.
  - Progress+Proficiency: merge correctness, nil proficiency for low attempts.
  - StudentInfo: role filtering (context_learner only), distinctness, and `last_interaction_at` sourced from `Enrollment.updated_at`.
  - ScopeResources: direct child resolution from depot hierarchy.
  - Grades: graded page scope filter, `available_at`/`due_at` enrichment from depot, correct aggregate stats (`minimum`, `median`, `mean`, `maximum`, `standard_deviation`), and correct counts in fixed 10% histogram buckets.
  - Grades helper: `students_without_attempt_emails/2` returns only enrolled learner emails with no attempts and excludes attempted learners/instructors.
  - Objectives proficiency: scope filtering via contained_objectives.
- Integration tests:
  - Oracle runtime loads concrete oracles for a sample scope and returns expected payload shapes.
- Manual checks:
  - Validate a real section scope renders expected bins and pie chart groupings.

## 14. Backwards Compatibility
- N/A. No schema changes and no external API modifications.

## 15. Risks & Mitigations
- Performance risk for large sections -> use post-processing for 0% inclusion and maintain indexes.
- Stale contained_objectives -> ensure rebuild on remix; add logging for missing scope mappings.
- Divergence from existing metrics definitions -> reuse `Metrics` implementations and add regression tests.

## 16. Open Questions & Follow-ups
- None.

## 17. References
- None.

## 18. Decision Log
### 2026-02-19 - Grades Oracle Aggregation Contract + ClickHouse Recommendation
- Change: Replaced `GradesOracle` per-student raw grade tuple contract with per-page aggregate statistics and fixed 10-bin score histogram output; documented ClickHouse-first execution strategy with Postgres fallback.
- Reason: Assessment tile requires per-page summary statistics and distribution visualization payloads, not raw learner-level tuples.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/fdd.md`.
- Impact: Implementation and tests now target aggregate grades payload semantics and distribution bins; rollout planning should include ClickHouse parity validation.
### 2026-02-19 - Grades Oracle Added No-attempt Email Read-through
- Change: Added `students_without_attempt_emails(section_id, resource_id)` helper contract and query strategy under `GradesOracle`.
- Reason: UI requires an on-demand instructor action to email students who have not attempted a selected graded page, without expanding the main oracle payload.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`.
- Impact: Implementation and tests must validate learner-role filtering and no-attempt detection for targeted outreach actions.
### 2026-02-19 - Grades Payload Adds Schedule Metadata
- Change: Extended `GradesOracle` aggregate payload and query guidance to include `available_at` and `due_at` per page via `SectionResourceDepot` enrichment.
- Reason: Assessments tile needs static schedule metadata alongside grade distributions without additional oracle calls.
- Evidence: `docs/epics/intelligent_dashboard/concrete_oracles/README.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`.
- Impact: Implementation must enrich aggregate rows with in-memory section resource metadata and test this mapping.
