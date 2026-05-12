# Concrete Oracles: Progress Bins + Progress/Proficiency Raw

This note captures the concrete oracle split and query approach for the Instructor Intelligent Dashboard.
It is a required implementation companion to `prd.md` and `fdd.md` for oracle-specific query and payload details.

## Initial Implementation Policy (Required)

- For this initial concrete-oracle implementation, all oracle data paths must use the main Postgres database through standard Ecto queries (plus existing in-memory depot reads where applicable).
- Do not implement ClickHouse-backed execution paths in this first implementation pass.
- ClickHouse support (for selected oracle optimizations) is deferred until the end of the Intelligent Dashboard epic, after baseline Postgres implementations are complete, tested, and validated.

## Summary (Recommended Split)

1. **ProgressBinsOracle** (progress tile only)
   - Returns **per-container histogram counts** at fixed 10% bins (0..100).
   - Container granularity is **module-level** when scope is Unit (or Unit-level when scope is Course).
   - Fixed memory footprint, no per-student payload.

2. **ProgressProficiencyOracle** (proficiency pie + scatter modal)
   - Returns **raw per-student** tuples for the selected scope only:
     `{student_id, progress_pct, proficiency_pct}`.
   - Max payload size ~= enrolled students in the current scope (e.g., 1000 rows).
   - Projection bins the pie chart from these raw values; modal can render a real scatter plot.

3. **StudentInfoOracle** (student drilldown lists)
   - Returns enrolled student identifiers and display fields (id, email, first/last name) plus `last_interaction_at` from enrollment.

4. **ScopeResourcesOracle** (titles + types for direct items in scope)
   - Returns direct children of the current scope container with `resource_id`, `resource_type_id`, `title`.
   - Can also expose the course/section title.

5. **GradesOracle** (graded pages within scope)
   - Returns per-page aggregate grade statistics and histogram buckets for graded pages in the selected scope.
   - Enriches each graded page row with `available_at` and `due_at` from `SectionResourceDepot`.
   - Does not emit per-student raw grade rows from `load/2`.
   - Also provides `students_without_attempt_emails(section_id, resource_id)` for outreach actions.

6. **ObjectivesProficiencyOracle** (learning objectives proficiency in scope)
   - Returns objective proficiency distributions for objectives contained within the selected scope.

All oracles should be scoped by section + container (course/unit/module), and should filter to enrolled students only.

## Shared Assumptions

- Progress is stored on `resource_accesses.progress` as a float in the range `0.0..1.0`.
- Proficiency inputs are stored in `resource_summary` as aggregate attempt counts.
- `contained_pages` includes **all ancestor containers** for each page, and is rebuilt on remix.
  This is the correct join table to aggregate page-level data to any container.
- For a given container, **progress is the average of page-level progress** across all pages contained by that container.
  (Matches `Oli.Delivery.Metrics.progress_for/3`.)

References in code:
- `Oli.Delivery.Metrics.progress_for/3`
- `Oli.Delivery.Metrics.proficiency_per_student_across/2`
- `Oli.Delivery.Sections.rebuild_contained_pages/1`

## Oracle 1: ProgressBinsOracle (per-container progress bins)

### Inputs

- `section_id`
- `scope` (`container_type`, `container_id`)
- `axis_container_ids` (e.g. module ids within selected unit)
- `bin_size` fixed at `10` (bins 0..100)

### Output

```
%{
  bin_size: 10,
  by_container_bins: %{
    container_id => %{0 => count, 10 => count, ..., 100 => count}
  },
  total_students: integer
}
```

### Query Strategy

We need per-student progress per container, then bin counts.
We can do this in **one SQL query** with a small post-processing step to include zero-progress students.

#### Option A: SQL with student cross-join (fully in SQL)

This yields correct 0% bins for students with no resource_access rows.

```sql
WITH
  students AS (
    SELECT e.user_id
    FROM enrollments e
    WHERE e.section_id = $1 AND e.status = 'enrolled'
  ),
  containers AS (
    SELECT unnest($2::int[]) AS container_id
  ),
  page_counts AS (
    SELECT cp.container_id, COUNT(*) AS page_count
    FROM contained_pages cp
    WHERE cp.section_id = $1 AND cp.container_id = ANY($2)
    GROUP BY cp.container_id
  ),
  progress_by_student AS (
    SELECT
      cp.container_id,
      ra.user_id,
      SUM(ra.progress) / NULLIF(pc.page_count, 0) AS progress
    FROM contained_pages cp
    JOIN page_counts pc ON pc.container_id = cp.container_id
    JOIN resource_accesses ra
      ON ra.section_id = cp.section_id AND ra.resource_id = cp.page_id
    WHERE cp.section_id = $1 AND cp.container_id = ANY($2)
    GROUP BY cp.container_id, ra.user_id, pc.page_count
  )
SELECT
  c.container_id,
  LEAST(100, GREATEST(0, CEIL(COALESCE(p.progress, 0) * 10.0) * 10)) AS bin,
  COUNT(*) AS student_count
FROM containers c
CROSS JOIN students s
LEFT JOIN progress_by_student p
  ON p.container_id = c.container_id AND p.user_id = s.user_id
GROUP BY c.container_id, bin;
```

