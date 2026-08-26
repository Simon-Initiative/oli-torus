# Phase 5 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `5` — Group B Batch 2: Content "Order" Column + Container Navigators (FR-005, FR-006)

## Scope from plan.md
- FR-005: overlay `decorated_numbering_map/1` onto `Sections.get_units_and_modules_containers/1`'s raw SQL result.
- Update `content_table_model.ex`/`content.ex` to treat a `nil` `numbering_index` as "no number".
- FR-006: overlay `decorated_numbering_map/1` onto `list_navigator.ex`'s two container-navigator data sources.
- Add a `numbering_index: nil` clause to `list_navigator.ex`'s `item_prefix/2`.
- Check for repeated `decorated_numbering_map`-touching calls within a mount (FDD Section 8 pattern).

## Implementation Blocks
- [x] Core behavior changes:
  - `Sections.get_units_and_modules_containers/1` (`lib/oli/delivery/sections.ex`): signature changed from `section_slug :: String.t()` to `%Section{}`; overlays suppression-aware `numbering_index` via a private `overlay_suppression_aware_index/2`, leaving `numbering_level` untouched.
  - New public `Sections.overlay_suppression_aware_numbering/2`: overlays a list of `%SectionResource{}` structs. Both this and `overlay_suppression_aware_index/2` delegate to a shared private `overlay_numbering_index/3` (key-extraction function parameter), extracted during this phase's review to close a duplication finding.
  - `list_navigator.ex`'s `item_prefix/2`/`item_title/2`: gained (then combined into a single guarded clause) handling for `numbering_index: nil` alongside the existing `-1` sentinel.
  - `intelligent_dashboard_tab.ex`'s `fetch_dashboard_containers/1`: applies the overlay. The membership-check-only caller (`valid_container_id?/3`'s fallback) was given its own dedicated `dashboard_container_resource_ids/1` helper instead of a second `fetch_dashboard_containers/1` clause dispatching on argument shape, closing a review finding.
  - `instructor_dashboard_live.ex`: two more raw-numbering sources found and fixed mid-phase (see divergence note) — `do_handle_students_params/3`'s `navigator_items` (both branches) and the Learning Objectives tab's `navigator_items`.
  - `helpers.ex` / `student_dashboard_live.ex`: their own `get_containers/2` functions updated to pass `section` (struct) instead of `section.slug` to the now-`%Section{}`-accepting `get_units_and_modules_containers/1`.
- [x] Data or interface changes: `get_units_and_modules_containers/1`'s first-argument type changed (additive in effect — both real callers already had the struct in scope).
- [x] Access-control or safety checks: N/A — display-only change; confirmed by security review that the `fetch_dashboard_containers/1` split (pre-fix) never bypassed authorization.
- [x] Observability or operational updates: N/A for this phase.

