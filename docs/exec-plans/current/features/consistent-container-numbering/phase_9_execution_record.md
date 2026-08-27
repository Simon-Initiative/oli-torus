# Phase 9 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `9` — Post-Closeout Manual QA: Navigator Ordering + a Missed Surface

## Scope from plan.md
- Close out findings from a manual QA pass performed after Phase 8's closeout, using the
  `manual_qa.md` walkthrough this phase also produced, against a section with a suppressed
  *middle* top-level unit.
- Fix a recurring "sorted by a now-nullable `numbering_index`" defect found on three
  navigator/table surfaces.
- Fix one real surface -- the Student Dashboard's own Learning Objectives tab -- that the
  original FDD audit never covered.

## How this phase started
Phases 1-8 verified, per surface, that a suppressed container shows the *correct number*
(or no number). None of that work directly tested *row order* for a suppressed container
relative to its siblings. Manually walking through `manual_qa.md` against a 3-unit fixture
(the middle unit suppressed) surfaced four distinct problems the phase-by-phase automated
tests hadn't caught, because each phase's own tests checked labels, not list order.

## Implementation Blocks

### Finding 1 -- Content tab "Order" column sorts by the wrong field
`lib/oli_web/components/delivery/content/content.ex`'s `sort_by/3` sorted table rows by
`container.numbering_index` -- the same, already-suppression-overlaid field shown in the
"Order" cell. For a suppressed container that field is `nil`, and Elixir's default term
ordering places `nil` after every integer. Verified empirically (`Enum.sort_by(data, & &1.x,
:asc/:desc)` on a 3-item list with one `nil`): ascending pushes the suppressed row to the
**end**, descending pushes it to the **start** -- confirmed live in the running app before
fixing.

- [x] `lib/oli/delivery/sections.ex`: `get_units_and_modules_containers/1`'s query (and its
  `get_pages/1` fallback, used when a section has no containers) now also selects
  `document_index: sr.numbering_index` -- the raw, never-suppressed value, captured before
  the overlay can null it -- alongside the (still suppression-aware) `numbering_index`.
- [x] `lib/oli_web/components/delivery/content/content.ex`: `sort_by/3`'s `:numbering_index`
  clause now sorts by `container.document_index`, with an explanatory comment (requested
  directly) distinguishing row order (`document_index`, never `nil`) from the displayed
  number (`numbering_index`, `nil` for a suppressed row).

### Finding 2 -- Intelligent Dashboard's scope dropdown, same defect one level up
`intelligent_dashboard_tab.ex`'s `flatten_dashboard_containers/1` sorted the root
containers (units) by their own (already-overlaid) `numbering_index` before recursively
flattening each unit's modules in -- so a suppressed unit, and everything nested under it,
got pushed to the end of the whole list.

*(The fix described immediately below was this finding's first pass, made before Finding 3
introduced a shared `Sections` function. It was superseded later in this same phase, after
the review round -- see "Finding 2 initially accepted... then closed" under Review Loop --
by deleting this file's own duplicated tree-flatten logic entirely and calling
`Sections.overlay_and_order_containers_by_document_position/2` directly. Left here for the
narrative of how the fix evolved, not as the final state of the code.)*

- [x] `fetch_dashboard_containers/1` now returns `{overlaid_containers, document_order}`,
  where `document_order` maps each container's `id` to its raw index, captured before the
  overlay runs.
- [x] `flatten_dashboard_containers/2` (arity bumped) sorts roots by `document_order`
  instead of the containers' own `numbering_index`. Each root's own descendants are still
  appended via `flatten_dashboard_container/2`, unchanged, since it already follows the
  container's `children` list (document order) rather than sorting.
- [x] `navigator_items/1` (public, unchanged signature) updated to thread the new
  `{containers, document_order}` tuple through.

### Finding 3 -- Learning Objectives / Content tab navigator mixes levels
A related but distinct defect, found by comparing the Instructor Dashboard's "Content" tab
container-navigator dropdown against its Learning Objectives tab dropdown side by side and
noticing they didn't render the same relative order for the same course. Root cause:
`SectionResourceDepot.containers/2`'s own internal `Enum.sort_by(& &1.numbering_index)`
sorts units and modules together in one flat list by an index that resets per level (a
unit and a module can share the same raw index number), so unrelated containers can
interleave -- e.g. a suppressed unit's second module rendering after the *next* unit
entirely. This part of the defect is **not** suppression-specific -- it reproduces
identically with nothing suppressed at all -- but suppression makes it far more visible
(a whole subtree jumping position), and fixing it is the same underlying "order by document
position" work as Findings 1-2, so it's grouped here rather than deferred.

