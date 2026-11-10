# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/lo_analytics/instructor_viz`
Phase: `2 (PR2) — Student Table (Read-Only)`

## Scope from plan.md
- Add `StudentDistributionTable` (new LiveComponent), populated by the `selected_student_group`
  state PR1 already wires up. Filters the already-computed `student_proficiency` list by
  `distribution_group == selected_student_group`; never recomputes grouping.
- Static per-group guidance content (title, guidance copy, suggested action), verbatim from
  `design/instructor_viz_ui_brief.md`.
- Close ("X") control firing `deselect_student_group` on the parent `ExpandedObjectiveView`.
- Proficiency sub-filter (`filter_by_proficiency`), same four options (+ "all") in all three groups.
- `StudentDistributionTableModel` (new `SortableTableModel`): student name, proficiency (via
  `Proficiency.chip/1`), activity completion — no selection column yet (PR3). Group-specific default
  sort order.
- Load More via `visible_count` assign + `Enum.take/2` slice (per `plan.md`, this PR's task, not PR3 —
  `fdd.md` section 13 had this listed under PR3; corrected to match `plan.md` in this phase, see
  Work-Item Sync below).
- Empty-group state (header shows a `0` count, empty-state message instead of an empty table).
- Wire `ExpandedObjectiveView.render/1` to mount the table beside the chart when a group is selected.
- Out of scope this phase: selection checkboxes, select-all, Email button, `StudentSelection`
  extraction, `StudentSupportTile` migration (all PR3).

## Implementation Blocks
- [x] Core behavior changes
  - `OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTableModel`
    (`lib/oli_web/components/delivery/learning_objectives/student_distribution_table_model.ex`, new):
    `SortableTableModel`-based, 3 columns (student name, proficiency chip, activity completion %).
    Group-specific proficiency sort ordinal baked into the `:proficiency` column's `sort_fn` (Needs
    Support: Low-first; Excelling: Medium-first; Limited Activity: Not Enough Info -> Low -> Medium ->
    High, matching the plan's Clarifications verbatim).
  - `OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTable`
    (`lib/oli_web/components/delivery/learning_objectives/student_distribution_table.ex`, new
    LiveComponent): header (title, count via the same `ngettext` idiom the chart's own header already
    uses, guidance paragraph), proficiency `<select>` filter, `SortableTable.Table`-based body, Load
    More button, empty-state message. All local state (`sort_by`, `sort_order`,
    `selected_proficiency_filter`, `visible_count`) resets to defaults on a group switch, and persists
    across same-group re-renders (filter changes, Load More, re-sorting).
  - `ExpandedObjectiveView`: wired `StudentDistributionTable` beside `StudentDistributionMatrix` inside
    a `flex` row (`flex-col` on narrow, `xl:flex-row` — a minimal, non-pixel-tuned responsive fallback;
    full responsive layout is out of this ticket's scope per `prd.md`/`fdd.md`), rendered `:if`
    `@selected_student_group != nil`. Its close button's `phx-target` points at the parent's `@myself`
    (`parent_target` attr), since deselecting a group is state `ExpandedObjectiveView` owns.
  - Deleted `StudentProficiencyList`, `StudentProficiencyTableModel`, and their test file (dead since
    PR1 removed their only call site; per `fdd.md` section 14 these are deleted, not deprecated, once
    the replacement table ships). Reworded two stale comments in `learning_objectives.ex` and
    `instructor_dashboard_live.ex` that named the now-deleted module.
- [x] Data or interface changes
  - New LiveView events, both scoped to `StudentDistributionTable`'s own `@myself`:
    `filter_by_proficiency` (payload `%{"proficiency" => "all" | "not_enough_info" | "low" | "medium" |
    "high"}`) and `load_more` (no payload). A third, `student_distribution_sort`, drives re-sorting by
    clicking a column header (not an FDD-listed interface, but the same mechanism
    `StudentProficiencyList` used previously and required for the `SortableTableModel` pattern to be
    genuinely interactive rather than display-only).
  - `deselect_student_group` (already added in PR1, previously unreachable from any control) now has
    its first real caller: the table's close button.
- [x] Access-control or safety checks
  - `filter_by_proficiency`'s incoming string is validated against a fixed allowlist
    (`normalize_proficiency_filter/1`) before use, falling back to `"all"` for anything unrecognized.
  - `student_distribution_sort`'s incoming column name is resolved only against the table model's own
    known sortable columns (`parse_sort_by/1`), falling back to the default column for anything
    unrecognized — never converts client input to an atom via `String.to_atom`/`to_existing_atom`.
  - No new data exposure: `StudentDistributionTable` only filters/sorts/paginates the same
    section-scoped `student_proficiency` list `ExpandedObjectiveView` already loaded and authorized;
    it fetches nothing itself.
- [x] Observability or operational updates when needed
  - None added, consistent with this work item's already-recorded decision (`fdd.md` section 11,
    `phase_1_execution_record.md` "Telemetry Removed") not to add unwired custom telemetry.

