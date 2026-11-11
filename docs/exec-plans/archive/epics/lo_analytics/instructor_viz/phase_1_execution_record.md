# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/lo_analytics/instructor_viz`
Phase: `1 (PR1) — Chart Only, HEEx Student Distribution Matrix`

## Scope from plan.md
- Replace `DotDistributionChart` with a pure HEEx/SVG `StudentDistributionMatrix` (3 regions).
- Widen the linked-activity denominator via `SectionResourceDepot`.
- Add `Oli.Delivery.Metrics.StudentDistributionGroup` (group assignment).
- Rename `selected_proficiency_level`/`show_students_list`/`hide_students_list` to
  `selected_student_group`/`select_student_group`/`deselect_student_group`.
- Remove the `StudentProficiencyList` conditional from `ExpandedObjectiveView.render/1` (module itself
  deleted in PR2, not this phase).
- Delete `DotDistributionChart.tsx` + its Jest test + its `Components.tsx` registration.
- Out of scope this phase: `StudentDistributionTable`, selection checkboxes, Email wiring.

## Implementation Blocks
- [x] Core behavior changes
  - `Oli.Delivery.Metrics.StudentDistributionGroup` (`lib/oli/delivery/metrics/student_distribution_group.ex`): `group_for/2`, `assign/1`.
  - `OliWeb.Components.Delivery.LearningObjectives.StudentDistributionMatrix` (`lib/oli_web/components/delivery/learning_objectives/student_distribution_matrix.ex`): stateless HEEx/SVG matrix, 3 regions.
  - `ExpandedObjectiveView`: `linked_activity_ids_for_objective/2` (widened denominator), `selected_student_group` state, `select_student_group`/`deselect_student_group` events (toggle-to-deselect, key-filtered), wired the new matrix into `render/1`, removed `render_dots_chart/1`, the old `StudentProficiencyList` conditional, and the now-dead `calculate_proficiency_distribution_from_student_data/3`.
  - Deleted `assets/src/components/misc/DotDistributionChart.tsx` + its Jest test + its `Components.tsx` registration.
- [x] Data or interface changes
  - New LiveView events `select_student_group`/`deselect_student_group` replace `show_students_list`/`hide_students_list`.
  - `student_proficiency` assign now carries `activity_completion`/`distribution_group` per student.
- [x] Access-control or safety checks
  - `select_student_group` validates the incoming `"group"` string against a fixed atom allowlist (`parse_group/1`) before use — never `String.to_existing_atom` on raw client input.
- [x] Observability or operational updates when needed
  - None added. A custom telemetry call on the two new events was added and then removed in this
    same phase — see "Telemetry Removed" below for why.

## Test Blocks
- [x] Tests added or updated
  - `test/oli/delivery/metrics/student_distribution_group_test.exs` (new, 9 tests): boundary rules, exactly-one-group, `total_related_activities == 0`, nil-proficiency defense, no-mutation-of-other-fields.
  - `test/oli_web/components/delivery/learning_objectives/expanded_objective_view_test.exs` (updated): replaced the old React-chart assertions with HEEx/SVG assertions; added region selection, re-click-to-deselect, keyboard (Enter) activation, unrelated-keydown-ignored, no-data-mutation-on-selection, and denominator-widening (parent + sub-objective union, verified via a real `resource_summary` attempt) tests.
- [x] Required verification commands run
  - `mix test test/oli_web/components/delivery/learning_objectives/ test/oli/delivery/metrics/ test/oli/delivery/sections_test.exs` → 210 tests, 0 failures.
  - `mix format` on all touched files.
  - `cd assets && yarn lint` → clean.
  - `cd assets && yarn test` → 985/985 individual tests passed; 103 test *suites* fail to load due to a pre-existing Babel/JSX config issue affecting unrelated authoring files (`AccordionTemplate.tsx`, `NonActivities.tsx`, etc.) never touched by this change. Not a regression introduced by this PR — flagged as a residual environment risk, not fixed here (out of scope for this phase).
- [x] Results captured (above)

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no material divergence found; implementation matches `fdd.md` section 4.1/4.2 and `plan.md` Phase 1 (PR1) task list.
- [ ] Open questions added to docs when needed — none new; existing open questions in `prd.md`/`fdd.md` remain as-is.