## Divergence 1 — FR-006's real scope was 3 call sites, not 1 (significant, worth recording)
The plan's task list, following the FDD's Section 4.1 component list, named only `intelligent_dashboard_tab.ex`'s `fetch_dashboard_containers/1` as FR-006's remaining raw-numbering source (`helpers.ex`'s `get_containers/2` was already covered "for free" via FR-005). But FR-006/AC-011 itself names four navigator surfaces: Content, Learning Objectives, Student Insights, and Intelligent Dashboard. Reading `instructor_dashboard_live.ex` found two more real, independent sources feeding the same `list_navigator.ex` component with raw, unsuppressed numbering: `do_handle_students_params/3`'s `navigator_items` (serves both the plain "Students" tab and the Content-tab container drill-down — and therefore Student Insights too, since it's the same `Students` LiveComponent) and the Learning Objectives tab's `navigator_items`. Both were fixed using the same `Sections.overlay_suppression_aware_numbering/2` helper built for the originally-planned site — same fix pattern, three call sites instead of one.

## Divergence 2 — AC-010 needed no code change (significant, worth recording)
The plan assumed `content_table_model.ex`/`content.ex` needed updates to treat `nil` `numbering_index` as "no number." Reading `SortableTableModel`/`ColumnSpec` (`lib/oli_web/live/common/table/`) showed this was already true: the "Order" column has no `render_fn` (falls back to `Map.get(row, :numbering_index)`), and `Phoenix.HTML.Safe`'s `Atom` implementation already renders `nil` as an empty string; `content.ex`'s default `Enum.sort_by/3` is nil-safe via Erlang's standard term ordering. No production code was changed for AC-010 — verified with a new test instead of left as an untested assumption.

## Regression found and fixed — nil-root sections recur (same class as Phase 4, not a new investigation)
Running the full Phase 5 combined test suite surfaced ~15 pre-existing tests crashing with the same `FunctionClauseError` in `decorated_numbering_map/1` already root-caused in Phase 4 (a section with no populated `SectionResource` rows, which is structurally impossible via any real production section-creation flow). All were test-fixture issues, fixed at the fixture per the Phase 4 precedent (no new production guard added):
- `test/oli_web/controllers/delivery_controller_test.exs`: `setup_lti_session/1` (same fixture Phase 4 already fixed once — this run exercised more of it through the newly-added navigator call sites).
- `test/oli_web/live/delivery/instructor_dashboard/insights/students_tab_test.exs`: `setup_instructor_certificates/1`, `setup_enrollments_view/1`, and one inline `insert(:section)` — all fixed via a new local `insert_section_with_resources/1` helper (minimal Factory-built project/publication + `create_section_resources/2`).
- `test/oli_web/live/delivery/instructor_dashboard/insights/learning_objectives_tab_test.exs`: "loads correctly when there are no objectives" — switched to `Seeder.base_project_with_larger_hierarchy/0` (real section resources, zero objective-type resources, matching the test's actual intent).

## Test-clarity fix (raised by user code review, swept across all phases) — separate from the above
A user review comment on Phase 4's `helpers_test.exs` identified that its suppression test used `Oli.Seeder.base_project_with_larger_hierarchy/0`, whose container titles ("Module 1", etc.) are indistinguishable from the *numbered* label format those surfaces render — an assertion like `container_label == "Module 1"` can't prove suppression worked vs. silently not applying. Fixed `helpers_test.exs` with an `Oli.Factory`-built fixture using unambiguous titles ("Introduction to Math", "Statistics Basics") plus explicit `refute`s against the numbered form. A follow-up audit (agent-driven, all Phase 1-5 test files) found one more real instance: `test/oli/instructor_dashboard/oracles/concrete_oracles_test.exs`'s "ScopeResources oracle" describe block (Phase 2) — worse than the `helpers_test.exs` case, since `Oracles.ScopeResources`'s numbered format has no title component at all (`"{Level} {Index}"`), making it byte-identical to the bare-title fallback for that fixture regardless of a companion `refute`. Fixed with a describe-block-local `Oli.Factory` fixture (the shared module-level `Oli.Seeder` setup feeds several unrelated describe blocks in the same file, so it was left untouched) using titles like "Foundations" / "Basic Geometry" that can't be confused with any numbered format. All other test files audited were confirmed already clean (unambiguous titles, or assertions on numeric fields only).

## Test Blocks
- [x] Tests added:
  - `test/oli/delivery/sections_test.exs` — `describe "get_units_and_modules_containers/1"` (2 tests) and `describe "overlay_suppression_aware_numbering/2"` (2 tests).
  - `test/oli_web/components/delivery/list_navigator_test.exs` — 1 new test (`numbering_index: nil` handling).
  - `test/oli_web/live/delivery/instructor_dashboard/insights/content_tab_test.exs` — 1 new test (Order column + Content-drill-down navigator suppression).
  - `test/oli_web/live/delivery/instructor_dashboard/insights/learning_objectives_tab_test.exs` — 1 new test (Learning Objectives navigator suppression) + 1 fixture fix.
  - `test/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab_test.exs` — `describe "navigator_items/1"` (1 test).
  - `test/oli_web/live/delivery/instructor_dashboard/insights/students_tab_test.exs` — fixture fixes only (no new suppression test; this file isn't part of the numbering feature's own surface).
  - `test/oli_web/live/delivery/instructor_dashboard/helpers_test.exs` (Phase 4 file) — rewritten fixture (test-clarity fix, this phase).
  - `test/oli/instructor_dashboard/oracles/concrete_oracles_test.exs` (Phase 2 file) — rewritten fixture for one describe block (test-clarity fix, this phase).
- [x] Required verification commands run:
  - `mix format` on all touched files.
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli/delivery/sections_test.exs test/oli_web/components/delivery/list_navigator_test.exs test/oli_web/components/delivery/learning_objectives/ test/oli_web/live/delivery/instructor_dashboard/ test/oli_web/live/delivery/student_dashboard/ test/oli_web/controllers/api/scheduling_controller_test.exs test/oli_web/live/grades_live_test.exs test/oli_web/live/sections/assessment_settings/settings_live_test.exs test/oli_web/controllers/delivery_controller_test.exs test/oli/instructor_dashboard/oracles/concrete_oracles_test.exs` — 641 tests, 0 failures (re-run twice after seeing a handful of `DBConnection`-ownership failures under concurrent load; second run 0 failures, confirming pre-existing infra flakiness, same class seen in every earlier phase — not this diff).
  - `mix format --check-formatted` — clean.

## Work-Item Sync
- [x] FDD updated: Section 4.1 (component list gains the three Phase 5 call sites and the new `overlay_suppression_aware_numbering/2`/`overlay_numbering_index/3` helpers), Section 13 (AC-009/AC-010/AC-011 testing notes corrected), Section 16 (four new notes: nil-root recurrence, FR-006 scope divergence, AC-010 no-code-change finding, the test-clarity pattern swept across phases).
- [x] plan.md: Phase 5 marked `[COMPLETE]`, tasks/testing tasks checked off with implementation notes, two "Implementation note"-style divergence callouts, Review Notes subsection added.
- [x] Open questions added to docs when needed: yes, all four noted above, in FDD Section 16.

## Review Loop
- Round 1 (three parallel `harness-review` subagents — security, performance, elixir — diff scoped to only Phase 5's changes; `lib/oli/delivery/sections.ex` explicitly scoped to just `get_units_and_modules_containers/1` and `overlay_suppression_aware_numbering/2`, already-reviewed functions excluded). First launch failed for all three agents due to an org-wide spend limit; re-launched successfully after the limit reset.
  - Security: no findings — confirmed the (pre-fix) `fetch_dashboard_containers/1` shape-based dispatch never bypassed authorization, since neither clause performs authz itself and both only ever receive an already-scoped section id.
  - Performance: no findings — confirmed every call site hoists `decorated_numbering_map/1`/`overlay_suppression_aware_numbering/2` outside any loop; confirmed `do_handle_students_params/3`'s `navigator_items` was already computed unconditionally pre-diff, so the added overlay is marginal cost, not new baseline work.
  - Elixir: four findings, all addressed:
    1. Duplicated overlay branching between `overlay_suppression_aware_numbering/2` and `overlay_suppression_aware_index/2` — fixed by extracting shared `overlay_numbering_index/3` (key-extraction function param).
    2. `fetch_dashboard_containers/1`'s shape-driven (`%Section{}` vs. bare `%{id: ...}`) dispatch flagged as a hidden-bug risk (a future caller could silently lose suppression-awareness) — fixed by giving the membership-check caller its own `dashboard_container_resource_ids/1` function, collapsing `fetch_dashboard_containers/1` back to a single always-overlaid clause.
    3. `list_navigator.ex`'s duplicated `-1`/`nil` clause bodies — combined via `when idx in [-1, nil]`.
    4. `decorated_numbering_map/1` computed twice per request in `do_handle_students_params/3` — accepted, not fixed (documented rationale: already-cleared by the performance review as cheap Depot-cache-backed work; a real fix would require threading a pre-computed map through `Helpers.get_containers/2`'s public signature, rippling to its other caller for marginal gain).
  - Re-verified with the full Phase 5 test suite post-fix: still 641 tests, 0 failures (aside from the confirmed-flaky DBConnection noise). `mix compile --warnings-as-errors` and `mix format --check-formatted` both clean.
- Round 2: not needed — all actionable findings were resolved in round 1's fix pass with no new issues introduced.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (three-checklist round run, all findings resolved or explicitly accepted with rationale)
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