## Test Blocks
- [x] Tests added or updated
  - `test/oli_web/components/delivery/learning_objectives/student_distribution_table_test.exs` (new,
    11 tests): header content and count per group (AC-010, AC-015, AC-016, AC-017); group filtering
    (AC-011); group-specific default proficiency sort order for all three groups (AC-015, AC-016,
    AC-017); proficiency sub-filter narrowing (AC-018); empty-state rendering both for a truly empty
    group and for a filter that narrows a non-empty group to zero rows (AC-029, AC-030); Load More
    append without dropping/duplicating rows (AC-022, AC-023, AC-033); the close control's
    `phx-target` points at the passed-in `parent_target`, not the component's own `@myself`.
  - `test/oli_web/components/delivery/learning_objectives/expanded_objective_view_test.exs` (updated,
    +4 tests): table absent until a group is selected (AC-007); selecting a group renders the table
    beside the chart while the chart stays highlighted (AC-008, AC-009); switching groups updates the
    table in place without closing it first (AC-025); closing via the table's "X" closes the table,
    deselects the group, and leaves the underlying student data/count unchanged (AC-026, AC-028).
    Reworded a stale comment on the pre-existing `deselect_student_group/2` unit test now that it has
    a real rendered caller.
  - Deleted `student_proficiency_list_test.exs` (tested a module removed in this phase).
