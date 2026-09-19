# Linked Activities Details From Learning Objectives - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/lo_analytics/linked_activities/prd.md`
- FDD: `docs/exec-plans/current/epics/lo_analytics/linked_activities/fdd.md`
- Traceability: `docs/exec-plans/current/epics/lo_analytics/linked_activities/requirements.yml`

## Scope
Complete the existing Learning Objective Linked Activities LiveView with depot-backed parent/sub-objective activity resolution, one-row-per-activity aggregation across page contexts, shared expandable instructor details, three-column linked-mode rendering, activity filters/sorting/pagination, accessible interactions, and bounded telemetry.

Guardrails:

- Keep the existing route, authorization boundary, publication/section scope, and back-parameter behavior.
- Do not change activity tagging, post-processing, analytics schemas, student delivery, or existing Scored Activities/Practice Activities behavior.
- Do not add a migration or feature flag. All writes are out of scope; this page is read-only.
- Use existing depot and summary infrastructure; do not introduce request-time scans of activity revision objective JSONB or per-row summary queries.

## Clarifications & Default Assumptions
- A parent objective includes its effective descendants; a selected child includes only that child.
- A linked activity resource appears once, with aggregate attempts/correctness across eligible in-scope page occurrences.
- The first eligible page in stable depot/display order is the canonical page context for preview presentation when an activity occurs on multiple pages.
- Linked mode shows exactly `Question Stem`, `Attempts`, and `% Correct` plus the expansion control; the order and Learning Objectives columns remain available in the existing default mode.
- All rows start collapsed after initial load and after filter, sort, pagination, or navigation changes.
- `related_activities` is assumed to be maintained by existing post-processing. Stale or absent data produces safe empty states rather than synchronous repair.
- Product/design follow-ups about occurrence-level rows or telemetry naming do not block this plan unless they change AC-006 or the row contract.
- The filter toolbar was aligned to the approved design as a separate pass using the repo-local `ui_workflow` skill, not as a numbered phase of this plan. Scope was the toolbar only: `SearchInput.render`, `MultiSelect.render` for Attempts, `PercentageSelector.render` for Score with the percentage inside the dropdown, and Clear All Filters with `Icons.trash`, all reusing the components already used by `pages.ex` with no new styles. Explicitly out of scope and unchanged: the expanded detail chrome, which is the component shared with Scored and Practice Activities and whose divergence from the design predates this work item. Its runtime artifacts live outside the repository under the `ui_workflow` scope directory, so this note is the in-repo record. Traceability is AC-022.
- Moving the linked route onto the shared table changed how `% Correct` is formatted, from one decimal place to a whole number (`100.0%` became `100%`), because the shared column renders a 0-1 ratio. This is accepted as the cost of matching Scored and Practice Activities, and existing tests were updated to it. Flag it to design only if the decimal is required.

## As-Built Status

Phases 1 through 6 are implemented and recorded in their execution records. The authoritative implementation differs from some task prose below in these ways:

- `Oli.Delivery.Sections.LinkedActivities` is the production resolver and the legacy `Sections.get_activities_for_objective/2` path is retired.
- `OliWeb.Delivery.ActivityInsightsState` is the shared pure state projection; the route and `Pages` LiveViews keep their existing event boundaries rather than introducing a separate `ActivityInsightsTable` component.
- `ActivitiesTableModel` supports `:linked_activities` mode and renders the shared details, accessible expansion state, and linked columns.
- Cross-page aggregation, the real authoring/delivery scenario, and the phase 6 acceptance-criteria tests are complete.
- Browser/Figma QA remains blocked until an authenticated instructor Browser MCP session is prepared. This is the only release-readiness item not automated in this work item.