- [x] `lib/oli/delivery/sections.ex`: new public
  `overlay_and_order_containers_by_document_position/2` -- overlays suppression-aware
  numbering (same as `overlay_suppression_aware_numbering/2`) and reorders the result into
  true document/tree order: roots (containers with no parent present in the given list)
  sorted by their own raw index, each one's descendants immediately following it, also in
  document order. Falls back gracefully to a flat raw-index sort when the input is a
  partial list with no parent/child relationships present (e.g. a single-level query).
- [x] `lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex`: all
  three call sites that previously called `Sections.overlay_suppression_aware_numbering/2`
  directly for navigator state (`do_handle_students_params/3`'s two branches, and the
  Learning Objectives `handle_params/3` clause) now call the new function instead.

### Finding 4 -- Student Dashboard's own Learning Objectives tab has no overlay at all
Found manually testing `/student_dashboard/:student_id/learning_objectives` (a real, live
URL, checked directly): a suppressed unit showed its **raw** number (e.g. "Unit 2" instead
of no number), and the unit after it showed **its** raw number too (e.g. "Unit 3" instead
of the renumbered "Unit 2") -- not an ordering bug, the *number itself* was wrong.

Root cause: `student_dashboard_live.ex`'s `handle_params/3` clause for
`"active_tab" => "learning_objectives"` built `navigator_items` from plain
`SectionResourceDepot.containers/2` output, with no overlay call whatsoever. This is a
different LiveView module from the Instructor Dashboard's Learning Objectives tab (fixed in
Phase 5) -- the FDD's Group B audit (Section 4.1) enumerated only the Instructor
Dashboard's four navigator surfaces and never covered this separate, similarly-named
Student Dashboard one.

- [x] `lib/oli_web/live/delivery/student_dashboard/student_dashboard_live.ex`: wired in
  `Sections.overlay_and_order_containers_by_document_position/2` (same fix as Finding 3,
  since this call site has the identical raw-`containers/2` shape).

### Regression found while re-testing (not a new investigation)
Re-running the full suite after Finding 4's fix surfaced one failure:
`test/oli_web/live/delivery/student_dashboard/components/learning_objectives_tab_test.exs`'s
"loads correctly when there are no objectives" crashed inside `decorated_numbering_map/1`
(`FunctionClauseError` in `DeliveryResolver.hierarchy_node_with_children/2`). Same root
cause diagnosed and fixed repeatedly in Phases 4-5: the test's fixture was a bare
`insert(:section, ...)` with zero populated `SectionResource` rows -- previously harmless
here because this call site never touched suppression-aware numbering; now unsafe since it
does. Confirmed (again) this state cannot occur via any real section-creation flow (both
real creation paths wrap section + section-resources creation in one transaction). Fixed at
the fixture, switching to `Oli.Seeder.base_project_with_larger_hierarchy/0` -- no defensive
guard added to production code, consistent with every earlier occurrence of this same class
of fixture bug in this work item.

## Test Blocks
- [x] Tests added/updated, each using a dedicated 3-unit `Oli.Factory` fixture (Alpha /
  Beta / Gamma, Beta suppressed -- the middle unit, chosen deliberately over the first, to
  prove both "units before stay put" and "units after shift down" in one fixture):
  - `test/oli_web/live/delivery/instructor_dashboard/insights/content_tab_test.exs` -- new
    test asserting row order matches document order in both `sort_order: :asc` and `:desc`.
  - `test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs` --
    new test asserting `navigator_items/1`'s item order.
  - `test/oli/delivery/sections_test.exs` -- new `describe
    "overlay_and_order_containers_by_document_position/2"` (3 tests: no-suppression parity,
    suppressed-middle-unit document order, and a units+modules fixture proving the
    recursive "flatten a root's children immediately after it" branch -- added post-review,
    see Review Loop below).
  - `test/oli_web/live/delivery/instructor_dashboard/insights/learning_objectives_tab_test.exs`
    -- new test asserting the container navigator dropdown's item order.
  - `test/oli_web/live/delivery/student_dashboard/student_dashboard_live_test.exs` -- new
    `describe "learning_objectives"` block (this LiveView had no test coverage for this
    tab's navigator at all before this phase), asserting both suppression-aware labels and
    document order.
- [x] Required verification commands run:
  - `mix format` on all touched files.
  - `mix compile --warnings-as-errors` -- clean.
  - Full `mix test` (not just targeted modules), run twice: **26 doctests, 8449-8453 tests,
    0 failures attributable to this phase** -- two pre-existing, unrelated flaky tests
    (`attempt_controller_test.exs`, `discussions_live_test.exs`) surfaced once each across
    the two runs; neither references `document_index` or
    `overlay_and_order_containers_by_document_position` anywhere in their call stacks.
  - `mix format --check-formatted` -- clean.

## Review Loop
- Round 1 (three parallel `harness-review` subagents -- `.review/security.md` +
  `.review/performance.md` + `.review/elixir.md` -- diff scoped to Phase 9's changes only;
  `decorated_numbering_map/1`/`overlay_suppression_aware_numbering/2` excluded as
  already-reviewed in Phase 1):
  - Security: no findings. Confirmed the `document_order`/`document_index` lookups can
    never mix data across sections (both built from the same single-section `containers`
    list used in the same function call), no authorization check was touched, and the raw
    (never-suppressed) index is used only as a sort key -- never returned to a template or
    exposed to a user who shouldn't see it (display always reads the still-suppression-aware
    `numbering_index`).
  - Performance: no findings. Confirmed no N+1, no query moved out of
    `SectionResourceDepot`'s cache, and the new lookup maps (`document_order`,
    `containers_by_id`, `child_ids`) are each built once per call, giving the new
    tree-flatten helpers O(n) total cost, not worse than the code they replaced.
  - Elixir: two findings.
    1. **Medium** -- every new test used a fixture with 3 sibling units and zero module
       children, so the recursive "flatten a root's children in immediately after it"
       branch of `order_by_document_position/2`/`flatten_by_document_position/2`
       (`sections.ex`) and its twin in `intelligent_dashboard_tab.ex` was never actually
       exercised by a multi-level fixture, even though two of the three fixed call sites
       (`instructor_dashboard_live.ex`, `student_dashboard_live.ex`) query units *and*
       modules together in production.
    2. **Low/Medium** -- real duplication between `sections.ex`'s
       `order_by_document_position/2` + `flatten_by_document_position/2` and
       `intelligent_dashboard_tab.ex`'s `flatten_dashboard_containers/2` +
       `flatten_dashboard_container/2`: near-line-for-line identical "sort roots, then
       recurse via `children`" logic, not shared. Suggested as a follow-up ticket, not a
       blocking fix, since Phase 9 deliberately left Phase 5/8's existing
       `intelligent_dashboard_tab.ex` code untouched to keep this a narrowly-scoped bug fix.