#### Option B: Two-step (lean SQL + lightweight post-processing)

1) Fetch per-student progress for students who have any resource_access rows.
2) In Elixir, inject missing students with progress 0.0 and then bin.

This avoids the cross-join in SQL and is acceptable for cohorts up to ~1000 students.

### Ecto Sketch

```elixir
page_counts =
  from(cp in ContainedPage,
    where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
    group_by: cp.container_id,
    select: {cp.container_id, count(cp.id)}
  )

progress_by_student =
  from(cp in ContainedPage,
    join: ra in ResourceAccess,
    on:
      cp.page_id == ra.resource_id and
        cp.section_id == ra.section_id and
        ra.user_id in ^student_ids,
    join: pc in subquery(page_counts),
    on: pc.container_id == cp.container_id,
    where: cp.section_id == ^section_id and cp.container_id in ^container_ids,
    group_by: [cp.container_id, ra.user_id, pc.count],
    select: {
      cp.container_id,
      ra.user_id,
      fragment("SUM(?) / NULLIF(?, 0)", ra.progress, pc.count)
    }
  )
```

### Notes

- If `container_id == nil` (course root), `contained_pages` rows use `NULL` for container_id. For ProgressBinsOracle we avoid root bins and operate on concrete containers (units/modules).
- Use `section_resources.contained_page_count` if you want to avoid the `page_counts` subquery.
- Prefer `enrollments.status == :enrolled` to avoid including instructors.

## Oracle 2: ProgressProficiencyOracle (raw per-student tuples)

### Inputs

- `section_id`
- `scope` (`container_type`, `container_id`)

### Output

```
[
  %{student_id: 123, progress_pct: 72.0, proficiency_pct: 0.81},
  ...
]
```

`progress_pct` is normalized to `0..100`, and `proficiency_pct` is normalized to `0.0..1.0`.

### Query Strategy

Two queries, merged by `student_id`:

1) **Progress across scope** using `resource_accesses` + `contained_pages` (average of page progress).
2) **Proficiency across scope** using `resource_summary` + `contained_pages` (aggregate correctness formula).

#### Progress Query (adapted from `Metrics.progress_for/3`)

```sql
WITH
  page_counts AS (
    SELECT COUNT(*) AS page_count
    FROM contained_pages
    WHERE section_id = $1 AND container_id = $2
  )
SELECT
  ra.user_id,
  (SUM(ra.progress) / NULLIF(pc.page_count, 0)) * 100 AS progress_pct
FROM contained_pages cp
JOIN page_counts pc ON TRUE
JOIN resource_accesses ra
  ON ra.section_id = cp.section_id AND ra.resource_id = cp.page_id
WHERE cp.section_id = $1 AND cp.container_id = $2
GROUP BY ra.user_id, pc.page_count;
```

In Elixir, merge enrolled students and default missing users to progress 0.0.

#### Proficiency Query (adapted from `Metrics.proficiency_per_student_across/2`)

```sql
SELECT
  summary.user_id,
  (
    (1 * SUM(summary.num_first_attempts_correct)) +
    (0.2 * (SUM(summary.num_first_attempts) - SUM(summary.num_first_attempts_correct)))
  ) / NULLIF(SUM(summary.num_first_attempts), 0.0) AS proficiency_pct,
  SUM(summary.num_first_attempts) AS num_first_attempts
FROM resource_summary summary
WHERE summary.section_id = $1
  AND summary.project_id = -1
  AND summary.user_id != -1
  AND summary.resource_type_id = $page_type_id
  AND summary.resource_id IN (
    SELECT cp.page_id
    FROM contained_pages cp
    WHERE cp.section_id = $1 AND cp.container_id = $2
  )
GROUP BY summary.user_id;
```

For students with `num_first_attempts < 3` (see `proficiency_range/2`), return `nil` to keep N/A behavior.

### Merge Step

In Elixir:

1. Load enrolled student ids (`Sections.enrolled_student_ids/1`).
2. Build a map of `progress_pct` by student (default 0.0).
3. Build a map of `proficiency_pct` by student (default nil when missing or insufficient attempts).
4. Emit list of `{student_id, progress_pct, proficiency_pct}`.

### Notes

