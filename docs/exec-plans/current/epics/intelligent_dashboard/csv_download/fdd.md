# Intelligent Dashboard CSV Download - FDD

Last updated: 2026-04-16
Feature: `csv_download`
Primary Jira: `MER-5266`
Related feature docs: `docs/exec-plans/current/epics/intelligent_dashboard/csv_download/prd.md`, `docs/exec-plans/current/epics/intelligent_dashboard/data_snapshot/prd.md`
Reference sample: `torus_dashboard_export_example.zip`

## 1. Executive Summary

This feature should be implemented on top of the existing `data_snapshot` infrastructure rather than through a separate reporting/query path. The snapshot/projection layer already exists to keep dashboard consumers semantically aligned, and `MER-5266` should now replace the placeholder CSV dataset scaffolding with the concrete ZIP bundle required by the ticket.

Phase 1 establishes the concrete export contract. It defines:

- the exact CSV files and column order to emit in v1,
- which current projection owns each dataset,
- which dashboard UI state must be captured at click time,
- and which projection gaps must be filled before Phase 2 serializer work begins.

The key implementation posture is:

- export remains transform-only over `snapshot_bundle`,
- tile-owned semantics remain tile-owned,
- shared metadata/summary files are assembled from snapshot metadata plus projection outputs,
- no export code should issue independent analytics queries.

## 2. Current State Assessment

Existing infrastructure:

- `Oli.InstructorDashboard.DataSnapshot` already builds scoped snapshot bundles for dashboard consumers.
- `Oli.InstructorDashboard.DataSnapshot.CsvExport` already assembles ZIP output from dataset specs and serializers.
- `Oli.InstructorDashboard.DataSnapshot.DatasetRegistry` currently defines placeholder datasets such as `summary.csv`, `progress.csv`, and `assessments.csv`.
- `Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.MapRows` is generic scaffolding and does not match the ticket's required tabular CSV outputs.

Current projection maturity:

- `progress` projection already contains reusable series data suitable for `student_progress_by_unit.csv`.
- `student_support` projection already contains reusable bucket and student row data suitable for `student_support_summary.csv` and `student_support_list.csv`.
- `challenging_objectives` projection already contains reusable objective rows, but export-specific flattening and proficiency calculation rules must be made explicit.
- `assessments` projection already contains reusable assessment rows and histogram bins suitable for `assessment_scores_distribution.csv` and `assessment_summary.csv`.
- `summary` projection is still thin and does not yet expose the concrete values needed for `dashboard_metadata.csv` and `course_summary_metrics.csv`.

Conclusion:

- the architecture should be reused,
- the placeholder dataset registry should be replaced,
- summary/metadata shaping must be added,
- and some projections need export-oriented normalization fields even when the underlying tile projection is already close.

## 3. Source-of-Truth Rules

The following rules govern the implementation:

1. Export must reflect the same scoped data the instructor is viewing at click time.
2. Export must use the same parameterized semantics the tiles use at click time.
3. Tile semantics stay tile-owned. Export may flatten tile projection data, but it must not redefine tile meaning in a parallel path.
4. Shared metadata files may compose values across projections and dashboard context.
5. Empty datasets are omitted. No placeholder CSVs should be emitted.
6. Jira comment decisions dated April 16, 2026 supersede the sample ZIP where they conflict.

## 4. Click-Time State Snapshot

The export request must capture the following dashboard state at click time:

| State | Source | Why it matters |
|---|---|---|
| `dashboard_scope` | dashboard URL / LiveView assigns | Determines course vs container export scope |
| progress completion threshold | `tile_progress[threshold]` | Changes progress counts/rates |
| progress y-axis mode | `tile_progress[mode]` | UI-only; should not affect export values |
| student support search term | `tile_support[q]` | UI-only; should not filter export in v1 |
| student support selected bucket | `tile_support[bucket]` | UI-only; should not filter export in v1 |
| student support activity filter | `tile_support[filter]` | Presentational filter in the current tile; should not narrow export rows in v1 |
| inactivity threshold days | projection option currently defaults to `7` | Drives inactive classification in support outputs |
| proficiency definition label | dashboard/shared config | Required in metadata file |
| assessment completion threshold | projection option currently defaults to `50` | Affects assessment completion status semantics |
| browser timezone | LiveView assigns | Required for metadata and timestamp formatting |
| section/course identity | LiveView assigns plus scope resources | Required for ZIP naming and metadata rows |

Implementation decision for Phase 1:

- `dashboard_scope`, inactivity threshold, progress completion threshold, assessment completion threshold, timezone, and proficiency definition are semantic export inputs and must be captured.
- current pagination, expanded rows, and disclosure state are presentational and must not affect export contents.
- student support search term and selected bucket are presentational in the current tile implementation and should not narrow export contents in v1.
- student support activity filter should not narrow export rows in v1; export should include the full scoped student support list.

## 5. Concrete Dataset Contract

The export ZIP must contain the following datasets when applicable.

### 5.1 `dashboard_metadata.csv`

Purpose:
- shared context file for the exact export request and dashboard semantics.

Columns:
- `field`
- `value`

Rows:
- `course_name`
- `course_section`
- `dashboard_scope`
- `generated_at`
- `time_zone`
- `completion_threshold`
- `proficiency_definition`
- `total_students`
- optional `notes` row is sample-only and should not be required in production

Ownership:
- shared export adapter, not a single tile

Primary inputs:
- section/course assigns
- scope selector and scope label
- export timestamp
- browser timezone
- progress completion threshold
- proficiency definition label
- total students from shared projection/oracle state

Gap:
- no current shared projection exposes this complete metadata shape.

### 5.2 `course_summary_metrics.csv`

Purpose:
- shared summary metrics for the current scope.

Columns:
- `metric`
- `value`
- `unit`

Rows:
- `average_class_proficiency`
- `average_assessment_score`
- `average_student_progress`

Ownership:
- shared export adapter backed by summary-capable projections

Primary inputs:
- summary projection or directly reusable projection-derived values from objectives, assessments, and progress

Gap:
- current `summary` projection is not yet a concrete metric projection. This needs extension before serializer work.

### 5.3 `student_progress.csv`

Purpose:
- scoped progress completion table corresponding to the progress tile.

Columns:
- `content_item`
- `students_completed`
- `completion_rate`

Ownership:
- progress tile export contract

Primary inputs:
- `progress.progress_tile.series_all`
- click-time progress completion threshold

Notes:
- `y_axis_mode` is UI-only and should not change exported numeric values.
- Jira clarification on April 16, 2026 selected stable non-dynamic naming: filename `student_progress.csv` and first column `content_item`.

Gap:
- current series items already contain enough data; export only needs stable row shaping.

### 5.4 `student_support_summary.csv`

Purpose:
- support bucket summary corresponding to the mutually-exclusive support buckets shown in the student support tile.

Columns:
- `category`
- `student_count`
- `percentage`

Ownership:
- student support tile export contract

Primary inputs:
- `student_support.support.buckets`

Notes:
- bucket ids should be serialized in snake case to match sample output.
- percentage formatting should be decided once and reused in tests.
- Jira clarification on April 16, 2026 removed `inactive` from this summary because inactivity is not a support bucket.

Gap:
- projection data is sufficient; serializer can be built directly once numeric formatting is fixed.

### 5.5 `student_support_list.csv`

Purpose:
- detailed student rows corresponding to student support categorization.

Columns:
- `student_id`
- `student_name`
- `progress_pct`
- `proficiency_pct`
- `support_category`
- `inactive`

Ownership:
- student support tile export contract

Primary inputs:
- flattened `student_support.support.buckets[*].students`