## Review Loop
- Round 1 findings (5 parallel `.review/*.md`-scoped agents):
  - **security.md**: no findings. One residual risk noted for PR2: when the table starts rendering real student data on `select_student_group`, re-verify that query is scoped to the instructor's own section (object-level authorization) — this PR only toggles local selection state and renders no new data yet.
  - **performance.md**: no findings on the widened denominator (confirmed zero new DB queries) or `StudentDistributionGroup` (pure O(n)). One flagged item: `StudentDistributionMatrix` renders one unbounded `<circle>` per enrolled student with no cap/virtualization — a payload/DOM-size concern for very large sections, not a query-count issue. This overlaps with the already-tracked FDD section 16 open question ("dot-collapsing behavior at high density") — no new open question added, just corroborates the existing one.
  - **elixir.md**: 3 findings, all addressed:
    1. `deselect_student_group/2` was unreachable from any rendered control and untested -> added a doc comment explaining it's PR2's documented future caller (`fdd.md` section 5), and a direct `handle_event/3`-level unit test.
    2. No negative-path test for a tampered/unknown `"group"` value -> added `"an unrecognized group value is ignored instead of selecting anything"`.
    3. Minor idiom inconsistency (`socket.assigns[:x]` vs `Map.get(socket.assigns, :x, default)`) -> unified on `Map.get/2-3`.
  - **ui.md**: 1 high-severity finding, fixed: `role="img"` on the outer `<svg>` forced every descendant into the accessibility tree as presentational, hiding the nested `role="button"` regions (and their `aria-pressed` state) from screen readers -- undermining the ticket's own WCAG 2.1.1/2.4.7 goals for AT users even though physical keyboard focus still worked. Removed `role="img"`, kept `aria-labelledby`/`aria-describedby`. One low-severity residual risk noted (per-student `<title>` tooltips are mouse-hover-only, not keyboard/touch-reachable) -- acceptable for this PR since no per-student detail view exists yet (PR2).
  - **typescript.md**: no findings (clean deletion, no dangling references).
- Round 1 fixes: all applied (see above); full test suite re-run afterward -> 212 tests, 0 failures.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass (backend fully green; frontend Jest has a pre-existing, unrelated environment issue noted above)
- [x] Review completed when enabled (5-checklist round complete, all actionable findings fixed)
- [x] Validation passes (`validate_work_item.py --check all`)

## Visual Fidelity Pass (post-review, on user request)

The user flagged that the first PR1 chart implementation was functionally correct but visually
far from the Figma reference (arbitrary colors, no axis ticks, no count-badge styling). Rebuilt
`StudentDistributionMatrix` against Figma node `349:11083` ("Graph LP/Activity"):

- Region backgrounds now use real Torus tokens: Needs Support = `fill-Fill-fill-danger`
  (`#feebed`, matches the pale pink wash exactly), Excelling = `fill-Fill-Accent-fill-accent-green`
  at reduced opacity, Limited Activity = `fill-Fill-Chip-Gray` at reduced opacity. Selected-state
  border color matches each region's accent.
- Count badge rebuilt as the two-part shape Figma uses: a dark rounded square with a white bold
  number, immediately followed by a white rounded pill with the group label in dark text.
- Dots now colored by each student's `proficiency_range` (Low/Medium/High/Not enough data) via a
  new public `Proficiency.dot_fill_class/1` helper added to
  `lib/oli_web/components/delivery/learning_objectives/proficiency.ex`, reusing the exact same
  token family as the existing proficiency chip -- not by `distribution_group`, matching what the
  Figma reference actually shows (dot color encodes proficiency across all three regions, not
  which region the dot is in).
- Added x-axis percentage ticks (0/25/50/75/100%) and a "LEARNING PROFICIENCY" caps label below
  the plot, and a rotated "ACTIVITY COMPLETION" caps label on the left, matching the reference.
- Verified visually: rendered the component with `Phoenix.LiveViewTest.render_component/2`
  against representative sample data (a scratch ExUnit test, not committed), wrote the output to a
  static HTML page loading the Tailwind CDN with the project's actual token values, and viewed it
  in Chrome via browser automation. Side-by-side comparison against the Figma screenshot showed a
  close match on layout, badge shape, region colors, and axis labels.
- Explicitly **not** pixel-exact: Figma did not expose the region/dot fills as bound Figma
  variables (`get_variable_defs` did not return them), so exact hex values were approximated from
  existing Torus tokens and a visual read of the exported screenshot, not extracted literally. Flag
  for a final designer screenshot-diff before this is considered pixel-final (`fdd.md` section 16
  already tracks the related open questions: exact per-group badge icon, and the checkbox visual).
