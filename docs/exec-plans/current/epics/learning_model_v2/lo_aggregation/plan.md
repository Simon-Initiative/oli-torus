# MER-5821: Aggregate Child Learning Objective Proficiency into Parent Learning Objectives - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/learning_model_v2/lo_aggregation/prd.md`
- FDD: none. This work item intentionally skips a separate FDD (`harness-architect`). The
  technical design (function contract, `count` semantics per algorithm, call-site audit, and
  bucketing ownership) was resolved during PRD drafting and is captured directly in
  `prd.md` sections 2, 9, 13, and 14, and in `informal.md` in this same directory. This plan
  treats those sections as the design source of record in place of an `fdd.md`.
- Requirements: `docs/exec-plans/current/epics/learning_model_v2/lo_aggregation/requirements.yml`
  (FR-001 through FR-007, AC-001 through AC-010)

## Scope

Introduce a single, algorithm-agnostic weighted-aggregation function for parent Learning
Objective proficiency, and migrate the three audited runtime call sites (naive delivery-side
pooling, the Instructor Dashboard/CSV export authoring-side path, and the new
`"learning_objectives"` page element) onto it, so a parent LO's proficiency always reflects a
weighted combination of its Sub-LOs (and any directly-tagged evidence) instead of being
inconsistent or absent across surfaces. No timing change (stays a runtime projection), no LKT-AOA
implementation, no `learning_model_version` switch changes — those are explicit PRD non-goals.

## Clarifications & Default Assumptions

- The shared function's exact module and name are decided in Phase 1, not fixed in advance; the
  default assumption is that it lives near `Oli.Delivery.Metrics` (e.g. as a new function on
  `Metrics`, or a small new module it delegates to) since all three call sites already depend on
  `Metrics` today, and the PRD's Data/Interfaces section lists `Metrics.aggregate_raw_proficiency/1`
  as the closest existing analog to generalize from.
- Default assumption: the naive caller passes `num_first_attempts` as `count`; this is a firm
  requirement (PRD Assumptions), not a per-phase decision.
- Default assumption: bucketing is not part of the shared function. The naive caller continues
  calling `Metrics.proficiency_range/2` after aggregating. No phase below introduces a second
  bucketing implementation.
- Default assumption: `test/oli/delivery/sections_test.exs:3450-3498` is updated in place (not
  deleted) to assert the new aggregated behavior, since it is the test that currently documents
  the gap this work item closes.
- Clarification needed during Phase 3: whether `Sections.get_objectives_and_subobjectives/2`
  should call the shared function per-objective in a loop or extend its existing set-based query
  to fetch all Sub-LO evidence for a section in one pass and aggregate in memory. Default
  assumption: extend the existing set-based query (per PRD Non-Functional Requirements — this
  function already serves full-roster Instructor Dashboard reads and must not regress to N+1
  query behavior).

## Phase 1: Shared aggregation function

- Goal: Introduce the algorithm-agnostic weighted-aggregation function with its documented
  `count` contract, fully unit-tested in isolation, with no call site wired to it yet.
- Tasks:
  - [x] Decide the function's home module/name (default assumption above) and add it with the
    exact `@doc` text agreed in `prd.md` / `informal.md` (must be preserved verbatim, not
    rewritten). Implemented as `Oli.Delivery.Metrics.aggregate_weighted_proficiency/1`.
  - [x] Implement `score = Σ(proficiency_i × count_i) / Σ(count_i)` over a list of
    `(proficiency, count)` pairs, including a parent's own direct `(proficiency, count)` pair
    when present (FR-001).
  - [x] Handle a child with `count == 0` or unset/`nil` proficiency without excluding it from the
    aggregation's evidence accounting (FR-004) — it must still be representable so the caller can
    detect incomplete coverage, not silently vanish from the computation.
  - [x] Do not implement bucketing inside this function; it returns the weighted score (and total
    evidence count) only (FR-007, PRD Assumptions).
- Testing Tasks:
  - [x] ExUnit unit tests: multiple Sub-LOs with different counts (AC-001); parent with both
    direct evidence and Sub-LOs (AC-002); a Sub-LO with zero/insufficient evidence not silently
    dropped (AC-005); deterministic output for repeated calls with the same inputs (PRD
    Non-Functional Requirements).
  - Command(s): `mix test test/oli/delivery/metrics/aggregate_weighted_proficiency_test.exs`