- [x] Required verification commands run
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/components/delivery/learning_objectives/
    test/oli/delivery/metrics/student_distribution_group_test.exs` → 76 tests, 0 failures.
  - `mix test test/oli_web/components/delivery/learning_objectives/ test/oli/delivery/metrics/
    test/oli/delivery/sections_test.exs` (same broader regression scope PR1 used) → 210 tests, 0
    failures.
  - `mix format --check-formatted` (repo-wide) — clean.
  - `python3 <skills_root>/validate/scripts/validate_work_item.py <work_item_dir> --check all` — passed,
    both before and after implementation.
  - No `yarn`/frontend commands run this phase: no `assets/` files were touched (this PR's table is
    pure HEEx, like PR1's chart), and `plan.md`'s own Phase 2 gate does not call for them — that
    regression pass is Phase 5's job.
  - Tests were run against an isolated, worktree-local Postgres database (via `DATABASE_URL`) rather
    than the repo's shared `oli_test` database, since another concurrent session held open connections
    to `oli_test` that made this worktree's `mix test` alias (which unconditionally drops/recreates the
    DB) fail with `object_in_use`. Forcing that drop would have disrupted another session's active
    work, so this was avoided rather than forced through.
- [x] Results captured (above)

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged:
  - `fdd.md` section 13 previously listed AC-022/AC-023/AC-033 (Load More) under the PR3 bullet, while
    `plan.md`'s own Phase 2 task list already assigned Load More to PR2. This was a pre-existing
    inconsistency between the two docs (not something this phase's implementation caused) — followed
    `plan.md` as the authoritative delivery sequence (Load More implemented in this PR) and corrected
    `fdd.md` section 13 plus the three affected ACs' `plan.md` proofs in `requirements.yml` to match.
  - No other material divergence: implementation matches `fdd.md` section 4.1 (`StudentDistributionTable`
    / `StudentDistributionTableModel`) and `plan.md` Phase 2 (PR2) task list.
- [x] Open questions added to docs when needed — none new. Carried forward, unresolved, from
  `fdd.md` section 16 / `design/instructor_viz_ui_brief.md`: the exact Figma proficiency-filter option
  list (implemented per the plan's default assumption: the same 4 options + "all" in every group), the
  per-group header badge icon (not implemented — this phase's header is text-only, no icon, since the
  icon question was flagged unconfirmed and nothing in the ACs requires one), and the empty-state
  copy (no Figma frame covers it; the message text used here, "No students currently belong to this
  group." / "No students match the selected filter.", is a reasonable default, not a confirmed string).

## Review Loop
- Round 1 findings (4 parallel `.review/*.md`-scoped agents; `.review/typescript.md` and
  `.review/requirements.md` skipped -- no TypeScript touched, no `prd.md` change):
  - **security.md**: no findings. One residual, non-blocking note: `render/1`'s
    `Map.fetch!(@group_content, assigns.selected_group)` would raise on an out-of-contract
    group value; safe today only because `ExpandedObjectiveView` validates the group against
    a hardcoded allowlist before ever setting `selected_student_group`, and this component only
    renders when that value is non-nil. Worth re-checking if `selected_group` ever becomes
    settable through a new entry point (e.g. a deep link) without that same validation.
  - **performance.md**: 2 findings, both fixed:
    1. `update/2` unconditionally rebuilt the filtered/sorted table on every parent re-render,
       not only when this component's own inputs changed (LiveView calls a LiveComponent's
       `update/2` on every parent render pass). Fixed by short-circuiting on
       `group_changed?`/`students_changed?`/first-mount only.
    2. `load_more` and `student_distribution_sort` both re-ran the group+proficiency
       `Enum.filter/2` passes even though neither changes what's filtered (only pagination or
       sort order). Fixed by splitting the pipeline into `recompute_filtered_students/1` (group
       + proficiency filter, called only when those actually change) and `resort/1`
       (re-sort only); `load_more` now only bumps `visible_count` and does no filtering/sorting
       at all, deriving the visible slice in `render/1`.
  - **elixir.md**: 3 findings; 2 fixed, 1 noted:
    1. `filter_by_proficiency`/`student_distribution_sort` had no catch-all `handle_event`
       clause, so a malformed/missing-key client event would raise `FunctionClauseError` and
       crash the LiveView -- fixed by adding a fallback clause per event (matching the existing
       `OliWeb.Common.SortableTable.TableHandlers` idiom for the same situation).
    2. No test exercised a group switch while a non-default sort/filter/pagination was active,
       to confirm that state resets rather than carrying over -- added
       "switching groups resets in-flight sort, filter, and pagination state" to
       `student_distribution_table_test.exs`.
    3. Minor, not fixed: the three distribution-group atoms and their per-group content/ordering
       are hardcoded independently in `student_distribution_table.ex`, `student_distribution_table_model.ex`,
       and (pre-existing from PR1) `student_distribution_matrix.ex`. This mirrors an existing PR1
       pattern rather than introducing new duplication; flagged as a reuse opportunity, not
       fixed here, to avoid scope creep into PR1's already-shipped code in this phase.
  - **ui.md**: 1 real finding, not auto-fixed; 1 minor note:
    1. The shared `OliWeb.Common.SortableTable.Table`'s sortable `<th>` headers are mouse-only
       (a bare `phx-click`-bound `<th>`, no `tabindex`, no keydown handler, no `aria-sort`).
       This is a pre-existing shared-component gap, not new code from this phase, but this PR is
       the first surface in this work item that makes sorting a real interactive control an
       instructor would use. Fixing it means changing a component shared across the codebase --
       out of this phase's scope to fix unilaterally. `prd.md`'s AC-035 does not list sorting
       among the controls that must be keyboard-operable. **Flagged as an open risk, not fixed**;
       added to `fdd.md` section 16 as a new follow-up for an explicit scope decision before
       PR3's keyboard/focus pass.
    2. Minor, not fixed: the same shared `<th>` lacks `scope="col"`, and the table has no
       `<caption>`/`aria-labelledby` tying it to the group's `<h4>` title above it. Low severity,
       same shared-component root cause as (1).
  - No `.review/requirements.md` or `.review/typescript.md` findings (not run -- out of scope
    per the checklist selector: no `prd.md` change, no TypeScript touched).
- Round 1 fixes: all applicable fixes applied (see above); full targeted suite re-run afterward
  -> 211 tests, 0 failures (`test/oli_web/components/delivery/learning_objectives/`,
  `test/oli/delivery/metrics/`, `test/oli/delivery/sections_test.exs`); `mix format
  --check-formatted` and `mix compile --warnings-as-errors` both clean.

## Manual QA Follow-up (post-review, on user request)

The user ran the app locally and requested four changes after visually checking the table:

- Column headers renamed: "Learning Proficiency" -> "Proficiency", "Activity Completion" ->
  "Activities" (`student_distribution_table_model.ex`).
- The Activities cell now renders `"<attempted> of <total> (<pct>%)"` (e.g. `"1 of 9 (11%)"`)
  instead of a bare percentage, using the same `activities_attempted_count`/
  `total_related_activities` fields `ExpandedObjectiveView` already attaches per student.
- The whole table block is now a fixed `h-[625px]` column (`flex flex-col`): the header and
  proficiency filter stay fixed at the top, the table body scrolls internally
  (`flex-1 overflow-y-auto`), and the "Load N more" button is pinned below the scrollable area
  rather than scrolling away with the rows.
- The proficiency filter's default option now reads "Proficiency" instead of "All" (same
  `"all"` value underneath, per FDD section 5's interface contract).

**Also found and fixed a real bug while making these changes**: the proficiency filter was not
functioning at all when driven from the actual browser `<select>`. Root cause: the `<select
phx-change="filter_by_proficiency">` was bound directly on a bare `<select>`, not inside a
`<form>`. A repo-wide grep of every other `phx-change` usage in `lib/oli_web` (dozens of call
sites) showed this codebase's convention is always `<form phx-change=...>` or `<.form
phx-change=...>` -- never a bare form control -- which was the tell. Fixed by wrapping the
`<select>` in `<.form for={%{}} phx-target={@myself} phx-change="filter_by_proficiency">`,
matching the existing convention (e.g. `learning_objectives.ex`'s `search_objective` form). The
original tests for this handler used `element(view, "select") |> render_change(%{"proficiency"
=> ...})`, which supplies the event params explicitly and therefore couldn't have caught this --
it never actually exercised the real DOM-to-params serialization path that was broken. Replaced
those with `view |> form("form", %{"proficiency" => ...}) |> render_change()`, which does drive
real `<form>` serialization, and added two more tests locking in the new header labels/activities
format and the dropdown's default label.

Verification after this pass: `mix compile --warnings-as-errors`, `mix format
--check-formatted` (repo-wide) -- both clean. `mix test
test/oli_web/components/delivery/learning_objectives/
test/oli/delivery/metrics/student_distribution_group_test.exs` -> 79 tests, 0 failures. Broader
regression (`test/oli_web/components/delivery/learning_objectives/ test/oli/delivery/metrics/
test/oli/delivery/sections_test.exs`) -> 213 tests, 0 failures.

Two small follow-ups from further manual QA:
- The dropdown's default option label was corrected from "Proficiency..." to "Proficiency" (no
  ellipsis).
- The native `<select>` had no explicit width, so selecting the longest option ("Not Enough
  Info") could grow the closed select box wide enough to wrap onto a second line beneath the
  browser's native arrow icon. Fixed with a fixed `w-44` plus `truncate`/`overflow-hidden`/
  `whitespace-nowrap` and `pr-8` to reserve room for the arrow, so the label always renders on
  one line regardless of which option is selected.

## Manual QA Follow-up 2: Figma-accurate header badge and left accent border

The user flagged that the table panel should have a colored left accent border per group, and
that the header should show a count badge next to the title (not "Needs Support (0 students)"
as a parenthetical). Re-checked directly against the Figma reference nodes
(`349:11077`/`349:11526`/`349:11974`, file `iVKgFJwC1iKP7jmJBGILOK`) via screenshots and
pixel-sampling (not just the earlier metadata pass):

- **Left accent border**: confirmed present, ~3px wide, slightly rounded top/bottom corners,
  matching the exact same pattern already used by `StudentSupportTile`'s bucket accent bar
  (`absolute inset-y-0 left-0 w-[3px] rounded-l-xl`). Sampled colors pixel-exact against
  existing tokens: Needs Support `#FF4040` (`Border-border-danger`, already used by the chart's
  own Needs Support region border), Excelling `#218358` (`Text-text-accent-green`, already used
  by the chart), Limited Activity `#353740` (`Text-text-high`).
- **Header badge**: confirmed the header shows a small colored circular badge with the student
  count, to the left of the group title (title has no parenthetical count anymore); the guidance
  paragraph renders below that row, unchanged. Badge colors also sampled pixel-exact: Needs
  Support bg `#FEEBED` (`Fill-fill-danger`) / text approximated to `Text-text-danger`
  (`#CE2C31`, the sampled `#B60202` has no matching existing token -- same
  approximate-to-nearest-existing-token approach PR1 used for the chart); Excelling bg `#E7FCF3`
  (`Fill-Chip-Green`) / text `#218358` (`Text-text-accent-green`); Limited Activity bg `#CED1D9`
  (`Fill-Chip-Gray`) / text `#000000` (`Text-Chip-Gray`). No new tokens needed -- every value
  matches (or nearly matches) a token already wired into this codebase.

Implementation: added `accent_class`/`badge_bg_class`/`badge_text_class` to each group's entry in
`@group_content`; added the absolutely-positioned accent bar and replaced the inline
`(N Students)` text with a `<span>` badge (with an `aria-label` carrying the full "N student(s)"
text for screen readers, since the visible badge is bare-number-only). Updated
`student_distribution_table_test.exs`: three assertions that checked the old inline count text
now check the badge's `aria-label`; added a new test asserting each group's accent/badge classes
render correctly.

Verification: `mix compile --warnings-as-errors`, `mix format --check-formatted` -- both clean.
`mix test test/oli_web/components/delivery/learning_objectives/` -> 71 tests, 0 failures. Broader
regression (`test/oli_web/components/delivery/learning_objectives/
test/oli/delivery/metrics/ test/oli/delivery/sections_test.exs`) -> 214 tests, 0 failures.

On follow-up, the user asked why the accent was a separate absolutely-positioned overlay `<div>`
instead of a real CSS `border-left`. Switched to `border-l-[3px]` plus a per-group
`border-l-{token}` color class layered on the panel's existing 1px `border`, removing the extra
element and the `relative`/`absolute` positioning entirely. Re-verified:
`mix compile --warnings-as-errors`, `mix format --check-formatted` clean; `mix test
test/oli_web/components/delivery/learning_objectives/` -> 71 tests, 0 failures.

**That still rendered gray in the browser.** First attempted fix (fully independent per-side
border-color classes with no shorthand-producing class at all, to rule out a CSS cascade/source-
order issue) also failed. Root cause, found by reading `assets/tailwind.plugins.js`: the custom
`tokenColorPlugin` that turns `tailwind.tokens.js` entries into usable Tailwind classes only ever
generated an all-sides `.border-{token}` rule (`{ borderColor: light }`) -- it never generated
`.border-t/-r/-b/-l-{token}` at all. `border-l-{token}` wasn't losing a cascade fight; it was not
a real CSS rule, full stop, so the element always fell back to whichever all-sides `.border-{color}`
class was also present (`Border-border-subtle`'s light gray, `#E6E9F2` -- exactly the "grisecito"
reported). This is a pre-existing gap in shared build tooling, not something introduced by this
ticket, but this is the first place in the app that needed a per-side token border.

Fixed in `assets/tailwind.plugins.js`: added `.border-t/-r/-b/-l-{token}` generation (light +
dark), collected into a separate `borderSideComponents` object and registered via its own,
later `addComponents()` call so the per-side rules are always emitted after the general
`.border-{token}` rules in the compiled stylesheet -- guaranteeing the override wins regardless
of which two tokens are combined or their relative declaration order in `tailwind.tokens.js`
(the fragile alternative: relying on `Object.entries(tokens)` iteration order happening to place
the override token after the base token). Reverted `student_distribution_table.ex` back to the
clean `border` + `border-l-[3px]` + `border-l-{token}` form, since it now works correctly.

`yarn lint`/Prettier clean. **User confirmed the correct per-group border color renders in the
browser.**

## Manual QA Follow-up 3: Table striping, sorting bug, and pulling checkboxes forward

The user reviewed the table itself and reported all rows sharing one background color (no zebra
striping) and sorting "not working well," and asked to pull the selection checkboxes forward
into this phase (originally PR3) -- and whether `StudentSupportTile` had already solved any of
this that could be reused.

Investigation:
- **Striping**: confirmed real. `OliWeb.Common.SortableTable.Table.render_row/2` appends
  `additional_row_class` to *every* row identically -- there is no index-based alternation in
  that shared component at all, so passing a single class (as this table did) colors every row
  the same.
- **Sorting**: confirmed real, but only for one column. `StudentDistributionTableModel`'s
  `:student_name` `ColumnSpec` had no custom `sort_fn`, so it fell through to
  `ColumnSpec.default_sort_fn/2`, which does `Map.get(row, :student_name)` -- but student rows
  only carry `:full_name`, never `:student_name` (that atom was only ever the column's *key*,
  used for the header/event wiring, and happened to coincide with nothing on the data). Every
  comparison read `nil` on both sides, so `Enum.sort/2` returned the input order unchanged --
  clicking "Student Name" silently did nothing. Proficiency (custom `sort_fn`) and Activities
  (real `:activity_completion` field) sorted correctly; only Student Name was broken.
- **`StudentSupportTile` reuse check**: it has real `rem(index, 2)`-based striping (reusable
  pattern), but it is a flat scrollable list with no sortable columns at all, so it has no
  sorting behavior to borrow. Its checkboxes are a custom `role="checkbox"` `<button>`, which
  `fdd.md` section 2 already decided against for this ticket in favor of native
  `<input type="checkbox">`.
- User decision (asked via clarifying question): pull the selection checkbox column and
  "select all" forward into this phase as local state only -- no Email button, no
  `StudentSelection` shared-module extraction. Both remain PR3, now wired onto the selection
  state this phase already built instead of building it from scratch.

Given the shared `OliWeb.Common.SortableTable.Table` had two real, unrelated gaps (no real
striping, no accessible sort headers -- the latter already flagged as an open risk in Round 1
review) and now also needed a checkbox column, `StudentDistributionTable` stopped using it
entirely and renders its own `<table>`:

- `StudentDistributionTableModel` rewritten: no more `ColumnSpec`/`SortableTableModel`. Now just
  `columns/0` (key/label pairs) and `sort/4` (a plain `Enum.sort_by/3` using `student.full_name`
  directly for the name column -- the exact bug above, fixed by construction), keeping the same
  per-group proficiency ordinal logic as before.
- `StudentDistributionTable`'s `render/1` hand-rolls `<table>`/`<thead>`/`<tbody>`: real
  `rem(index, 2)`-based striping against `bg-Table-table-row-1`/`bg-Table-table-row-2` (matching
  `StudentSupportTile`'s pattern and this ticket's own token mapping); each sortable `<th>` wraps
  a real `<button>` (not a bare `phx-click`-bound `<th>`) with `aria-sort` on the `<th>` itself,
  resolving the Round 1 UI-review sort-header keyboard finding for this table; a checkbox column
  (native `<input type="checkbox">` per row, `phx-value-student_id`, `aria-label`) plus a header
  "select all" checkbox, backed by a `selected_student_ids :: MapSet.t()` assign with
  `toggle_student`/`toggle_all` handlers (local `MapSet` logic, matching `StudentProficiencyList`'s
  old pattern -- intentionally *not* yet calling a shared module, since that extraction is PR3).
  Selection state resets on a group switch (same reset pass as sort/filter/pagination) and
  persists across sort/proficiency-filter changes and Load More within a group. `toggle_all`
  operates on the full filtered+sorted list, not just the currently-visible/paginated slice, so
  selecting all then loading more doesn't leave newly-revealed rows inconsistently unselected.

Tests: rewrote `student_distribution_table_test.exs`'s row-name helper (`td:first-child` ->
`td:nth-child(2)`, since the checkbox is now the first cell) and sort-header selectors
(`th[phx-value-sort_by=...]` -> `button[phx-value-sort_by=...]`, since that attribute moved onto
the button). Added: a striping test asserting the two tokens actually alternate by row index; a
sort-click regression test asserting clicking "Student Name" actually reorders rows (and reverses
on a second click) -- direct regression coverage for the bug found above; a row-checkbox toggle
test asserting one row's selection doesn't affect another's; a select-all test asserting it
selects every filtered student and toggles fully off when already fully selected.

Verification: `mix compile --warnings-as-errors`, `mix format --check-formatted` -- both clean.
`mix test test/oli_web/components/delivery/learning_objectives/student_distribution_table_test.exs`
-> 18 tests, 0 failures (14 previous + 4 new). Broader regression
(`test/oli_web/components/delivery/learning_objectives/ test/oli/delivery/metrics/
test/oli/delivery/sections_test.exs`) -> 218 tests, 0 failures.

Docs synced: `plan.md` Phase 2 now lists the checkbox/select-all task and the hand-rolled-table
architecture decision explicitly (was previously scoped to Phase 3); Phase 3 narrowed to "Email &
Shared Selection-State Extraction" only, and its shared-module extraction task now names
`StudentDistributionTable`'s already-shipped inline logic as a migration source alongside
`StudentSupportTile`'s. `requirements.yml` AC-020's `plan.md` proof updated to point at Phase 2.
`fdd.md` section 4.1 updated to describe the hand-rolled table and the border-color plugin fix;
section 13's PR2/PR3 testing-strategy lists updated to match; the "sort-header keyboard access"
section 16 follow-up marked resolved for this table specifically (the shared component itself is
unchanged for its other consumers).

## Manual QA Follow-up 4: Avatar and header tooltips

Two more Figma-fidelity gaps surfaced once the table itself was working correctly:

- **Avatar in the Student Name column**: Figma shows a small circular avatar (photo or initials)
  before each student's name -- already solved elsewhere in the app
  (`OliWeb.Components.Delivery.UserAccount.user_picture_icon/1`, used by `StudentSupportTile`).
  The user explicitly did not want the active/inactive status dot `StudentSupportTile` also
  shows on its avatar; this table has no such status concept. Wiring it required threading
  `:picture` through the student data pipeline: `Accounts.get_users_by_ids/1`'s `select:` list
  only fetched `[:id, :name, :given_name, :family_name, :email]`, never `:picture`, even though
  `Oli.Accounts.Schemas.User` has that field. That function has exactly two callers, both in
  `expanded_objective_view.ex` (confirmed by grep before widening its select list), so this was a
  low-risk, effectively local change. Added `:picture` to the select list and to both places
  `expanded_objective_view.ex` builds a student map (`retrieve_students_data/1` and the
  missing-student backfill in `add_missing_students_to_proficiency_data/4`), then rendered
  `UserAccount.user_picture_icon/1` in the table's Student Name cell (falls back to initials when
  a student has no picture, same as `StudentSupportTile`).
- **Header info tooltips on Proficiency and Activities**: Figma shows a small ⓘ icon before
  those two column labels (not before Student Name), matching an existing pattern
  (`OliWeb.Delivery.InstructorDashboard.HTMLComponents.render_label/1`) already used by the
  outer (collapsed-row) objectives table. Copy was **not** invented new: the Proficiency tooltip
  reuses that same outer table's existing "Student Proficiency" tooltip text verbatim; the
  Activities tooltip reuses the exact text the now-deleted `StudentProficiencyTableModel` shipped
  for its "Activities Attempted" column (confirmed via `git show HEAD:...` against the
  uncommitted deletion, since that module predates this ticket). `render_label/1` itself wasn't
  reused directly, since it bundles the icon *and* the column title into one non-splittable
  block, while here only the title belongs inside the clickable sort `<button>` — added a small
  local `header_tooltip/1` component instead, replicating that component's icon/dialog markup.
  On a follow-up question, corrected the icon's color: initially wrapped it in the same
  `text-Text-text-high` class `render_label/1` uses, but the user pointed at the actual Figma
  node and a direct `get_variable_defs` check on the icon instance (`349:11236`, "20px/Support")
  confirmed `Icon/icon-default` (`#757682`), not `Text/text-high` — fixed to
  `text-Icon-icon-default` (the SVG's `stroke="currentColor"` inherits it from the wrapping
  `<span>`). `StudentDistributionTableModel.columns/0` now carries an optional `:tooltip` per
  column entry.

Tests added: `Proficiency` and `Activities` headers render their tooltip text; `Student Name`'s
header renders no `<dialog>`. Verification: `mix compile --warnings-as-errors`, `mix format
--check-formatted` clean; `mix test test/oli_web/components/delivery/learning_objectives/` -> 76
tests, 0 failures.

## Manual QA Finding: "Linked Activities" (1) vs. "Activities" (0 of 3) discrepancy

While reviewing the table live, the user noticed a Learning Objective's collapsed-row "Linked
Activities" column read "View 1 Activity" while, once expanded, this table's "Activities" column
for a student read "0 of 3" for the same objective -- and asked why.

Root cause (not a bug): the two counts read the same underlying field
(`section_resources.related_activities`) but at different scope. The collapsed row's
`:related_activities_count` (`ObjectivesTableModel`, populated by
`Sections.get_objectives_and_subobjectives/2` with `include_related_activities_count: true`) is
the top-level objective's own directly-attached activities only. This table's
`total_related_activities` (via `linked_activity_ids_for_objective/2`, added in PR1) is the
*union* of the objective's own activities with all its sub-objectives' activities -- exactly the
"widened denominator" change `informal.md`/`fdd.md` already documented as an intentional PR1
correction (Requirement 1), just not previously spelled out as "these two specific numbers, in
these two specific places, will now disagree." Confirmed via `Sections.get_objectives/2`'s
implementation (`sections.ex`) doing `length(objective.related_activities || [])` with no
sub-objective union, versus this ticket's own union logic.

Decision (user, explicit): leave the collapsed row's "Linked Activities" column as-is. It belongs
to `ObjectivesTableModel`, a component this ticket's plan never scoped to touch; reconciling the
two would be a separate, deliberate scope decision, not a PR2 fix. Documented as a known,
intentional cross-surface discrepancy in `fdd.md` section 15 (Risks & Mitigations) so a future
reader doesn't mistake it for a bug.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled (4-checklist round complete, applicable findings fixed,
  two design/shared-component-scope findings explicitly flagged rather than auto-fixed)
- [x] Manual QA follow-up applied and re-verified (see above)
- [x] Validation passes (`validate_work_item.py --check all`)