Notes:
- export should include all applicable rows for the current scope, not only currently paged rows.
- Jira clarification on April 16, 2026 ultimately kept the existing boolean inactive indicator in this file and only removed the `inactive` row from `student_support_summary.csv`.

Gap:
- projection data is sufficient; serializer needs flattening and stable sort order.

### 5.6 `challenging_learning_objectives.csv`

Purpose:
- export of low-proficiency objectives corresponding to the challenging objectives tile.

Columns:
- `objective_id`
- `objective_text`
- `proficiency`

Ownership:
- challenging objectives tile export contract

Primary inputs:
- flattened `challenging_objectives.rows`
- underlying objective proficiency distribution data

Gap:
- Jira clarification on April 16, 2026 explicitly chose UI parity here, so export should use the categorical proficiency label already shown in the tile rather than inventing a numeric average.

### 5.7 `assessment_scores_distribution.csv`

Purpose:
- histogram-style score distribution by assessment.

Columns:
- `assessment_name`
- `score_range`
- `student_count`

Ownership:
- assessments tile export contract

Primary inputs:
- `assessments.assessments.rows[*].histogram_bins`

Gap:
- projection data is sufficient, and Jira clarification on April 16, 2026 confirmed the existing 10-point histogram buckets should be used.

### 5.8 `assessment_summary.csv`

Purpose:
- per-assessment summary table corresponding to the assessments tile.

Columns:
- `assessment_name`
- `available_from`
- `due_date`
- `students_completed`
- `students_not_completed`
- `score_min`
- `score_median`
- `score_mean`
- `score_max`
- `score_std_dev`

Ownership:
- assessments tile export contract

Primary inputs:
- `assessments.assessments.rows`

Gap:
- projection data is sufficient; serializer must derive `students_not_completed` from totals and format nullable metrics/dates consistently.

## 6. Dataset-to-Projection Mapping

| Dataset | Owning projection / adapter | Status |
|---|---|---|
| `dashboard_metadata.csv` | shared export adapter over snapshot metadata + dashboard context | needs new shaping |
| `course_summary_metrics.csv` | shared export adapter over summary-capable projection data | needs projection work |
| `student_progress.csv` | `progress.progress_tile` | reusable |
| `student_support_summary.csv` | `student_support.support` | reusable |
| `student_support_list.csv` | `student_support.support` | reusable |
| `challenging_learning_objectives.csv` | `challenging_objectives` | reusable |
| `assessment_scores_distribution.csv` | `assessments.assessments` | reusable |
| `assessment_summary.csv` | `assessments.assessments` | reusable |

## 7. Required Projection Extensions Before Phase 2

The following extensions are required or strongly recommended before concrete serializer implementation.

### 7.1 Summary / Shared Metadata

Add a shared export-ready source for:

- course title
- section title
- scope label
- total students
- average class proficiency
- average assessment score
- average student progress
- proficiency definition label

Preferred approach:

- extend the summary/shared dashboard projection contract rather than computing these values ad hoc inside serializers.

### 7.2 Shared Export State Contract

Define an explicit export request map passed into `CsvExport.build_zip/2` that contains:

- scope selector and scope label
- export timestamp
- timezone
- progress completion threshold
- inactivity threshold days
- proficiency definition label
- assessment completion threshold
- course/section naming inputs

This avoids serializers reaching into LiveView assigns directly.

## 8. Explicit Non-Goals for Phase 1

Phase 1 does not:

- implement serializers,
- modify `DatasetRegistry`,
- add the dashboard button,
- wire LiveView download behavior,
- decide final partial-failure UX,
- or change query/oracle behavior.

## 9. Phase 2 Entry Criteria

Phase 2 can begin when:

1. the eight concrete datasets in this document are accepted as authoritative,
2. the click-time semantic state contract is accepted,
3. the summary/metadata projection extension approach is accepted,
4. and the revised Jira comment resolution is reflected in serializer/tests: remove the summary-row `inactive` entry but keep the detailed-list `inactive` boolean column.