- Re-ran `mix compile --warnings-as-errors`, `mix format`, and the full
  `learning_objectives`/`metrics` test directories after this pass: 103 tests, 0 failures, no new
  warnings.
- Responsive/mobile layout (chart-above-table stacking on narrow viewports) was discussed and
  deliberately deferred: it depends on the table existing (PR2) to pick a real breakpoint, and
  `prd.md`/`fdd.md` already scope responsive layout as out of this ticket's goals. Noted as a
  decision to make explicitly before Phase 4 (QA), not implemented here. If a real need emerges to
  react to the *container's* width rather than the viewport (e.g. this row rendering in a narrow
  panel on a wide screen), `assets/src/hooks/dashboard_tile_group_resize.ts` (used by
  `student_support_tile.ex`) is the precedent for a `ResizeObserver`-driven
  `data-dashboard-width-mode` pattern already used elsewhere in this codebase -- likely overkill
  for this simpler two-pane case, where a plain Tailwind viewport breakpoint should suffice.

## Tidewave Follow-up Fidelity Iteration

After the initial fidelity pass, a live Tidewave review against the instructor dashboard route
identified additional chart details that were corrected in-place:

- The chart heading now follows the Figma framing as "Student Distribution: N Students" instead of
  "Estimated Learning".
- The chart geometry was enlarged and aligned to the isolated Figma frame proportions
  (`580x532` viewBox), including axis placement and left-side y-axis padding to avoid clipped
  rotated text.
- Dot color semantics were refined: no selected group renders all dots inactive; selecting a group
  activates only that group's dots. Active dots receive the Figma-style white stroke
  (`1.5px`) while inactive dots keep the inactive palette.
- Dot click handling was added so clicking a dot selects/deselects the same group as clicking the
  corresponding region. The global SVG `<title>` was removed to avoid a native browser tooltip over
  empty chart space; per-dot native `<title>` tooltips remain.
- Region count labels render above dots for Figma parity, but the label layer uses
  `pointer-events: none` so hit-testing reaches the dot or region underneath. A small
  `StudentDistributionMatrixLabels` Phoenix hook only fades a label when the mouse is over a label
  that overlaps at least one dot; it does not render chart state or replace the HEEx/SVG chart.
- Additional Figma nodes were inspected for dark mode:
  - `365:19876` confirmed label colors: white pill, black count chip, charcoal label text.
  - `365:19875` confirmed the Limited Activity dark background as `fill/chip-gray` (`#353740`).
  These are mapped through tokens in `assets/tailwind.tokens.js` (`Black-Alpha-000`,
  `Text-text-charcoal`, `Graph-region-limited-activity`).
- Graph dot tokens were mapped for light/dark and active/inactive states for low, medium, high, and
  not-enough-info dots.
- Temporary visual-QA fixture data was added in `ExpandedObjectiveView` and scoped to the "Manage
  mix tasks" LO (`resource_id` `10479`). It preserves the real 62-student count but overrides group,
  proficiency, and activity-completion values so the chart can be visually checked across all three
  regions, including boundary dots near the 50% proficiency/activity thresholds. This is explicitly
  temporary and must be removed before treating the branch as production-ready.

Verification after this follow-up:

- `mix compile --warnings-as-errors`
- `mix test test/oli_web/components/delivery/learning_objectives/expanded_objective_view_test.exs`
  → 22 tests, 0 failures.
- Targeted ESLint/Prettier checks for `assets/src/hooks/student_distribution_matrix_labels.ts` and
  `assets/src/hooks/index.ts` passed.
- `yarn run check-types` still fails on the pre-existing unrelated `gifuct-js` type/module issue in
  `assets/src/components/parts/janus-image/hooks/useGifPlayer.ts`; no new hook-specific type error
  was reported before that blocker.

## Post-Handoff Cleanup

Independently re-verified the entire Tidewave follow-up before closing this out (not just trusting
the handoff summary): full `mix compile --warnings-as-errors` (forced recompile), full relevant
`mix test` run (217 tests, 0 failures), `mix format --check-formatted`, and ESLint/Prettier on the
new hook and `tailwind.tokens.js` — all clean. Confirmed the new `Graph-*`/`Black-Alpha-000` tokens
actually exist with correct light/dark hex values, and that `Proficiency.dot_fill_class/2`'s new
2-arity signature has no stale single-arity callers.