- This oracle is intentionally **not per-module** to keep memory bounded.
- The scatter modal can be rendered from this raw list.
- The proficiency pie chart can be computed by binning on the projection layer.

## Oracle 3: StudentInfoOracle (enrolled student identity data)

### Inputs

- `section_id`

### Output

```
[
  %{
    student_id: 123,
    email: "a@b.com",
    given_name: "Ada",
    family_name: "Lovelace",
    last_interaction_at: ~U[2026-02-24 12:34:56Z]
  },
  ...
]
```

### Query Strategy

Filter to enrolled learners only (exclude instructors). Use the same role filter as
`Sections.enrolled_student_ids/1` (`context_learner`) and enrollment status `:enrolled`.

#### Ecto Sketch

```elixir
student_role_id = Lti_1p3.Roles.ContextRoles.get_role(:context_learner).id

query =
  from(e in Enrollment,
    join: ecr in assoc(e, :context_roles),
    join: u in assoc(e, :user),
    where: e.section_id == ^section_id and e.status == :enrolled and ecr.id == ^student_role_id,
    select: %{
      student_id: u.id,
      email: u.email,
      given_name: u.given_name,
      family_name: u.family_name,
      last_interaction_at: e.updated_at
    },
    distinct: u.id
  )
```

### Notes

- Keep this payload minimal (no full user struct) since it is used for drilldown lists and hover cards.
- This oracle is often reused by other tiles that need student lists.

## Oracle 4: ScopeResourcesOracle (titles + types for current scope)

### Inputs

- `section_id`
- `scope` (`container_type`, `container_id`)

### Output

```
%{
  course_title: "Course Title",
  items: [
    %{resource_id: 101, resource_type_id: 1, title: "Unit 1"},
    %{resource_id: 102, resource_type_id: 1, title: "Unit 2"}
  ]
}
```

### Query Strategy

Use `SectionResourceDepot` (in-memory) to avoid DB round trips. The depot already caches section resources.

#### Approach

1. Fetch the course title from `Section.title` (or from the root section resource if preferred).
2. Load hierarchy via `SectionResourceDepot.get_delivery_resolver_full_hierarchy/1`.
3. Resolve the current scope node and return its **direct children** with `resource_id`, `resource_type_id`, `title`.

### Notes

- This oracle is intentionally fast and avoids SQL.
- When scope is `:course`, return top-level units (container children of root).

## Oracle 5: GradesOracle (graded pages within scope)

### Inputs

- `section_id`
- `scope` (`container_type`, `container_id`)

### Output

```
%{
  grades: [
    %{
      page_id: 201,
      minimum: 42.0,
      median: 71.5,
      mean: 69.8,
      maximum: 100.0,
      standard_deviation: 14.3,
      histogram: %{
        "0-10" => 0,
        "10-20" => 1,
        "20-30" => 2,
        "30-40" => 4,
        "40-50" => 6,
        "50-60" => 8,
        "60-70" => 12,
        "70-80" => 9,
        "80-90" => 5,
        "90-100" => 3
      },
      available_at: ~U[2026-03-01 14:00:00Z],
      due_at: ~U[2026-03-07 23:59:59Z]
    },
    ...
  ]
}
```

`minimum`, `median`, `mean`, `maximum`, and `standard_deviation` are percentage scores (`0.0..100.0`) computed per page for enrolled learners with attempts.

### Query Strategy

Step 1: Determine **graded page ids** within the selected scope.

Options:
1. **In-memory**: use `SectionResourceDepot.graded_pages/1` plus hierarchy traversal to filter to
   descendants of the current container.
2. **SQL**: use `contained_pages` to filter graded pages by container id.

Step 2: Aggregate `resource_accesses` rows for enrolled learners by `page_id`:
- score stats: `minimum`, `median`, `mean`, `maximum`, `standard_deviation`
- histogram bucket counts across fixed percentage ranges: `0-10, 10-20, ..., 90-100`

Step 3: Enrich each graded page aggregate row with `available_at` and `due_at`
from `SectionResourceDepot` section resources.

#### Ecto Sketch (SQL-based containment)

```elixir
page_ids =
  from(cp in ContainedPage,
    join: sr in SectionResource,
    on: sr.resource_id == cp.page_id and sr.section_id == cp.section_id,
    where:
      cp.section_id == ^section_id and
        cp.container_id == ^container_id and
        sr.graded == true,
    select: cp.page_id,
    distinct: true
  )
  |> Repo.all()

grade_aggregates =
  from(ra in ResourceAccess,
    join: e in Enrollment,
    on: e.section_id == ra.section_id and e.user_id == ra.user_id and e.status == :enrolled,
    join: ecr in assoc(e, :context_roles),
    where:
      ra.section_id == ^section_id and
        ra.resource_id in ^page_ids and
        ecr.id == ^student_role_id and
        not is_nil(ra.score) and
        not is_nil(ra.out_of) and
        ra.out_of > 0,
    group_by: ra.resource_id,
    select: %{
      page_id: ra.resource_id,
      minimum: fragment("MIN((? / ?) * 100.0)", ra.score, ra.out_of),
      median: fragment("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (? / ?) * 100.0)", ra.score, ra.out_of),
      mean: fragment("AVG((? / ?) * 100.0)", ra.score, ra.out_of),
      maximum: fragment("MAX((? / ?) * 100.0)", ra.score, ra.out_of),
      standard_deviation: fragment("STDDEV_POP((? / ?) * 100.0)", ra.score, ra.out_of)
    }
  )
  |> Repo.all()
```

