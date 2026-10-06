# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `2 — Filter tabs (All Sources / Templates / My Course Sections)`

## Scope from plan.md
- Add `@params.source_filter` and a tab-bar UI above `FilterBox.render` for All Sources / Templates / My Course Sections.
- Extend `filter/3` with a `source_filter`-narrowing pass before the existing text-query pass.
- Each tab keyboard-operable, with an accessible name and selected/`aria-selected` state.
- No change to `retrieve_all_sources/2`, no new row-typing scheme, no card/hover work (Phase 3), no steps 2/3, no `Stepper` changes.

## Design fidelity note
Before implementing, pulled `get_design_context` for the actual filter-tab row (Figma nodes `44:746`–`44:748`, `74:3907`), which had not been fetched during the `ui_workflow` plan phase. Confirmed the row is genuinely three tab buttons (not a dropdown, despite the Figma layer name "Drop-down filter"), with exact colors that map 1:1 to existing tokens already used elsewhere in the design: active — border/text `Text-text-button`; inactive — border `Border-border-default`, text `Text-text-high`; both on `Background-bg-primary`. No new token gaps found for this component.

## Implementation Blocks
- [x] Core behavior changes:
  - `@default_params` gains `source_filter: :all`.
  - New `handle_event("filter_source", %{"filter" => filter}, socket)` maps the client string to `:all | :templates | :my_sections` via an explicit `case` (never `String.to_atom`), resets `params.offset` to `0`, and delegates to a new shared `update_source_list/3` helper.
  - `filter/3` refactored into `filter_by_source_type/2` (new) + `filter_by_query/2` (renamed from the inline case), narrowing by `TableModel.tag_variant/1` (`:template`/`:my_section`) before the text search.
  - New `source_filter_tabs/1` / `source_filter_tab/1` private function components render the 3-tab bar above `FilterBox.render`.
- [x] Data or interface changes — none to `retrieve_all_sources/2`, `TableModel`, `CardListing`, or `Stepper`; `filter/3`'s new first pass is additive.
- [x] Access-control or safety checks — n/a for this phase (presentation/filtering only over an already-authorized in-memory list).
- [x] Observability or operational updates — none needed yet (telemetry is Phase 6 scope per plan.md).

## Test Blocks
- [x] Tests added: 3 new LiveView tests in `select_source_test.exs`, `describe "source filter tabs"`:
  - "renders all three tabs with accessible names and the correct selected state" (AC-001)
  - "changing the active tab does not reset the previously selected sort order" (AC-002)
  - "a search performed under one tab never returns rows belonging to a different tab" (AC-003)
- [x] Required verification commands run:
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/live/new_course/ test/oli/delivery/section_creation_test.exs test/oli_web/live/delivery/student_onboarding/` — 82 tests, 0 failures (includes the 3 new tests plus the full existing regression baseline, including the `Stepper`-sharing regression coverage).
  - `mix format --check-formatted` — OK.
  - `mix credo --strict` on the changed file — no new issues; all reported items are pre-existing and outside this diff (verified by line number).
- [x] Results captured — see above; all green.

## Bugs found and fixed during implementation
- `aria-selected={@active}` (a raw Elixir boolean bound to a HEEx attribute) renders as a bare boolean-style HTML attribute (present when `true`, omitted when `false`) rather than the ARIA-required string `"true"`/`"false"`. Caught by the first test run (AC-001 test failed), not by static review. Fixed to `aria-selected={to_string(@active)}`.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no divergence; `filter/3`'s split into `filter_by_source_type/2`/`filter_by_query/2` and the `update_source_list/3` extraction are implementation details within the FDD's already-approved design, not a design change.
- [x] Open questions added to docs when needed — none new; the pending "Template" vs. "Free" tag question (Phase 3 scope, already logged) is unaffected by this phase.

## Review Loop
- Round 1: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/ui.md` (new accessible UI introduced), via 4 parallel `reviewer` subagents.
  - Security: no findings. `filter_source` maps client input through a closed, deny-by-default `case` (no `to_atom`/`to_existing_atom`); `source_filter` has no alternate untrusted entry path (no `handle_params`/query-string ingestion).
  - Performance: no findings. New filter pass is one more `O(n)` `Enum.filter` over the same already-in-memory, already-authorized list; no new query.
  - Elixir: 5 findings, all applied as fixes (see below).
  - UI/accessibility: 2 real findings, both applied as fixes (see below); 1 informational (no roving tabindex — consistent with every other `role="tab"` usage already in this repo, no action needed); 1 confirmed-correct note (the `to_string(@active)` fix); 1 low/optional note (35px tab height vs. 44px touch-target guidance) left as-is, since it matches both the Figma spec exactly and this same file's existing view-toggle button height.
- Round 1 fixes:
  1. (Elixir) Extracted `update_source_list/3` to de-duplicate the "recompute table_model/total_count, then assign" block that `filter_source` would otherwise have made a 5th near-identical copy of; `apply_search`, `reset_search`, `sort`, `page_change`, and the `update/2` selection branch now all route through it.
  2. (Elixir) Line 46 now uses the `TableModel` alias consistently instead of a stray fully-qualified reference.
  3. (Elixir) `filter_source` now resets `params.offset` to `0`, preventing a stale-pagination empty page when switching tabs from page 2+.
  4. (Elixir) Renamed the misleading `_all_sources` catch-all clause (which actually matches any unrecognized value, not just "all") to `_other_filter` in both `filter_by_source_type/2` and the `filter_source` handler's `case`.
  5. (Elixir) `params[:source_filter]` → `params.source_filter` in `filter/3` for access-style consistency with the adjacent `params.applied_query`.
  6. (UI) Added a non-color cue for the active tab (`bg-Fill-Accent-fill-accent-blue` fill, an existing token already used for "accent blue" surfaces in this design) alongside the border/text color change, so the selected state isn't communicated by color alone.
  7. (UI) Wired `id`/`aria-controls` from each tab to the results region: each tab gets a stable `id="source-filter-tab-<filter>"` and `aria-controls="select_source_results"`; the `Listing.render` output is now wrapped in `<div id="select_source_results">`, matching the pattern used elsewhere in the repo (`clickhouse_backfill_live.ex`, `institutions/index_live.ex`) for associating tabs with the region they affect. (Did not add `role="tabpanel"` to that region — these are filter tabs narrowing one continuously-visible list, not content-switching tabs with per-tab hidden/shown panels, so the `tabpanel` show/hide semantic would misrepresent the actual behavior; the reviewer's own alternative suggestion — id/aria-controls wiring without forcing the full panel-per-tab pattern — was followed instead.)
- All fixes re-verified: full regression suite green (82/82), `mix credo --strict` shows no new issues, `mix format --check-formatted` OK.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists run, all findings resolved
- [x] Validation passes (`validate_work_item.py --check all`)