## Phase 1: Define and Test the Data Contracts
- Goal: establish deterministic objective-family resolution, page-context indexing, row normalization, and aggregation contracts before changing LiveView behavior.
- Tasks:
  - [x] Add the focused delivery helper/service for resolving the selected objective plus effective descendants from `SectionResourceDepot`.
  - [x] Batch-fetch objective section resources, union direct `related_activities`, preserve stable ordering, and de-duplicate resource IDs.
  - [x] Add page traversal/context indexing for eligible delivered pages and unique activity IDs, including deterministic canonical context selection.
  - [x] Define normalized linked-row fields for title/content/revision, attempts, average score, resource ID, page contexts, and LTI metadata.
  - [x] Define summary merge behavior: add counts and recompute ratios from numerators/denominators; preserve zero/empty values.
  - [x] Add bounded telemetry event names/metadata contracts for linked load and grouped summary load.
  - [x] Retire `Sections.get_activities_for_objective/2` together with its private helpers `calculate_all_activity_metrics/2` and `extract_question_stem/1` in `lib/oli/delivery/sections.ex`. The new resolver replaces it; its only consumer is `related_activities_live.ex`, which Phase 4 rewrites. Leaving it in place would strand roughly ninety lines of dead code guarded by passing tests.
- Testing Tasks:
  - [x] Unit-test direct, parent-plus-child, child-only, duplicate, unrelated, empty, missing-context, and stable-order cases.
  - [x] Unit-test multi-page context indexing and merged correctness/attempt totals, including zero denominators.
  - [x] Unit-test linked/default row normalization and allow-listed sort/filter field mapping.
  - [x] Migrate, do not delete, the eight tests in the `get_activities_for_objective/2` describe block of `test/oli/delivery/sections_test.exs`. Re-point them at the new resolver, keeping their existing cases: single-activity objective, multi-activity objective, mixed graded and practice pages, sub-objective, non-existent objective, activity with no question stem, zero-attempt activities, and attempts/percent-correct accuracy. Extend the sub-objective case so a parent objective also includes its children's activities, per AC-002.
  - Command(s): `mix test test/oli/delivery test/oli_web/components/delivery` (target the new modules/tests first)
- Definition of Done:
  - The resolver returns only unique, section-scoped IDs and page contexts without database writes or revision-objective scans.
  - `Sections.get_activities_for_objective/2` and its private helpers no longer exist, no caller references them, and their test coverage lives with the new resolver.
  - Contract tests cover AC-002, AC-003, AC-006, AC-014, and the data portions of AC-015.
- Gate:
  - New unit tests pass; design review confirms the resolver uses depot batch APIs and exposes no mutable authoring data; a repository-wide search confirms no remaining references to the retired function or its helpers.
- Dependencies:
  - PRD, FDD, existing `SectionResourceDepot`, section resource, and analytics summary contracts.
- Parallelizable Work:
  - Telemetry metadata tests and row normalization tests can proceed independently after the contract shape is agreed.

## Phase 2: Extract the Shared Activity Detail Lifecycle
- Goal: make expansion, lazy loading, caching, adaptive repair, and detail rendering reusable without changing current dashboard behavior.
- Tasks:
  - [x] Repoint `lib/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live.ex` to `Oli.Delivery.Sections.LinkedActivities.get_activities_for_objective/2`; the route now uses the resolver's objective-family and aggregation contract.
  - [x] Extract the generic activity-insights state currently held in `Pages`. Only the pure state projections moved to `OliWeb.Delivery.ActivityInsightsState`: initial state, reset, expanded-row IDs, and the loaded check. Lazy summary loading and adaptive repair polling stayed with each LiveView, because the two use different strategies: `Pages` pre-loads every activity on the selected page in one call, while the linked route loads per activity on expansion since its activities span several pages. Unifying them requires first deciding which strategy wins, which is tracked as follow-up rather than done here.
  - [x] Resolve `has_lti_activity` from the activity revision instead of a hardcoded `false`; `normalize_activity_row/4` now derives it from the registered LTI activity type IDs.
  - [x] Refactor `ActivitiesTableModel` to accept a small mode/options contract while preserving its current default columns and events. `new/2` takes `:columns` and resolves the specs through `column_specs_for/1`, which raises on an unknown mode instead of silently falling back to the default columns.
  - [x] Add linked mode that hides order and Learning Objectives columns while retaining the chevron, question, attempts, and score columns.
  - [x] Keep `ActivityHelpers` and `render_assessment_details/2` as the source for question, answer key, hints, explanation, dynamic variables, distribution, first-try, and eventual-correct details.
  - [x] Retire `RelatedActivitiesTableModel`; the route uses the shared `ActivitiesTableModel` linked mode.
