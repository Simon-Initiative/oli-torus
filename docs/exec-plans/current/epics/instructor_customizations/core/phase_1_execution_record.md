# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/core`
Phase: `1`

## Scope from plan.md
- Establish the additive instructor-customization persistence model.
- Add the compact page-level exclusion read model and pure enabled-state predicates.
- Keep authored revisions, publications, and `SectionResource` records untouched.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Notes:
- Added `section_page_activity_exclusions` with one row per active exclusion, section ownership, target-shape constraint, partial uniqueness constraints, and indexes for the concrete page and selection reads.
- Kept page and activity resource ids without foreign keys so authored content changes can leave harmless stale rows; section deletion still cascades.
- Added `ActivityExclusion.changeset/4`, which receives trusted section/page scope separately from target attrs so later transport callers cannot mass-assign cross-section scope.
- Added `%PageExclusions{}` with MapSet-backed lookup fields and pure predicates for embedded activities, selections, and selection-local candidates.
- Added separate raw and compact page reads. The compact hot-path read selects only the three fields needed by the view and executes one repository query.
- Documented raw and compact reads as trusted/internal APIs until Phase 2 adds authorized UI-facing boundaries.
- No telemetry events were needed for this read-only foundation phase.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification:
- `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/core --check all`
- `mix test test/oli/delivery/instructor_customizations`
- `mix format --check-formatted priv/repo/migrations/20260604120000_create_section_page_activity_exclusions.exs lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/activity_exclusion.ex lib/oli/delivery/instructor_customizations/page_exclusions.ex test/oli/delivery/instructor_customizations/context_test.exs test/oli/delivery/instructor_customizations/activity_exclusion_test.exs`
- `mix compile --warnings-as-errors`
- `MIX_ENV=test mix ecto.rollback --step 1`
- `MIX_ENV=test mix ecto.migrate`

Results:
- Work-item validation passed before implementation.
- Targeted Phase 1 tests passed: `12 tests, 0 failures`.
- Formatting check passed.
- Compilation with warnings as errors passed.
- The migration was verified forward and backward successfully.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

Notes:
- Updated the FDD and plan to retain only indexes backed by concrete reads. Future reporting and kind-summary indexes will be added with the queries that require them.
- Clarified in the plan that `AC-003` is split across phases: Phase 1 proves database uniqueness; Phase 2 must prove repeated disable operations are idempotent at the context API boundary.
- No PRD changes were required.

## Review Loop
- Round 1 findings:
  - Scope fields could be mass-assigned through the changeset.
  - Trusted/internal reads did not document their authorization boundary.
  - The compact page view selected and sorted more data than needed.
  - Candidate predicates allocated an empty MapSet on every missing-selection lookup.
  - Two indexes were speculative rather than tied to current queries.
  - Query-count telemetry needed to filter unrelated repository queries.
  - Database shape constraint and required-field combinations needed broader tests.
  - `AC-003` idempotency belongs to Phase 2 and needed explicit traceability.
- Round 1 fixes:
  - Passed trusted section/page scope separately into `changeset/4` and added overwrite protection coverage.
  - Documented trusted/internal read boundaries.
  - Added a minimal one-query projection for `%PageExclusions{}` and optimized the candidate predicate.
  - Removed speculative indexes and synchronized the FDD/plan.
  - Hardened query-count filtering and expanded changeset/database constraint coverage.
  - Documented the split responsibility for `AC-003`.
- Round 2 findings:
  - Candidate grouping eagerly allocated a default MapSet even when the selection already existed.
  - Coverage did not explicitly prove that exclusion persistence leaves revisions, published resources, and section resources untouched.
  - Uniqueness coverage did not explicitly prove that the same targets remain valid across different section, page, and selection scopes.
- Round 2 fixes:
  - Replaced eager candidate grouping with a fetch-and-update branch.
  - Added explicit non-mutation coverage for authored and section-resource records.
  - Added positive uniqueness-scope coverage across sections, pages, and selections.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
