# Instructor Expanded LO Visualization - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/lo_analytics/instructor_viz/prd.md`
- FDD: `docs/exec-plans/current/epics/lo_analytics/instructor_viz/fdd.md`
- UI Brief: `docs/exec-plans/current/epics/lo_analytics/instructor_viz/design/instructor_viz_ui_brief.md`
- Requirements: `docs/exec-plans/current/epics/lo_analytics/instructor_viz/requirements.yml` (FR-001..FR-011, AC-001..AC-036)
- Jira: MER-5814

## Scope

Replace the current one-dimensional expanded Learning Objective visualization
(`DotDistributionChart` + `StudentProficiencyList`/`StudentProficiencyTableModel`) with a
two-dimensional, pure-HEEx/SVG Student Distribution matrix and a group-based student table, per
`fdd.md`. No feature flag.

Delivery is sequenced as **three PRs**, each landing on `master` independently:

1. Chart only (HEEx matrix replaces the old chart; selection event is a no-op beyond storing state).
2. Read-only student table, populated by the chart's selection.
3. Selection checkboxes, Email button, and the shared `StudentSelection` extraction.

This order deliberately de-risks the newest technical bet (a pure-HEEx 2D matrix, no charting
library, no React) before building the rest of the feature on top of it. Under this team's
release-cut model, `master` does not imply production — a release only ships what was on `master` at
cut time — so it is acceptable for PR1 and PR2 to individually leave the feature functionally
incomplete on `master`, as long as **all three PRs land before the next release cut**. Track that
cut date once known and treat it as a hard dependency for PR3.

Out of scope (per `prd.md` Non-Goals): proficiency computation itself, the sub-objectives table below
the expanded row, a new activity-completion signal beyond the existing attempted-activity proxy, and
responsive/mobile layout.

## Clarifications & Default Assumptions

Carried from `prd.md`/`fdd.md`, restated here because they affect what gets built and in which PR:

- Group split uses continuous proficiency score vs. 50%, not the Low/Medium/High display label.
  Implemented in PR1.
- The matrix has exactly three selectable regions (Needs Support, Excelling, Limited Activity), not
  four — the two lower quadrants are one merged Limited Activity hit-region. Implemented in PR1.
- `total_related_activities == 0` => 0% activity completion => Limited Activity. Implemented in PR1.
- Activity Completion = `activities_attempted_count / total_linked_activity_count` (existing
  attempted-at-least-once proxy). No new signal is built in this plan.
- "Not enough data" proficiency + high activity completion is provisionally classified as Needs
  Support (`fdd.md` section 2, flagged as the highest-uncertainty rule). Implemented in PR1 with a
  named constant/guard so it is trivially findable and changeable if product overrides this default.
- Exactly-50% boundaries are inclusive on the "high"/"excelling" side (`>= 50%`). Implemented in PR1.
- The chart is pure HEEx/SVG, not React — see `fdd.md` section 4.4 for why. Implemented in PR1.
- Load More is client-side pagination over an already-loaded, already-filtered list; no new server
  query shape. Implemented in PR2.
- The per-group proficiency filter exposes the same four options (Not Enough Info / Low / Medium /
  High) in all three groups for implementation simplicity, pending the open question in `fdd.md`
  section 16. Implemented in PR2.
- The new table's checkbox column uses a native `<input type="checkbox">`, not
  `StudentSupportTile`'s custom button pattern, pending the Figma checkbox-visual confirmation in
  `fdd.md` section 16. Implemented in PR3.
- The `StudentSelection` extraction touches `StudentSupportTile` (an unrelated, live MER-5252
  feature) as a pure internal refactor with no behavior change. Implemented in PR3.

## Phase 1 (PR1): Chart Only — HEEx Student Distribution Matrix

- Goal: replace `DotDistributionChart` with the new HEEx/SVG matrix. Selecting a region updates
  server state and nothing else renders differently yet — this PR exists to validate the HEEx-chart
  approach in production before building the table on top of it.