- Testing Tasks:
  - [x] Add component/model tests for linked versus default column sets and detail-row rendering. `aria-expanded` is asserted in the linked route LiveView test rather than at the component level, since the attribute depends on expansion state the table model only receives from a live socket.
  - [x] Complete the Phase 1 contract coverage that was not written: child-only objective scope, unrelated activity exclusion, empty relationship arrays, a page resource whose revision is missing from `build_page_contexts/2`, zero-denominator ratios in `merge_summary_metrics/1`, and `normalize_activity_row/4` field/scale mapping.
  - [x] Run existing Scored Activities, Practice Activities, and Survey tests to detect regressions in the default table path.
  - Command(s): `mix test test/oli_web/components/delivery/pages test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Existing dashboard views render unchanged with default options.
  - Linked mode supports collapsed initial state, lazy cache reads, re-expansion, loading, and no-analytics empty states.
  - Contract tests cover AC-004, AC-005, AC-016, AC-017, and AC-020 for the `Pages` path. Both callers merge `expanded_activity_ids` into the table model data themselves, and `ActivitiesTableModel.render_expanded/3` reads it to emit `aria-expanded`. At the end of this phase the linked route did not yet pass that state through, so the attribute rendered as a constant `false` there; Phase 4 completed AC-016 and AC-017 for that route.
- Gate:
  - Existing activity dashboard tests pass and the shared boundary review confirms no duplicated question-detail renderer remains.
- Dependencies:
  - Phase 1 normalized row and summary contracts.
- Parallelizable Work:
  - Default/linked column model tests and accessibility assertions can be developed alongside the state extraction, then integrated at the gate.

## Phase 3: Implement Cross-Page Summary Loading
- Goal: connect unique linked rows to page-scoped `ActivityHelpers` calls and produce consistent aggregate row/detail metrics.
- Tasks:
  - [x] Group linked activity IDs by containing page context and call `summarize_activity_performance/6` once per page group, never once per row. Superseded after implementation review: table metrics are read once per activity from the section-scoped `ResourceSummary`, and page grouping remains only for the expanded detail path. See the decision log in `fdd.md`.
  - [x] Merge resource/response summaries and correctness metrics by activity resource ID, preserving activity-specific staged detail payloads and canonical preview context.
  - [x] Convert explicitly between score scales when wiring `merge_summary_metrics/1` into `normalize_activity_row/3`. `merge_summary_metrics/1` returns `avg_score` as a 0-1 ratio, while `normalize_activity_row/3` treats its incoming score as a 0-100 percentage and then divides by 100. Feeding one into the other through the current `:percent_correct -> :avg_score` fallback yields values that are wrong by a factor of one hundred. Remove that silent fallback and pass the scale explicitly.
  - [x] Narrow the page-revision load in `LinkedActivities.resolve_context/2`. It currently loads every non-hidden lesson revision in the section, including full `content`, on each call, and Phase 1 discards the result. Build the activity-to-page index from a narrow select (`id`, `resource_id`, `activity_refs`, `graded`) and load the complete revision only for the canonical page of a row being expanded. The full revision is still required at that point because `ActivityHelpers.build_ordinal_mapping/1` walks `revision.content` and `AdaptiveIFrame.screen_preview/3` needs the whole revision, so do not narrow the revision handed to `summarize_activity_performance/6`.
  - [x] Handle missing revisions, missing page contexts, zero attempts, helper failures, and adaptive summary repair without crashing the LiveView.
  - [x] Ensure enrolled student scope matches existing instructor dashboard behavior and excludes raw response/PII data from new assigns and telemetry.
  - [x] Instrument duration, group/row counts, cache outcomes, empty-summary counts, and bounded error classes.
- Testing Tasks:
  - [x] Test one-page and multi-page summaries, additive counts, recomputed ratios, canonical context selection, missing context, and no-attempt states.
  - [x] Test telemetry event payloads contain bounded operational fields and exclude emails, raw responses, authored content, and arbitrary query strings.
  - [x] Verify summary loading and expansion do not insert/update/delete revisions, attempts, responses, or summary rows.
  - Command(s): `mix test test/oli/analytics test/oli_web/components/delivery/activity_helpers_test.exs test/oli_web/components/delivery/pages`
- Definition of Done:
  - Detail summaries match the established activity dashboard payload, and table metrics report section-scoped totals once per activity.
  - Contract tests cover AC-004 through AC-006, AC-012, AC-013, and AC-015.
- Gate:
  - Summary merge tests pass and a query/log review confirms grouped calls, section scoping, and no source-data mutation.
- Dependencies:
  - Phase 1 context/index contracts and Phase 2 shared lifecycle.
- Parallelizable Work:
  - Telemetry assertions and read-only snapshot tests can proceed while summary grouping is implemented.

## Phase 4: Integrate the Linked Activities LiveView
- Goal: replace the shallow route implementation with the shared activity-insights experience and preserve all navigation/control semantics.
- Tasks:
  - [x] Load the complete page revision for an activity's canonical page context before calling `ActivityHelpers.summarize_activity_performance/6`. Phase 3 narrowed the page-revision select to `id`, `resource_id`, `activity_refs`, and `graded`, which is correct for building the index but insufficient for the detail path: `ActivityHelpers.build_ordinal_mapping/1` walks `revision.content` and `AdaptiveIFrame.screen_preview/3` needs the whole revision, so expanding a row against the narrow map raises. Nothing fails today because `activity_metrics/3` only reads `page_id`. Do this before wiring expansion.
  - [x] Update `RelatedActivitiesLive` to resolve linked activity context from the depot and pass normalized rows/contexts into the shared boundary.
  - [x] Retain selected objective title, existing route, authorization, redirect behavior, and encoded `back_params` navigation.
  - [x] Add Search, Attempts, Score, Clear All Filters, sortable question/attempts/score headers, and pagination using existing parameter semantics.
  - [x] Fix the linked sort contract so `title`, `total_attempts`, and `avg_score` headers map to the allow-listed route sort fields and update their indicators. This is AC-010.
  - [x] Apply filters before sorting/pagination, reset offset on filter changes, preserve active parameters across page changes, and allow-list all parsed atoms.
  - [x] Pass `expanded_activity_ids` into the linked route's table model data so `aria-expanded` reflects the real expansion state rather than rendering a constant `false`. This completes AC-016 and AC-017 for this route.
  - [x] Render distinct no-linked-activities and no-filter-match states; keep all rows collapsed on initial and changed contexts.
  - [x] Remove shallow route-specific rendering and wire linked table mode with the shared details render function.
  - [x] Replace the bare `rescue _ -> socket` at the end of `RelatedActivitiesLive.maybe_load_activity_summary/2`. It currently swallows every exception in the summary-load path with no log and no state change, so a failing expansion leaves the row spinning forever and hides exactly the page-context and score-scale defects this work item has been correcting. Log bounded context and cache the existing empty summary so the row stays usable, per FDD section 10.
  - [x] Use the `canonical_page_context` map produced by `LinkedActivities.resolve_context/2` instead of `List.first(activity.page_contexts)`. The two agree today, but the hand-rolled pick bypasses the documented canonical selection and will diverge if that rule changes.
  - [x] Remove the silent `:percent_correct -> :avg_score` fallback still present in `LinkedActivities.normalize_activity_row/4`. Phase 3 added the explicit conversion in `activity_metrics/3`, so the fallback is now unreachable but still misleading.
  - [x] Resolve `LinkedActivities.merge_summary_metrics/1`, which became dead code when Phase 3 implemented aggregation inline in `activity_metrics/3`. Either use it as the single merge path or retire it with its tests. Leaving it in place keeps a function that emits `avg_score` as a 0-1 ratio next to a normalizer that expects 0-100, which is the exact confusion the scale contract in FDD 4.4 exists to prevent.
  - [x] Correct the `page_context` typespec. It still declares `page_revision: Revision.t()` while the value is now a four-field map.
- Testing Tasks:
  - [x] Extend `test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs` for route/back navigation, parent/child scope, de-duplication, unrelated exclusion, search, Attempts, Score, clear, sorting, pagination, expansion, collapse/re-expansion, and empty states.
  - [x] Click each of the three sortable headers and assert the row order actually changes for question stem, attempts, and `% Correct`, in both directions. No existing test exercises header sorting on this route, which is why the Phase 2 sort regression went undetected. Covers AC-010.
  - [x] Write the filter and Clear All Filters assertions against behavior, meaning the resulting params and the rows that survive, rather than against the current `<select>` and `<input>` markup. The filter controls are replaced in the UI alignment phase, and behavior-level assertions survive that change instead of needing to be rewritten.
  - [x] Expand a row and assert the shared detail content renders: Question, Answer Key, Hints, Explanation, Dynamic Variables where applicable, the answer distribution, First Try Correct, and Eventually Correct. Then collapse and re-expand the same row, and expand an activity with no question-level analytics and assert the established empty state. The route currently has no test that expands anything, which is the central behavior of this ticket. Covers AC-004 and AC-005.
  - [x] Assert no row is expanded on initial load, and that none becomes expanded after filtering, sorting, or paging. Covers AC-020.
  - [x] Assert `aria-expanded` tracks real expansion state on the chevron and that the control exposes an accessible name. Covers AC-016 and AC-019.
  - [x] Assert pagination limits rows to the page size and preserves the active search, filters, and sort across page changes. Covers AC-021.
  - [x] Add authorization tests for unauthenticated, non-enrolled, and cross-section objective/activity access.
  - [x] Add HTML assertions for exactly the linked columns, required detail labels, collapsed initial rows, accessible names/states, and visible focus hooks/classes.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs`