- Definition of Done:
  - Function exists, is unit-tested per the cases above, and its `@doc` matches the agreed text
    exactly.
  - No existing call site has been modified yet.
- Gate:
  - `mix test` targeted at the new module passes; `mix format` clean.
- Dependencies:
  - None. This phase has no dependency on Phases 2-4.
- Parallelizable Work:
  - None within this phase; it is the prerequisite for Phases 2-4.

## Phase 2: Naive delivery-side integration (student prologue/lesson/review)

- Goal: Generalize `Metrics.aggregate_raw_proficiency/1` /
  `proficiency_for_student_per_learning_objective/3` to call the Phase 1 function instead of its
  own inline pooling, with no behavior change for existing sections (this call site already
  behaves like a weighted average today, so this phase is a refactor-in-place, not a functional
  change).
- Tasks:
  - [x] Replace the inline pooling logic in `aggregate_raw_proficiency/1`
    (`lib/oli/delivery/metrics.ex:804-823`) with a call to the Phase 1 shared function, passing
    `num_first_attempts` as `count` for each child (PRD Assumptions).
  - [x] Confirm `proficiency_for_student_per_learning_objective/3`
    (`lib/oli/delivery/metrics.ex:761-802`) still bucket via `proficiency_range/2` on the
    aggregated score (FR-007).
  - [x] Leave `raw_proficiency_per_learning_objective/2`'s SQL-embedded formula
    (`lib/oli/delivery/metrics.ex:1522-1546`) untouched in this phase; it feeds
    `proficiency_per_student_for_objective/3`, which Phase 3 addresses separately.
- Testing Tasks:
  - [x] Update/extend existing coverage in `test/oli/analytics/summary/metrics_v2_test.exs` for
    `aggregate_raw_proficiency/1` and `proficiency_for_student_per_learning_objective/3` to assert
    unchanged output for current fixtures, plus a new case covering a parent LO that has both its
    own directly-tagged evidence and a Sub-LO (AC-004; the double-counting outcome for this case
    was revised after Phase 4 — see the Post-Phase-4 Correction note below).
  - [x] Run the targeted `Phoenix.LiveViewTest` suites for `prologue_live_test.exs`,
    `lesson_live_test.exs`, and `review_live_test.exs` to confirm no visible regression
    (AC-007, AC-008).
  - Command(s): `mix test test/oli/analytics/summary/metrics_v2_test.exs test/oli_web/live/delivery/student/`
- Definition of Done:
  - `aggregate_raw_proficiency/1` and its caller delegate to the Phase 1 function.
  - Existing naive fixtures produce identical output to pre-change behavior.
- Gate:
  - Targeted `mix test` above passes; `mix format` clean.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Can run concurrently with Phase 3 and Phase 4 once Phase 1 is merged; none of the three call
    sites depend on each other.

## Phase 3: Instructor Dashboard / CSV export integration (the main gap)

- Goal: Make `Sections.get_objectives_and_subobjectives/2` actually combine a parent LO's Sub-LOs
  into its displayed/exported proficiency, closing the gap the ticket exists to fix, without
  regressing to per-learner or per-objective query loops.