- Tasks:
  - [ ] Add `linked_activity_ids_for_objective/2` to `ExpandedObjectiveView`
        (`lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`), using
        `SectionResourceDepot.objectives_with_effective_children_for/2` +
        `SectionResourceDepot.get_resources_by_ids/2` (`fdd.md` section 4.2 code sketch).
  - [ ] Replace the single-objective lookup inside `add_missing_students_to_proficiency_data/4` with
        a call to the new function, updating `total_related_activities` and the `related_activity_ids`
        passed into `Metrics.student_activities_attempted_count/3`.
  - [ ] Create `lib/oli/delivery/metrics/student_distribution_group.ex`
        (`Oli.Delivery.Metrics.StudentDistributionGroup`) with `group_for/2` and `assign/1`,
        implementing the boundary rules from Clarifications above, including the
        `total_related_activities == 0` and nil-`proficiency` defensive defaults.
  - [ ] In `ExpandedObjectiveView`, after building the enriched student list, call
        `StudentDistributionGroup.assign/1` once and keep the result as the `student_proficiency`
        assign.
  - [ ] Rename `selected_proficiency_level` to `selected_student_group` throughout the module.
  - [ ] Replace `handle_event("show_students_list", ...)` / `"hide_students_list"` with
        `handle_event("select_student_group", %{"group" => group}, socket)` (toggling: selecting the
        already-selected group deselects it) and `handle_event("deselect_student_group", _params,
        socket)`. Neither handler does anything beyond updating `selected_student_group` in this PR.
  - [ ] Create `lib/oli_web/components/delivery/learning_objectives/student_distribution_matrix.ex`
        as a stateless `Phoenix.Component` (not a `LiveComponent`), rendering the three-region SVG
        matrix following the `StudentSupportParametersModal.matrix/1` pattern (`fdd.md` sections 3,
        4.1): region `<rect>`s, per-student `<circle>`s with a native `<title>` tooltip, per-region
        count labels, Tailwind `dark:` classes for theming, `viewBox`-based sizing. Each region gets
        `phx-click`, `tabindex="0"`, `role="button"`, `aria-pressed`, `aria-label`, and a
        `phx-keydown` binding treating `Enter`/`Space` as a click.
  - [ ] Wire `ExpandedObjectiveView.render/1` to render `StudentDistributionMatrix` inline (passing
        `students`, `selected_group`, `myself`, `unique_id`) instead of calling `render_dots_chart/1`.
  - [ ] Delete `render_dots_chart/1`, `assets/src/components/misc/DotDistributionChart.tsx` and its
        Jest test file, and the `registerApplication('DotDistributionChart', ...)` line in
        `assets/src/apps/Components.tsx`.
  - [ ] Remove the `StudentProficiencyList` conditional from `ExpandedObjectiveView.render/1` (it is
        deleted, not migrated, in this PR — its replacement does not exist until PR2). Confirm the
        sub-objectives table below is unaffected.
  - [ ] Emit telemetry on `select_student_group`/`deselect_student_group` (`fdd.md` section 11):
        `section_id`, `objective_id`, `group` tags.