- Definition of Done:
  - The existing route provides the complete linked activity workflow and all linked activity requirements are represented in automated coverage.
  - Contract tests cover AC-001 through AC-013 and AC-016 through AC-021. This claim was not true at the first pass of this phase: the route had eleven tests covering authorization, listing, search, attempt and score filters, back navigation, and sub-objective scope, and zero tests for expansion, detail content, header sorting, Clear All Filters, pagination, or `aria-expanded`. The phase is not done until every AC listed here has a test that exercises it.
- Gate:
  - Targeted LiveView suite passes; manual keyboard/responsive verification confirms controls and expansion behavior; no unrelated activity dashboard regression is observed.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Test fixture expansion for parent/child/duplicate/multi-page cases can proceed while the LiveView wiring is implemented.

## Phase 5: Verification, Review, and Release Readiness
- Goal: prove the complete work item against repository gates and operational guardrails.
- Tasks:
  - [x] Run formatter and targeted backend tests; inspect query counts/log output for linked-load and summary-load paths.
  - [x] Pass `disabled={@selected_attempts_ids == %{}}` to `MultiSelect.render` on the linked route. `pages.ex` passes it for Scored and Practice Activities and the linked toolbar omits it, so the control's disabled state diverges from the shared behavior.
  - [ ] Perform manual instructor-flow verification with parent, child, duplicate, unrelated, zero-attempt, multi-page, and filtered datasets.
  - [x] Decide whether `LinkedActivities.activity_attempt_fallback/2` is a production requirement or a test-fixture workaround. It was introduced in Phase 3 so activities with evaluated attempts but no summary rows stay visible, and it adds a third query path plus a `ResourceSummary` query using the magic constants `project_id == -1 and user_id == -1`. If it stays, route it through the existing accessor in `Oli.Analytics.Summary` instead of duplicating that query here.
  - [x] Stop recomputing the page grouping inside the summary-load telemetry metadata. `activity_page_groups/2` was later removed altogether and the page-context count moved to the `load` event. Document that `normalize_activity_row/3` calls `Activities.list_lti_activity_registrations()` internally and must not be used per row; production code should use the arity-4 form with precomputed IDs.
  - [x] Complete security, performance, Elixir/Phoenix, UI/accessibility, and requirements reviews.
  - [ ] Update Jira execution status/artifacts according to repository issue-tracking policy.
  - [x] Populate the `proofs` entries in `requirements.yml`, matching the convention used by the `lo_element` work item. Note that `requirements_trace.py --action verify_implementation` reads the top-level `acceptance_criteria` list, which is empty here because every criterion is nested under its functional requirement, so that gate passes without checking anything for this work item.
  - [x] Confirm no migration, feature flag, or rollout configuration is required and document any product decision that changes AC-006.