- Round 1 fixes:
  - Closed finding 1: added a new test to `test/oli/delivery/sections_test.exs`'s
    `describe "overlay_and_order_containers_by_document_position/2"` block, with a
    dedicated 3-units-with-1-module-each fixture (the suppressed unit's module included),
    asserting each module lands immediately after its own parent unit and that both the
    suppressed unit *and* its module carry `numbering_index: nil`. Re-ran
    `mix test test/oli/delivery/sections_test.exs` post-fix: 104 tests, 0 failures.
  - Finding 2 initially accepted as a scoped follow-up (see below), then closed in a
    follow-up discussion after the review: confirmed `intelligent_dashboard_tab.ex`'s
    duplicated logic predates this work item entirely (introduced in commit `4d37822531`,
    ticket MER-5248, "Global filter navigation learning dashboard" -- unrelated to
    MER-5871), and that `navigator_item/1` (the per-container formatting step fused into
    the duplicated recursion) only reads fields off a single container, with no tree
    awareness of its own. That meant `intelligent_dashboard_tab.ex` could call
    `Sections.overlay_and_order_containers_by_document_position/2` directly (overlay +
    document order in one step) and simply `Enum.map(&navigator_item/1)` the result, with
    no new module or shared-helper extraction needed -- the shared function this phase
    already added to `Sections` was already the right place. Deleted
    `fetch_dashboard_containers/1`'s manual overlay+`document_order`-map construction,
    `flatten_dashboard_containers/2`, and `flatten_dashboard_container/2` outright;
    `navigator_items/1`'s public signature and return value are unchanged. Verified against
    both the direct unit tests (`describe "navigator_items/1"`, 2 tests) and full LiveView
    integration tests that navigate real `insights/dashboard?dashboard_scope=...` routes
    (`instructor_dashboard_live_test.exs`, `intelligent_dashboard_tab_save_flow_test.exs`):
    98 tests, 0 failures before and after the refactor (confirmed the pre-refactor baseline
    run first, to rule out a masked regression).
- Round 2: not needed -- both findings closed with no new issues introduced.

## Work-Item Sync
- [x] plan.md: Phase 9 added and marked `[COMPLETE]`.
- [x] `manual_qa.md` (this work item's manual QA walkthrough) corrected in place multiple
  times during this process as real discrepancies between its written expectations and the
  actual running app were found -- see its own content for the current, verified-accurate
  navigation and expected values.
- [x] Open questions/follow-ups: none -- the review's finding 2 (see Review Loop above) was
  closed rather than deferred once it was confirmed a fix required no new module, just
  calling the shared function this phase already added.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (three-checklist round run, one actionable finding resolved, one
  accepted as a scoped, documented follow-up)
- [x] Validation: manually re-verified against the running app (the same section/URLs used
  to originally find each bug) in addition to automated tests. After all fixes and the
  review round landed, the full `manual_qa.md` walkthrough (Parts 1 and 2, all 9 numbered
  views, both sort directions where applicable) was re-run end-to-end against a live
  Course A/Course B pair and passed -- no further discrepancies found.