- Testing Tasks:
  - [ ] ExUnit, new `test/oli/delivery/metrics/student_distribution_group_test.exs`: boundary tests at
        exactly 50% proficiency and 50% activity completion (AC-012, AC-013, AC-014); every student
        resolves to exactly one group (AC-019); `total_related_activities == 0` and nil-`proficiency`
        defaults; `assign/1` does not mutate unrelated fields (AC-031).
  - [ ] ExUnit, `expanded_objective_view_test.exs`: denominator widening (no sub-objectives ==
        unchanged behavior; with sub-objectives == de-duplicated union; missing-from-depot == `[]`).
  - [ ] `Phoenix.LiveViewTest`, updated `expanded_objective_view_test.exs`: default state has
        `selected_student_group == nil` and no highlighted region (AC-006); selecting a region
        highlights it and only one region can be selected at a time (AC-005); selecting a different
        region deselects the previous one (AC-024); selecting the same region again deselects it
        (AC-027); selection does not change any student's proficiency/activity data (AC-031);
        grouping recalculates from updated fixture data without a page reload (AC-032).
  - [ ] `Phoenix.LiveViewTest` or a component-level `render_component/2` test for
        `StudentDistributionMatrix`: one dot rendered per student (AC-002); x/y driven by
        `proficiency`/`activity_completion` (AC-003); per-region counts match input length (AC-004);
        keyboard activation (`Enter`/`Space` on a focused region) fires the same event as a click
        (AC-034); focus-visible styling is present in the rendered markup (AC-036).
  - [ ] Grep the repo for remaining references to `DotDistributionChart`,
        `Components.DotDistributionChart`, `show_students_list`, `hide_students_list`,
        `selected_proficiency_level` to confirm full removal in this PR's scope (the table-side
        references to `StudentProficiencyList` are handled in PR2, not here).
  - Command(s): `mix test test/oli_web/components/delivery/learning_objectives/`, `mix test test/oli/delivery/metrics/student_distribution_group_test.exs`, `mix format`
- Definition of Done:
  - The expanded row renders the new HEEx matrix with correct per-region counts and highlight
    behavior; no student table renders when a region is selected (expected in this PR); no dead
    references to the old chart remain.
- Gate:
  - All tests above pass; `mix format` clean; manual smoke check in a running app that clicking and
    keyboard-selecting each of the three regions highlights it and no error is raised.
- Dependencies:
  - None (first PR).
- Parallelizable Work:
  - The `StudentDistributionGroup` module and the denominator-widening change touch different
    functions and can be developed in either order or concurrently by two people before being wired
    together in the same PR.

## Phase 2 (PR2): Student Table (Read-Only)

- Goal: add `StudentDistributionTable`, populated by the selection state PR1 already wires up. No
  selection checkboxes or Email button yet.
- Tasks:
  - [ ] Create `lib/oli_web/components/delivery/learning_objectives/student_distribution_table.ex`
        (LiveComponent), filtering the `student_proficiency` list by `distribution_group ==
        selected_student_group`.
  - [ ] Add the static guidance-content map (title, guidance copy, suggested action per group) using
        the verbatim copy captured in `design/instructor_viz_ui_brief.md` (AC-010, AC-015, AC-016,
        AC-017).
  - [ ] Render the close ("X") control firing `deselect_student_group` on the parent (AC-026).
  - [ ] Add the proficiency sub-filter (`handle_event("filter_by_proficiency", ...)`), same four
        options in all three groups per Clarifications above (AC-018).
  - [ ] Create `lib/oli_web/components/delivery/learning_objectives/student_distribution_table_model.ex`
        (new `SortableTableModel`: student name, proficiency via `Proficiency.chip/1`, activity
        completion — no selection column yet), with the group-specific default `sort_by_spec`
        (AC-015, AC-016, AC-017).
  - [ ] Implement Load More as a `visible_count` assign + `Enum.take/2` slice (AC-022, AC-023, AC-033).
  - [ ] Implement the empty-group state: header with a `0` count and an empty-state message instead of
        an empty table (AC-029, AC-030).
  - [ ] Wire `ExpandedObjectiveView.render/1` to mount `StudentDistributionTable` beside the chart
        when `selected_student_group != nil`.
- Testing Tasks:
  - [ ] `Phoenix.LiveViewTest`, new `student_distribution_table_test.exs`: header content per group
        (AC-010, AC-015, AC-016, AC-017); filtered rows only show the selected group (AC-011);
        proficiency filter behavior (AC-018); Load More append without dropping/duplicating rows
        (AC-022, AC-023, AC-033); empty-group rendering (AC-029, AC-030).
  - [ ] `Phoenix.LiveViewTest`, `expanded_objective_view_test.exs`: table is absent until a group is
        selected (AC-007); table renders beside the chart and the chart stays highlighted while it is
        open (AC-008, AC-009); switching groups updates the table without closing first (AC-025);
        closing via "X" clears the selection and the table (AC-026); closing does not mutate data
        (AC-028).
  - Command(s): `mix test test/oli_web/components/delivery/learning_objectives/`, `mix format`