- Testing Tasks:
  - [x] Run the complete targeted LiveView/component/domain suites and broader `mix test` as risk/time permits.
  - [x] Close the test gaps left open at the end of Phase 4. Assert the expanded detail CONTENT, not only that a detail row exists: the current test checks for `#details-row_<id>` and nothing inside it, so a row that expands to an empty container passes, and since the summary-load rescue now caches an empty summary on failure the test cannot tell a successful load from a silent fallback. Assert Answer Key, Hints, Explanation, Dynamic Variables where applicable, the answer distribution, First Try Correct, and Eventually Correct. Covers AC-004. Completed in Phase 6.
  - [x] Assert header sorting for `title` and `total_attempts`. Only `avg_score` is exercised today, in both directions; the other two headers have no coverage. Covers AC-010. Completed in Phase 6.
  - [x] Assert that an activity with no question-level analytics expands to the established empty state. Covers AC-005. Completed in Phase 6.
  - [x] Assert the expansion control exposes an accessible name. `aria-expanded` and `aria-controls` are asserted; the accessible name is not. Covers AC-019. Completed in Phase 6.
  - [x] Assert rows stay collapsed after filtering, sorting, and paging, not only on initial load. Covers AC-020. Completed in Phase 6.
  - [x] Verify AC-022 manually against the approved design and record the result.
  - [x] Run `mix format --check-formatted` and harness plan/requirements validation.
  - [x] Verify manual keyboard focus, responsive layout, loading/error/empty states, and no mutation of source analytics data.
  - Command(s): `mix test`, `mix format --check-formatted`, `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/lo_analytics/linked_activities --action master_validate --stage implementation_complete` (resolve `<skills_root>` to the local harness skills installation; do not hardcode a user home path in a committed artifact)