- Tasks:
  - [x] Extend the query backing `get_objectives_and_subobjectives/2`
    (`lib/oli/delivery/sections.ex:5914-6185`) and/or
    `Metrics.proficiency_per_student_for_objective/3` (`lib/oli/delivery/metrics.ex:1509-1556`) to
    fetch each parent LO's own evidence and its Sub-LOs' evidence in the same set-based pass
    (resolve the Clarification above), then call the Phase 1 shared function per parent LO per
    student. Implemented via new `Metrics.raw_proficiency_per_student_for_objective/3` (raw,
    not-yet-bucketed extraction of the existing query); the bucketing helper was later relocated
    to the shared `Metrics.proficiency_bucket_for_student/3` (see the Post-Phase-4 Correction note
    below).
  - [ ] ~~Ensure double-counting prevention...~~ **NOT done — deliberately superseded after
    Phase 4**, see the Post-Phase-4 Correction note below. This task, as originally written, was
    initially implemented (exclusion of a parent's own evidence whenever it has Sub-LOs, mirroring
    `Metrics.proficiency_for_student_per_learning_objective/3`'s pre-existing 2024 behavior), then
    explicitly reversed: Darren Siegel confirmed on Slack (2026-09-01) that the parent's own
    evidence should always be combined with its Sub-LOs' evidence instead (FR-003, AC-004),
    accepting the resulting double-counting risk when an activity is tagged to both levels. Left
    unchecked because double-counting prevention is not what the shipped code does.
  - [x] Ensure a leaf LO (no `children`) takes the same path it does today and is unaffected
    (AC-008).
- Testing Tasks:
  - [x] Update `test/oli/delivery/sections_test.exs:3450-3498` (the test that currently asserts
    the un-aggregated behavior) to assert the new combined result using
    `setup_objectives_and_activities_test/0` (`test/oli/delivery/sections_test.exs:3711`)
    (AC-006).
  - [x] Add a case for a parent LO with one attempted Sub-LO and one unattempted/under-evidenced
    Sub-LO, asserting incomplete coverage is reflected rather than treated as fully attempted
    (AC-005).
  - [x] Run `Phoenix.LiveViewTest` coverage for `instructor_dashboard_live_test.exs` and
    `student_dashboard_live_test.exs`, and controller tests covering
    `delivery_controller.ex`'s `download_learning_objectives/2` CSV export (AC-006).
  - Command(s): `mix test test/oli/delivery/sections_test.exs test/oli_web/live/delivery/instructor_dashboard/ test/oli_web/live/delivery/student_dashboard/ test/oli_web/controllers/delivery_controller_test.exs`
- Definition of Done:
  - Instructor Dashboard tab, per-student instructor view, and CSV export all show a combined
    parent LO proficiency for sections with Sub-LO-only tagged evidence.
  - The previously-passing assertion of non-aggregated behavior is gone, replaced by an assertion
    of the new behavior.
- Gate:
  - Targeted `mix test` above passes; query plan/shape reviewed against PRD Non-Functional
    Requirements (no N+1 introduced); `mix format` clean.
- Dependencies:
  - Phase 1. Not dependent on Phase 2.
- Parallelizable Work:
  - Can run concurrently with Phase 2 and Phase 4 once Phase 1 is merged.

## Phase 4: Learning-objectives page element integration

- Goal: Make `PageElement.maybe_proficiency/5` combine Sub-LOs for the
  `"learning_objectives"` page element, consistent with Phases 2 and 3.
- Tasks:
  - [x] Update `maybe_proficiency/5`
    (`lib/oli/delivery/learning_objectives/page_element.ex:135-147`) to call the Phase 1 shared
    function (directly, or via whichever `Metrics`/`Sections` entry point Phase 2/3 expose) for
    LOs with `children`, instead of returning only the LO's own direct proficiency. Implemented
    as `maybe_proficiency/6` (gained an `objectives_with_children` param, shared with
    `do_included_objectives/3` to avoid a duplicate depot fetch), consuming two functions
    extracted from `Sections` into `Metrics` for reuse across all three call sites:
    `Metrics.evidence_resource_ids/2` and `Metrics.proficiency_bucket_for_student/3`.
  - [x] Confirm `lib/oli/rendering/content/learning_objectives.ex`'s `proficiency_for/2` still
    renders the same bucket labels it does today; no rendering change should be needed if the
    upstream data now already reflects the aggregated value. Confirmed unchanged; the module was
    not touched by this phase.
- Testing Tasks:
  - [x] Add/extend tests for `page_element.ex` covering a parent LO with Sub-LOs and no direct
    evidence (AC-007). Includes a case where the Sub-LO has no activity within the page
    element's own render scope, cross-checked directly against
    `Sections.get_objectives_and_subobjectives/2` for the same student/section.
  - [x] Run existing rendering tests for `learning_objectives.ex` to confirm no regression in
    label/bucket rendering.
  - Command(s): `mix test test/oli/delivery/learning_objectives/ test/oli/rendering/content/learning_objectives_test.exs`
- Definition of Done:
  - The page element shows a combined parent LO proficiency consistent with Phase 3's Instructor
    Dashboard value for the same student and section.
- Gate:
  - Targeted `mix test` above passes; `mix format` clean.
- Dependencies:
  - Phase 1. Not dependent on Phase 2 or Phase 3.
- Parallelizable Work:
  - Can run concurrently with Phase 2 and Phase 3 once Phase 1 is merged.

## Post-Phase-4 Correction: parent's own evidence is always combined, not excluded

After Phase 4 was implemented and committed, further review of the case where a parent LO has
Sub-LOs but neither the parent nor its Sub-LOs necessarily have overlapping evidence surfaced a
genuine open question the PRD/requirements.yml had not resolved precisely: should a parent LO's
own directly-tagged evidence ever be excluded from its aggregated proficiency, and if so, when?

Phases 2–4 as originally implemented answered this by excluding a parent's own evidence entirely
whenever it had any Sub-LOs (mirroring `Metrics.proficiency_for_student_per_learning_objective/3`'s
pre-existing 2024 behavior from ticket NG23-252). This avoided double-counting an activity tagged
to both a parent and a Sub-LO, but it also meant a parent with substantial, genuinely independent
direct evidence could show "Not enough data" indefinitely if its Sub-LOs were never tagged to any
activity — a real regression risk for existing course content, since a separate, already-filed
ticket will restrict this kind of parent-level tagging only for **new** courses going forward, not
retroactively.

Four alternatives (exact activity-level reconciliation, always combining, prefer-Sub-LOs-with-a-
fallback, and always-Sub-LOs-only) were compared, with worked numeric examples, in
`parent_evidence_aggregation_options.md` in this directory. **Darren Siegel confirmed on Slack
(2026-09-01)** that always combining a parent's own evidence with its Sub-LOs' evidence ("Option
B") is "the simplest thing that we can (and should) do" — explicitly accepting the resulting
double-counting risk when an activity happens to be tagged to both a parent and one of its
Sub-LOs, rather than building the more expensive exact-reconciliation approach or the fallback
approach. This decision supersedes the original Jira ticket's own AC that such an activity's
evidence must count only once, at the Sub-LO.

Retrofit applied across all phases already implemented:

- `Metrics.evidence_resource_ids/2` (introduced in Phase 4, shared by all three call sites) now
  unconditionally returns `[resource_id | children]` instead of excluding `resource_id` whenever
  `children` is non-empty.
- `Metrics.proficiency_for_student_per_learning_objective/3` (Phase 2's call site, and the
  pre-existing 2024 logic it was refactored from) now delegates to `evidence_resource_ids/2` as
  well, replacing its own separate `if rev.children == [] do ... else ... end` exclusion with the
  same always-combine rule — unifying all three call sites onto one shared implementation of this
  rule instead of two independent copies.
- `Sections.get_objectives_and_subobjectives/2` and `PageElement.maybe_proficiency/6` required no
  code changes themselves, since both already delegated to `Metrics.evidence_resource_ids/2`.
- Every test asserting the old exclusion behavior was recomputed and updated for the new combined
  result: `test/oli/analytics/summary/metrics_v2_test.exs`, `test/oli/delivery/sections_test.exs`
  ("filters by student_id when provided"), and
  `test/oli/delivery/learning_objectives/page_element_test.exs` (both the resource_ids-fetched
  assertion and the combined-proficiency assertion).
- `informal.md`, `prd.md`, and `requirements.yml` (FR-003/AC-004) were updated to describe the new
  rule and record the decision and its rationale.

No further phase renumbering was needed — Phase 5 (below) still applies to the corrected
implementation.

## Post-Correction Cleanup: consolidating the student-facing call site onto shared primitives

A branch-wide `/simplify`-style review (reuse, simplification, efficiency, altitude lenses)
surfaced that `Metrics.proficiency_for_student_per_learning_objective/3` (Phase 2's call site)
still used its own private raw-fetch/aggregate pair — `raw_proficiency_per_learning_objective/2`
plus `aggregate_raw_proficiency/1` and `naive_child_proficiency/2` — instead of the
`raw_proficiency_per_student_for_objective/3` + `evidence_resource_ids/2` +
`proficiency_bucket_for_student/3` pipeline the Instructor Dashboard and page element call sites
already shared. This was accumulated phasing debt (Phase 2 predates the cleaner primitives Phase 3
introduced), not a deliberate design choice, and duplicated the naive proficiency formula
byte-for-byte in both Elixir and SQL.

`proficiency_for_student_per_learning_objective/3` was refactored to call
`raw_proficiency_per_student_for_objective/3` and `proficiency_bucket_for_student/3` directly, and
the now-fully-unused private helpers `aggregate_raw_proficiency/1` and `naive_child_proficiency/2`
were deleted. `raw_proficiency_per_learning_objective/2` itself was **not** removed — it remains a
public function used independently by `Oli.Scenarios.Directives.Assert.ProficiencyAssertion` and
covered by its own dedicated test in `metrics_v2_test.exs`, outside this ticket's scope. Verified
mathematically equivalent (every objective-type `ResourceSummary` row uses a fixed `part_id`, so
`GROUP BY`+`SUM` over that one row equals reading it directly) and confirmed by the full existing
test suite plus the `Oli.Scenarios` suite (which exercises `raw_proficiency_per_learning_objective/2`
via the assertion directive above) — no test changes were required for this refactor.

Also fixed in the same pass: a genuinely dead `aggregate_raw_proficiency([])` clause (the general
clause already produced the identical result), an unnecessary defensive `List.wrap/1` in
`page_element.ex` (the depot always normalizes `children` to a list, never `nil`), and this file's
own stale reference to `Sections.aggregated_proficiency_bucket/3` (see the Phase 3 task note
above, corrected to point at its final home).

## Phase 5: Cross-cutting verification, review, and closeout

- Goal: Confirm the three integrated call sites agree with each other, run full regression, and
  close out review/requirements/issue-tracking obligations before this work item is considered
  done.
- Tasks:
  - [ ] Manual QA per PRD QA Plan: for one section fixture with a parent LO with Sub-LOs and no
    direct evidence, confirm the Instructor Dashboard tab, its CSV export, the per-student
    instructor view, and student prologue/lesson/review views all show the same combined value
    for the same student; confirm a leaf LO is unchanged. **Also** cover the scenario that
    actually changed behavior under the Post-Phase-4 Correction (Option B): a parent LO that has
    *both* its own directly-tagged evidence *and* a Sub-LO with evidence — confirm all four
    surfaces show the same combined value (not the parent's own value alone, and not "not enough
    data"). The "no direct evidence" scenario alone behaves identically whether or not the
    parent's own evidence is combined, so it does not exercise Option B on its own.
  - [ ] Update Jira `MER-5821` with implementation notes/status per `docs/ISSUE_TRACKING.md`.
  - [ ] Run code review per `docs/CODEREVIEW.md`: `.review/security.md` and `.review/performance.md`
    always; `.review/elixir.md` (backend Elixir/Ecto/LiveView changes) and `.review/requirements.md`
    (this PRD's traceability) since both apply to this work item; `.review/ui.md` and
    `.review/typescript.md` are not expected to apply (no frontend/TypeScript changes).
- Testing Tasks:
  - [ ] Run the full affected-area suite: `mix test test/oli/delivery/ test/oli/analytics/summary/ test/oli_web/live/delivery/ test/oli_web/controllers/delivery_controller_test.exs`.
  - [ ] Run `mix format --check-formatted` across all touched files.
  - Command(s): `mix test test/oli/delivery/ test/oli/analytics/summary/ test/oli_web/live/delivery/ test/oli_web/controllers/delivery_controller_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - All PRD acceptance criteria (AC-001 through AC-010) are demonstrably satisfied by passing
    automated tests plus the manual QA above.
  - Code review findings from the applicable `.review/` guides are resolved or explicitly
    accepted.
- Gate:
  - Full targeted test run above is green; code review has no unresolved findings.
- Dependencies:
  - Phases 2, 3, and 4 all complete.
- Parallelizable Work:
  - None; this phase is the closeout gate after Phases 2-4 converge.

## Parallelization Notes

- Phase 1 is a strict prerequisite for everything else and should be done first, alone.
- Phases 2, 3, and 4 touch three independent call sites (naive delivery-side pooling, the
  Instructor Dashboard/Sections path, and the page element) with no code overlap between them, and
  can be implemented in parallel once Phase 1 is merged.
- Phase 3 is the largest and most product-visible phase (it is the gap the ticket exists to
  close) and should not be blocked on Phases 2 or 4 finishing first.
- Phase 5 must wait for all of Phases 2-4 to land, since its cross-site consistency check requires
  all three surfaces to already reflect the new aggregation.

## Phase Gate Summary

- Gate A (end of Phase 1): shared aggregation function exists, is unit-tested, and its `@doc`
  contract is final.
- Gate B (end of Phases 2-4, in any order): each of the three call sites independently passes its
  own targeted tests and shows the aggregated value in its own surface.
- Gate C (end of Phase 5): cross-site consistency confirmed manually, full regression suite green,
  applicable code review guides clean, Jira `MER-5821` updated.
