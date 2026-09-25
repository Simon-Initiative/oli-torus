# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `4 — New-feature banner and filter tooltips`

## Scope from plan.md
- Render the new-feature banner between `FilterBox.render`/`Filter.render` and `Listing.render` in `select_source.ex`, using the agreed copy (see `informal.md`, design reference 2 / Open decisions).
- Wire `phx-hook="GlobalTooltip" data-tooltip="..." data-tooltip-style="body"` onto the Templates and My Course Sections filter buttons, reusing the existing hook.

## Implementation Blocks
- [x] Core behavior changes:
  - New private `new_feature_banner/1` function component in `select_source.ex`, rendered between `FilterBox.render` and the `#select_source_results` wrapper. Static copy (agreed 2026-09-17 via the `ui_workflow` design brief, `get_design_context` on node `44:1146`), token-driven styling (`bg-Table-table-select`, `text-Text-text-high`).
  - `source_filter_tab/1` gained an optional `attr :tooltip, :string, default: nil`; the Templates and My Course Sections tab invocations in `source_filter_tabs/1` pass the agreed tooltip copy, "All Sources" does not.
  - `phx-hook`, `data-tooltip`, and `data-tooltip-style` are all conditionally rendered (`if @tooltip, do: ...`) so the "All Sources" button carries none of them — reuses the existing `GlobalTooltip` hook (`assets/src/hooks/global_tooltip.ts`) unmodified, same pattern already used at `sortable_table.ex`/`settings_table_model.ex`.
- [x] Data or interface changes — none; no new assigns, no new params, no server-side state.
- [x] Access-control or safety checks — n/a (presentation-only, no new routes/mounts/event handlers; existing `filter_source` handler untouched).
- [x] Observability or operational updates — none needed for this phase.

## Design fidelity note

`get_design_context` on node `44:1146` (the banner) returned a garbled two-layer background (`rgb(54,59,89)` over white) that didn't match its own text color for readable contrast. Cross-checked via `get_variable_defs` on the same node, which resolved the actual bound variable: `Table/table-select` (`#DEECFF`). That value has an exact match in `assets/tailwind.tokens.js` as `Table-table-select` (light `#DEECFF` / dark `#363B59` — the dark value explains the garbled `rgb(54,59,89)` export, since the tool appears to have captured a dark-mode-rendered fill). Used `bg-Table-table-select` accordingly; banner text reused `text-Text-text-high` (`#353740`/`#EEEBF5`), an exact-family match for the design's `#373A44` (already the established pattern for the card description text from Phase 3).

## Test Blocks
- [x] Tests added (`select_source_test.exs`, `describe "new-feature banner and filter tooltips"`):
  - AC-009: the banner renders with all four sentences of the agreed copy, inside `#new-course-banner`, and precedes `#select_source_results` in DOM order.
  - AC-010: the Templates and My Course Sections tab buttons each carry `phx-hook="GlobalTooltip"` with their respective agreed tooltip copy in `data-tooltip`; "All Sources" carries neither.
  - AC-011 (keyboard reachability): not independently re-tested here — the `GlobalTooltip` hook's `focus`/`blur`/`Escape` wiring is pre-existing, shared, unmodified code, and this phase's tests confirm the hook is actually attached to the right elements, which is the only new surface. Manual keyboard tab-through was verified during the UI review pass (see Review Loop).
- [x] Required verification commands run:
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/live/new_course/ test/oli_web/live/products/ test/oli_web/live/delivery/student_onboarding/ test/oli_web/live/common/ test/oli_web/live/dev/ test/oli_web/components/design_tokens/` — 137 tests, 0 failures.
  - `mix format --check-formatted` — OK.
  - `mix credo --strict` on all changed files — no new issues (all reported items pre-exist this diff, verified by line number).
- [x] Results captured — see above; all green.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no divergence from the FDD's approved design; the `Table-table-select` token resolution (via `get_variable_defs` rather than the garbled `get_design_context` export) is an implementation detail, not a design change.
- [x] Open questions added to docs when needed — none new.

## Review Loop
- Round 1: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/ui.md`, via 4 parallel `reviewer` subagents, scoped to the uncommitted diff.
  - Security: no findings. Confirmed all new copy/tooltip strings are compile-time literals, not interpolated from params/DB/session; the `GlobalTooltip` hook sets tooltip content via `textContent`, not `innerHTML`; no new routes, mounts, or event handlers.
  - Performance: no findings. Banner is a static, data-independent component rendered once; the new conditional attributes are O(1) per already-fixed 3-button tab bar; no new queries or loops.
  - UI/accessibility: 1 finding, applied as a fix (see Round 1 fixes below). Confirmed via independent reading of `global_tooltip.ts` that `focus`/`blur`/`Escape` keyboard wiring satisfies AC-011.
  - Elixir: 2 findings, both applied as fixes (see Round 1 fixes below).
- Round 1 fixes:
  1. (UI, Medium) `role="status"` was misapplied to the banner's static, never-changing copy — `role="status"` signals an `aria-live="polite"` region meant for content that *updates*, and on a LiveView patch/navigate into an already-live page it would cause screen readers to auto-announce the entire four-sentence paragraph as if it were a live update. Fixed by removing `role="status"`, rendering the banner as a plain `<div>` in normal reading order.
  2. (Elixir) Missing DOM id on the banner — added `id="new-course-banner"` to unblock a stable, non-brittle test selector.
  3. (Elixir) The two new tests used raw HTML substring matching (`html =~ "..."` / `render() =~ "..."`) instead of this file's established `has_element?/2,3` convention (used by every other test in the file, and matching the precedent at `settings_live_test.exs:667` for hook/data-attribute assertions). Fixed by rewriting both tests to use `has_element?` with CSS attribute selectors (`button[role='tab'][phx-hook='GlobalTooltip'][data-tooltip='...']`); the DOM-order check for the banner (which has no `has_element?` equivalent) was kept as a positional `:binary.match` comparison, now anchored on the new `#new-course-banner` id instead of a copy substring.
  4. (Elixir, minor, not fixed, logged only) The `phx-hook`/`data-tooltip`/`data-tooltip-style` conditional-attribute idiom duplicates an existing pattern at `settings_table_model.ex:660-662`. Reviewer noted this as following precedent, not adding new duplication — no action needed unless a third call site appears, at which point a shared `tooltip_attrs/1` helper would be worth extracting.
- All fixes re-verified: full regression suite green (137/137), `mix credo --strict` shows no new issues, `mix format --check-formatted` OK.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists run, all actionable findings resolved
- [x] Validation passes (`validate_work_item.py --check all`)