- Definition of Done:
  - Selecting a region shows a correctly filtered, correctly sorted, correctly captioned table beside
    the chart; closing/switching behaves per the ticket; no selection checkboxes or Email button exist
    yet (expected).
- Gate:
  - All tests above pass; manual smoke check of all three group states against the Figma nodes in
    `design/instructor_viz_ui_brief.md` for copy accuracy.
- Dependencies:
  - Phase 1 (needs `selected_student_group`/`distribution_group` to exist).
- Parallelizable Work:
  - None within this phase; it is a single LiveComponent build.

## Phase 3 (PR3): Selection, Email & Shared Selection-State Extraction

- Goal: complete feature parity by adding student selection and the Email flow, and remove the third
  copy of duplicated selection-toggle logic across the codebase.
- Tasks:
  - [ ] Create the shared selection module (`fdd.md` section 4.1 — final module path decided at
        implementation time, default `lib/oli_web/components/delivery/students/student_selection.ex`):
        `toggle/2`, `toggle_all/2`, `selected_emails/2`, extracted from the duplicated logic in
        `StudentProficiencyList` (already deleted by PR1/PR2 — extract from its git history or from
        `StudentSupportTile` directly) and `StudentSupportTile`.
  - [ ] Add the selection checkbox column to `StudentDistributionTableModel` (native
        `<input type="checkbox">`, per Clarifications) and select-all header control, calling the new
        shared module (AC-020).
  - [ ] Wire `OliWeb.Components.Delivery.Students.EmailButton` and the `email_modal_payload`/
        `DraftEmailModal` forwarding pattern into `StudentDistributionTable` (AC-021).
  - [ ] Migrate `StudentSupportTile`
        (`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`)
        to call the shared selection module instead of its inline `MapSet` logic, as a pure refactor
        with no behavior change.
  - [ ] Emit telemetry on Email-from-group and Load More usage (`fdd.md` section 11).
- Testing Tasks:
  - [ ] `Phoenix.LiveViewTest`, `student_distribution_table_test.exs`: checkbox selection and
        select-all (AC-020); Email button acts on the current selection (AC-021); every control
        (checkboxes, Email, Load More, filter, Close) is keyboard-operable (AC-035); focus-visible
        styling across every control introduced in all three PRs (AC-036, final pass).
  - [ ] ExUnit, new tests for the shared selection module: toggle, toggle-all, and email-derivation
        behavior in isolation.
  - [ ] Run `StudentSupportTile`'s existing test suite unmodified to confirm the migration introduced
        no behavior change.
  - Command(s): `mix test test/oli_web/components/delivery/learning_objectives/`, `mix test test/oli_web/components/delivery/instructor_dashboard/`, `mix format`
- Definition of Done:
  - Students can be selected individually or via select-all and emailed from the group table;
    `StudentSupportTile` behaves identically to before its internal refactor.
- Gate:
  - All tests above pass, including `StudentSupportTile`'s full existing suite.
- Dependencies:
  - Phase 2 (needs the table to exist).
- Parallelizable Work:
  - The shared-module extraction and the `StudentDistributionTable` checkbox/Email wiring can be done
    by the same person sequentially, or split: one person extracts and tests the shared module while
    another wires the table's UI against its planned interface.

## Phase 4: Manual QA, Accessibility Verification & Telemetry Validation

- Goal: verify the shipped behavior against the Figma source of truth, the ticket's accessibility
  requirements, and the telemetry added across the three PRs.
- Tasks:
  - [ ] Visual comparison against the five Figma nodes in `design/instructor_viz_ui_brief.md`
        (`346:6145`, `358:11956`, `349:11077`, `349:11526`, `349:11974`) for the default state and each
        of the three group states, including guidance copy accuracy.
  - [ ] Keyboard-only walkthrough of region selection and every table control, confirming visible
        focus indicators, against `.review/ui.md`.
  - [ ] Confirm telemetry events from PR1 and PR3 are visible in the local/staging AppSignal or
        telemetry sink.
  - [ ] Confirm the still-open FDD questions (section 16) that were resolved during implementation are
        reflected correctly in the shipped behavior, or explicitly re-flagged if still unresolved.
