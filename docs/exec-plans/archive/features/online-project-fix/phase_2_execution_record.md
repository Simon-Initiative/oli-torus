# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/online-project-fix`
Phase: `2 - Streamed Read-Only Analysis and Reporting`

## Scope from plan.md
- Implement the non-mutating, publication-scoped analysis path.
- Stream current page content and retain only compact relationship maps and report metadata.
- Exclude Adaptive pages, report missing activities, and classify cross-page sharing deterministically.
- Add complete context coverage for the Phase 2 analysis portions of `AC-003` through `AC-014`; defer `AC-011`'s post-repair assertion to Phase 3.
- Do not implement repair writes, locks, telemetry, routing, or LiveView behavior.

## Implementation Blocks
- [x] Core behavior changes
  - Added a parameterized working-publication page query over current, non-deleted, project-scoped revisions.
  - Enumerated page content with `Repo.stream/2` inside its required transaction and bounded each cursor fetch with `:stream_max_rows`.
  - Classified only exact top-level boolean `advancedDelivery: true` as Adaptive; missing and false flags remain Basic.
  - Extracted nested references through `Oli.Authoring.Editing.Utils.activity_references/1`, retained both compact `MapSet` relationship directions, and discarded each page body after reduction.
  - Resolved sorted unique activity ids through `AuthoringResolver.existing_activity_resource_ids/2` in bounded chunks, selecting only validated ids and no activity JSON.
  - Returned deterministically ordered missing records and shared groups, including non-repairable shared missing ids and all required summary cardinalities.
- [x] Data or interface changes
  - Replaced the Phase 1 `:analysis_not_implemented` boundary with `{:ok, %Report{}}` for valid analysis calls.
  - Added the content-free `{:invalid_page_content, page_resource_id}` analysis error.
  - Kept the Phase 3 repair boundary explicitly fail-closed as `:repair_not_implemented`.
- [x] Access-control or safety checks
  - Preserved persisted system-admin authorization before every option, project, publication, or page query.
  - Excluded Adaptive page metadata and references from both relationship maps, not merely from final rendering.
  - Rejected malformed page trees and non-positive/non-integer activity ids before resolver queries rather than returning a partial report or leaking lower-level exceptions.
  - Analysis performs no writes and missing references remain report-only.
- [x] Observability or operational updates when needed
  - No project-repair telemetry or logging added; bounded operational instrumentation remains Phase 4 scope.

## Test Blocks
- [x] Tests added or updated
  - Updated Phase 1 boundary tests for real read-only reports while retaining authorization, normalization, and option-bound coverage.
  - Added coverage for empty/no-reference projects, missing/false/true Adaptive flags, nested and repeated references, two independent repairable groups, one shared missing group, compact deterministic output, deleted/non-project rows, malformed traversable content, wrong-type references, and corrupt mapping/revision mismatches.
  - Added before/after counts plus full relevant authoring, mapping, publication, delivery-section, and learner-access row snapshots proving analysis neither inserts nor updates state.
  - Counted resolver telemetry events with a one-id batch size to prove unique ids are chunked and repeated page relationships do not create an N+1.
- [x] Required verification commands run
  - `mix test test/oli/authoring/project_repair_test.exs`
  - `mix test test/oli/authoring/project_repair_test.exs test/oli/publishing/authoring_resolver_test.exs --exclude flaky`
  - `mix format --check-formatted lib/oli/publishing/authoring_resolver.ex lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair/*.ex test/oli/authoring/project_repair_test.exs`
  - `mix compile --warnings-as-errors`
- [x] Results captured
  - Targeted context suite passed: 17 tests, 0 failures.
  - Combined project-repair and existing authoring-resolver suites passed: 38 tests, 0 failures, with one pre-existing `@tag :flaky` ordering test excluded.
  - Formatting check passed.
  - Warnings-as-errors compilation passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Updated the FDD and plan to record the activity-only resolver projection introduced during review. The projection preserves the approved project scoping and batching while selecting no full activity JSON and rejecting wrong-type resources.
- [x] Open questions added to docs when needed
  - No new open question introduced in Phase 2.

## Review Loop
- Round 1 findings:
  - Security/Elixir: generic non-`nil` revisions could classify page/container ids as repairable activity sources.
  - Performance: generic resolver batches loaded complete activity revisions even though analysis needed only existence/type ids.
  - Requirements: non-mutation snapshots used counts where full row comparisons were needed, and report tests did not assert title/editor-target metadata.
  - Requirements/Elixir: Phase 2 records and Gate B overstated the post-repair portion of `AC-011`, which belongs to Phase 3.
- Round 1 fixes:
  - Added `AuthoringResolver.existing_activity_resource_ids/2`, which selects only current project activity ids and no activity JSON.
  - Added wrong-resource-type coverage and title/revision-slug assertions for missing and shared page summaries.
  - Strengthened persistence snapshots to compare current project revisions/content, mappings, project/publication state, and relevant delivery/learner rows in addition to global insert-detection counts.
  - Clarified the Phase 2 execution record and Gate B wording to defer `AC-011` post-repair verification to Gate C.
- Round 2 findings (optional):
  - Security: the new resolver projection needed to prove mapping and revision resource ids match before certifying an activity.
  - Performance: test snapshots retained unrelated/global rows and historical project revisions unnecessarily.
- Round 2 fixes (optional):
  - Added the mapping/revision resource-id equality predicate and a deliberately corrupt mapping regression test.
  - Scoped snapshots to current working-publication revisions and the selected project's delivery/learner rows while retaining global counts for insert detection.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