Build the histogram map in SQL or in a second grouped query keyed by `page_id`.
Merge stats + histogram + schedule metadata in Elixir and return one row per graded page.

#### Direct helper: `students_without_attempt_emails/2`

Expose a read-through function:
- Input: `(section_id, resource_id)`
- Output: `{:ok, [email]} | {:error, reason}`
- Behavior:
  - includes only enrolled `context_learner` users in the section
  - excludes users with any attempt row for the page in `resource_accesses`
  - excludes instructor/non-learner roles

### Notes

- If using the in-memory hierarchy, you can avoid joining `contained_pages` entirely.
- `SectionResourceDepot.graded_pages/1` already returns graded page section resources.

## Oracle 6: ObjectivesProficiencyOracle (learning objectives in scope)

### Inputs

- `section_id`
- `scope` (`container_type`, `container_id`)

### Output

```
[
  %{
    objective_id: 555,
    title: "Apply conservation of energy",
    proficiency_distribution: %{
      "High" => 12,
      "Medium" => 18,
      "Low" => 6,
      "Not enough data" => 14
    }
  },
  ...
]
```

### Query Strategy (Primary / Postgres)

**Key existing mechanism:** `contained_objectives` table.

This table is rebuilt on remix via `Sections.rebuild_contained_objectives/1` and is populated by:
- `contained_pages` (page containment by container),
- JSONB activity references inside page content (`get_all_activity_references`),
- activity revisions’ `objectives` JSON (objective ids attached to activities).

That gives a **direct container → objective_id** mapping without ad-hoc graph traversal at runtime.

#### Step 1: Objective IDs for current scope

```elixir
objective_ids = Sections.get_section_contained_objectives(section_id, container_id)
```

`container_id == nil` returns root (entire section) objectives.

#### Step 2: Objective titles (fast, in-memory)

```elixir
objective_srs =
  SectionResourceDepot.get_resources_by_ids(section_id, objective_ids)
```

Filter to objective `resource_type_id` if needed.

#### Step 3: Proficiency distribution

Reuse existing aggregation logic in `Metrics.objectives_proficiency/3`:

```elixir
Metrics.objectives_proficiency(section_id, section_slug, objective_srs)
```

This uses:
- `proficiency_per_student_for_objective/2` (objective-level summaries in `resource_summary`)
- enrolled student filtering (`Sections.enrolled_student_ids/1`)
- distribution counts for `High/Medium/Low/Not enough data`

### Deferred Alternative (ClickHouse, Post-epic)

If we need lower latency or richer attempt-level slicing, a ClickHouse query over xAPI can
aggregate by objective ids per scope pages. This would be the **first CH-backed oracle** and
adds operational risk; the Postgres `contained_objectives` + `resource_summary` path should be
the baseline for this implementation. Do not implement this alternative in the initial delivery pass.

### Notes

- This approach **avoids per-page activity joins at query time** by relying on the precomputed
  `contained_objectives` mapping.
- `related_activities` on objective section resources is precomputed and useful for counts,
  but it is **not container-scoped**; `contained_objectives` is the scope filter.

## Implementation Placement

Proposed modules (names are illustrative):

- `Oli.InstructorDashboard.Oracles.ProgressBins`
- `Oli.InstructorDashboard.Oracles.ProgressProficiency`
- `Oli.InstructorDashboard.Oracles.StudentInfo`
- `Oli.InstructorDashboard.Oracles.ScopeResources`
- `Oli.InstructorDashboard.Oracles.Grades`
- `Oli.InstructorDashboard.Oracles.ObjectivesProficiency`

Both should conform to `Oli.Dashboard.Oracle` and be wired through the instructor registry.

## Resolved Decisions

- Bin size is fixed at 10% for the feature (`0, 10, 20, ... 100` for progress bins; `0-10` through `90-100` for grade histograms).
- Progress missing-student default is `0.0`; proficiency missing/insufficient attempts remains `nil`.
- Progress zero-fill may be done in SQL (cross-join) or Oracle post-processing, but output semantics are fixed.