- Testing Tasks:
  - [ ] Manual: email-selected-students flow from a group table end to end.
  - Command(s): none (manual pass); record findings in the PR description.
- Definition of Done:
  - No unresolved visual or accessibility mismatch against the Figma source; telemetry confirmed
    flowing.
- Gate:
  - Sign-off recorded in the PR description referencing this phase's checklist.
- Dependencies:
  - Phase 3.
- Parallelizable Work:
  - None (final verification pass).

## Phase 5: Final Regression, Code Review & Requirements Closure

- Goal: close out the work item with a full regression pass and traceability update.
- Tasks:
  - [ ] Run the full backend and frontend test suites to catch any unrelated regression.
  - [ ] Request code review per `docs/CODEREVIEW.md`: `.review/security.md` and
        `.review/performance.md` always; `.review/elixir.md` and `.review/ui.md` given this ticket's
        LiveView/UI surface area; `.review/requirements.md` given the PRD traceability in this work
        item. `.review/typescript.md` is no longer required for this ticket's chart (it is HEEx, not
        React) but still applies if any TypeScript file is touched (e.g. deleting
        `DotDistributionChart.tsx`).
  - [ ] Run `python3 <skills_root>/requirements/scripts/requirements_trace.py <work_item_dir> --action verify_implementation`
        and update `requirements.yml` AC statuses to `verified` with implementation-file proofs.
  - [ ] Update MER-5814 in Jira with the PR links (three PRs) per `docs/ISSUE_TRACKING.md`.
  - [ ] Confirm all three PRs landed on `master` before the next release cut (Scope section).
- Testing Tasks:
  - [ ] `mix test` (full suite)
  - [ ] `cd assets && yarn test && yarn lint` (regression check even though this ticket's own chart is
        no longer React — other apps in the bundle still need to build/test cleanly)
  - Command(s): `mix test`, `cd assets && yarn test`, `cd assets && yarn lint`, `mix format --check-formatted`
- Definition of Done:
  - Full suites pass; code review findings addressed; `requirements.yml` reflects final AC status; all
    three PRs merged before the release cut.
- Gate:
  - `master_validate --stage implementation_complete` passes.
- Dependencies:
  - Phase 4.
- Parallelizable Work:
  - None (closeout phase).

## Parallelization Notes

- Within PR1, the `StudentDistributionGroup` module and the denominator-widening change are
  independent of each other and can be built concurrently before being wired together.
- PR2 cannot start in earnest until PR1's `selected_student_group`/`distribution_group` data shape
  exists, but the guidance-content map and table-model column definitions can be drafted in parallel
  with the tail end of PR1.
- PR3's shared-module extraction and the table's checkbox/Email UI wiring can be split across two
  people.
- Phases 4 and 5 are strictly sequential closeout phases with no safe concurrent work.
- Because delivery spans three PRs with no feature flag, the hard constraint is calendar, not
  technical: all three must land on `master` before the next release cut. Track that date explicitly
  once known.

## Phase Gate Summary

- Gate A (after PR1): the HEEx chart renders correctly, selection/keyboard/highlight behavior is
  correct, and the group-assignment/denominator logic is independently tested — the riskiest technical
  bet in this ticket is now validated in production (on `master`, pre-release).
- Gate B (after PR2): the student table is correct, filtered, sorted, and captioned per group, with no
  data-mutation side effects from selection/closing.
- Gate C (after PR3): full feature parity — selection, email, and the third-copy selection-logic
  duplication removed — with `StudentSupportTile` regression-tested.
- Gate D (after Phase 4): visual, accessibility, and telemetry sign-off recorded.
- Gate E (after Phase 5): full regression green, code review complete, `requirements.yml` at
  `verified` for all 36 ACs, Jira updated, all three PRs confirmed merged ahead of the release cut.