- **Removed the temporary visual-QA fixture** from `ExpandedObjectiveView` (the "Manage mix
  tasks"/`resource_id 10479` override, `visual_qa_*` functions and their three call sites) rather
  than deleting it outright: the exact removed diff (231 lines, isolated to this one file) is
  preserved as a git stash, message `"fixture for testing"`, created via `git commit-tree`/
  `git stash store` so it does not get tangled with this phase's real changes to the same file.
  Verified with `git apply --check` that the stash patch applies cleanly to the current working tree
  before considering this done. Recover it with `git stash list` (find the entry by that message,
  since other unrelated stashes exist on this shared stash stack) then `git stash apply <sha>` (not
  `pop`, per this repo's shared-stash-stack convention) when representative multi-region chart data
  is needed again.
- Full suite re-run after fixture removal: 217 tests, 0 failures (unchanged from before removal,
  confirming no test depended on the fixture).
- Synced `fdd.md` (sections 4.1, 16, 17) with the final shipped design: dot click-to-select, dot
  active/inactive states, the `StudentDistributionMatrixLabels` hover-fade hook (and why it does not
  reopen the HEEx-vs-React decision), Figma-literal-pixel geometry as an explicit starting point
  pending future responsive work, and the graph-specific Figma color variable nodes now backing
  `assets/tailwind.tokens.js`.
- Not yet resolved: whether to keep `handoff.md` as a standalone file or fold it fully into this
  execution record and delete it (its content is already captured above); left as-is pending
  confirmation.

## Review Round 2 (post-Tidewave, post-fixture-removal)

Ran the same 5-checklist review round (`.review/security.md`, `.review/performance.md`,
`.review/elixir.md`, `.review/ui.md`, `.review/typescript.md`) against the full current diff, since
round 1 only covered the pre-Tidewave version of this work.

- **security.md**: no findings. One residual, non-blocking note: click/keydown handlers have no rate
  limiting, so rapid clicking could generate many telemetry events per session — same pattern as
  existing UI event handlers elsewhere in the codebase, low severity given this is an
  authenticated instructor-only view.
- **typescript.md**: no blocking findings. Two minor polish suggestions, both applied: avoid
  double-querying labels per `mousemove` in `updateFadedLabel`, and (not applied, low value) prefer
  `readonly` array return types for `labels()`/`studentDots()`.
- **elixir.md**: no blocking findings. One test-style inconsistency, fixed: two dot-state tests in
  `expanded_objective_view_test.exs` asserted via raw `html =~ "..."` substring matches instead of
  scoping to specific `<circle>` elements via Floki, unlike the sibling test in the same file. One
  documented (not changed) residual: `student_distribution_matrix.ex`'s `Map.fetch!(@regions, group)`
  would raise on an out-of-contract `:distribution_group` — fully guarded today by
  `StudentDistributionGroup.assign/1` always running first at both call sites, worth a note if this
  component is ever reused elsewhere.
- **performance.md**: no query/N+1 issues. One real finding, fixed: `StudentDistributionMatrixLabels`'s
  `updated()` re-scanned every student dot's `getBoundingClientRect()` on **every** LiveView patch of
  the chart -- including a plain `select_student_group` click, which only changes dot fill/stroke
  classes, not dot positions. Added a cheap `cx,cy`-based dot-position signature cached on the hook
  instance; `updated()` now skips the expensive overlap re-scan unless that signature actually
  changed (i.e. the student list itself changed, not just which group is selected).
- **ui.md**: no findings on the new dot `phx-click` (keyboard parity preserved via the region's own
  `tabindex`/`phx-keydown`) or the hover-fade hook (self-corrects every `mousemove`, `pointer-events:
  none` means a "stuck" fade is purely cosmetic even in the worst case). **One real, unresolved
  finding, intentionally not auto-fixed**: dots in the `:inactive` state -- which is every dot's state
  on first load, before any group is selected -- have measured contrast against their own region
  background well under the WCAG 1.4.11 non-text-contrast minimum (3:1) in several cases (e.g. Low
  dots on Needs Support ≈1.6:1 light / 2.0:1 dark; High dots on Excelling ≈1.2:1 light / 2.9:1 dark).
  These colors were read directly from Figma's own graph variables, so this is a design-vs-accessibility
  tension, not an implementation bug -- changing them unilaterally would mean diverging from the
  approved visual design without design/product sign-off. **Flagged as an open risk, not fixed**; see
  `fdd.md` section 15/16. Needs a design decision (darken/saturate the inactive palette, or accept the
  contrast as an intentional "de-emphasized" treatment) before this ships.

Verification after round 2 fixes: `mix format`, `mix compile --warnings-as-errors`, full relevant
`mix test` (217 tests, 0 failures), ESLint/Prettier on the hook file — all clean.

## Doc/Comment Hygiene Pass

On explicit user request, audited every moduledoc, `@doc`, and inline/HEEx comment introduced or
touched on this branch for ticket IDs, session/tool names, PR-sequencing references, and
work-item-doc-path references (`docs/exec-plans/current/.../fdd.md` and similar) -- all of which
either rot once this work item is archived to `docs/exec-plans/archive/`, or otherwise belong in a
PR description rather than the code itself. Found and fixed 7 instances across 4 files:

- `lib/oli/delivery/metrics/student_distribution_group.ex` moduledoc: dropped a `(MER-5814)` ticket
  reference.
- `lib/oli_web/components/delivery/learning_objectives/student_distribution_matrix.ex`: dropped
  `MER-5814` from the moduledoc; replaced a `See fdd.md section 4.4` pointer with the actual
  one-sentence reason inline; dropped a `design/instructor_viz_ui_brief.md` path reference (kept the
  Figma file/node citations themselves -- those are durable design-source provenance, not
  ticket/session history); removed a trailing "See ...phase_1_execution_record.md, UI review round 1"
  sentence from the `role="img"` comment (the preceding sentences already state the reason in full).
- `lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`: reworded the
  `deselect_student_group` handler comment and a matching test comment to explain *why* the handler
  exists without naming "PR2"; replaced an HTML comment citing `fdd.md section 4.4` with a
  self-contained one-line fact; deleted an HTML comment entirely that only described a future PR's
  planned work (not the current code); dropped `MER-5814` from a data-loading comment.
- `test/oli_web/components/delivery/learning_objectives/expanded_objective_view_test.exs`: matching
  reword of the `deselect_student_group/2` describe-block comment.

Also applied the three `change-cleanup` findings from the smart-mode pass immediately before this:
deleted `handoff.md` (never committed, so removed directly rather than via `git rm`), added
`@spec dot_fill_class(String.t() | nil, :active | :inactive) :: String.t()`, and added a
`@moduledoc` to `ExpandedObjectiveView` (which had none before this branch, despite its
responsibility surface changing substantially here).

Re-verified after both passes: `mix format`, `mix compile --warnings-as-errors`, full relevant
`mix test` (217 tests, 0 failures), and a final repo-wide grep for `MER-5814`, `MER-5252`,
`Tidewave`, `handoff`, `review round`, `PR1`/`PR2`/`PR3`, and `exec-plans/current` across every
touched `.ex`/`.ts`/`.exs` file -- clean.

## Telemetry Removed (dead-on-arrival instrumentation)

On user question, verified that the custom `:telemetry.execute/3` call added in this phase
(`select_student_group`/`deselect_student_group`) had no observable effect: grepped every
`:telemetry.attach`/`:telemetry.attach_many` call in the codebase and confirmed the only path from
a custom event to AppSignal is the generic `[:torus, :feature, :exec, :start | :stop |
:exception]` span convention in `lib/oli_web/telemetry.ex`. Nothing attaches a handler for
`[:oli, :instructor_dashboard, ...]`-style events -- including the existing precedent this call was
copied from (`learning_objectives.ex`'s `[:oli, :instructor_dashboard, :challenging_objectives,
:navigation]`), which has the identical problem. As written, the call was pure cost with zero
telemetry value: no AppSignal metric, no log line, nothing observable anywhere.

Removed `emit_group_selection_telemetry/2` and both call sites from `expanded_objective_view.ex`.
Per explicit user direction, also removed the corresponding "add telemetry in PR3"
(Email/Load-More usage) plan and the "confirm telemetry" QA task from Phase 4, and rewrote
`prd.md` section 12 and `fdd.md` section 11 to document the decision *not* to add ad hoc custom
telemetry for this feature, plus why (no wired consumer) -- so this does not get silently
reintroduced in a later phase by someone reading "telemetry defaults to included" out of
`harness.yml` without checking whether anything is actually listening. `harness.yml`'s existing,
already-wired Ecto/Phoenix telemetry (`oli.repo.query.*`, etc.) still covers this feature's
performance-observability needs with zero new code, which is unaffected by this removal.

Re-verified after removal: `mix format`, `mix compile --warnings-as-errors`, full relevant
`mix test` (217 tests, 0 failures — confirming no test depended on the removed telemetry call),
`requirements_trace.py verify_fdd`/`verify_plan`, and `validate_work_item.py --check all`.