- Definition of Done:
  - All automated and manual checks pass, review findings are resolved or explicitly tracked, telemetry is privacy-safe, and the linked route is ready for normal deployment.
- Gate:
  - CI-equivalent tests, formatting, requirements traceability, code reviews, and release checklist all pass.
- Dependencies:
  - Phases 1 through 4 complete.
- Parallelizable Work:
  - Security/performance reviews and manual accessibility verification can run in parallel after the integration tests pass.

## Phase 6: Close the Acceptance Criteria Test Gaps
- Goal: give every acceptance criterion that currently has no test an automated test that exercises it. This phase contains no production code changes on purpose. The equivalent testing tasks were attached to Phase 4 and Phase 5, which also carried code tasks, and were not completed in either pass.
- Tasks:
  - [x] None. Do not change production code in this phase. If a test cannot be written without a production change, stop and report it instead of making the change.
- Testing Tasks:
  - [x] Assert expanded detail content including Answer Key, Hints, Explanation, Dynamic Variables, answer distribution, First Try Correct, and Eventually Correct. Covers AC-004.
  - [x] Assert header sorting for `title` and `total_attempts` in both directions. Covers AC-010.
  - [x] Assert that an activity with no question-level analytics expands to the established empty state. Covers AC-005.
  - [x] Assert the expansion control exposes an accessible name and tracks `aria-expanded`/`aria-controls`. Covers AC-019.
  - [x] Assert rows stay collapsed after filtering, sorting, and paging. Covers AC-020.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs`
- Definition of Done:
  - Each of AC-004, AC-005, AC-010, AC-019, and AC-020 has at least one test that fails if the behavior regresses. A test that only asserts an element's presence does not satisfy this.
  - No production file is modified by this phase.
- Gate:
  - The linked route suite passes, and the broader instructor dashboard, delivery component, and sections suites show no regression.
- Dependencies:
  - Phases 1 through 5 complete.
- Parallelizable Work:
  - The five assertions are independent and can be written in any order.

## Work Executed Outside the Phase Sequence
Two verification activities are executed with repo-local skills rather than `harness-develop`, because each has its own contract. This section is their in-repo record.

- Scenario coverage, authored with `build_scenario` as `Oli.Scenarios` YAML plus an ExUnit runner. Target behavior: one realistic course workflow that produces a parent objective with sub-objectives, activities attached at both levels including one attached to both, at least one activity placed on two pages, at least one activity with no attempts, and activities outside the objective family. Assertions cover the unique linked activity set for a parent and for a child, single-row de-duplication, exclusion of unrelated activities, and aggregate attempts and correctness for the multi-page activity. This is the only path that exercises the Phase 3 cross-page aggregation against real data rather than hand-built rows.
- Visual and interaction QA, executed with `ui_workflow` in `qa` mode against the approved design. Covers layout and visual comparison, keyboard focus order and visible focus, and responsive behavior. Requires an authenticated instructor browser session prepared by a person; it cannot be produced by the skill.

## Parallelization Notes
- Phase 1 is the critical foundation. Contract tests, telemetry schema checks, and row normalization are safe parallel tasks after the proposed return shapes are approved.
- Phase 2 and Phase 3 are sequential at the shared-state boundary, but their test writing can overlap once interfaces are stable.
- Phase 4 fixture/test preparation can run concurrently with Phase 3 implementation; route integration waits for the shared lifecycle and summary contract.
- Phase 5 review tracks may run concurrently, but final completion waits for all automated tests and review findings.

## Phase Gate Summary
- Gate A: depot-backed resolver and deterministic aggregation contracts pass unit tests.
- Gate B: shared table/detail extraction passes existing dashboard regression tests.
- Gate C: grouped page-context summaries pass merge, failure, privacy, and read-only tests.
- Gate D: linked route passes complete LiveView workflow, authorization, accessibility, and empty-state tests.
- Gate E: formatting, broader tests, requirements traceability, operational checks, and required reviews pass.
- Gate F: every acceptance criterion listed in Phase 6 has a test that exercises it, and the real scenario coverage is complete. Visual QA is recorded as attempted but blocked pending an authenticated Browser MCP session.

## Decision Log

### 2026-09-05 - Reconcile Plan With Execution Records
- Change: Added the as-built status and corrected the final gate to distinguish completed automated/scenario coverage from blocked browser/Figma QA.
- Reason: The implementation and phase records are complete, while several original task descriptions still describe pre-implementation code and tentative component names.
- Evidence: `phase_1_execution_record.md` through `phase_6_execution_record.md`, `test/scenarios/linked_activities/`, and the UI workflow runtime record under `~/.codex/memories/oli-torus-ng/ui-work/MER-5811/`.
- Impact: The plan now reflects the actual architecture and release gate without altering historical phase task prose.
