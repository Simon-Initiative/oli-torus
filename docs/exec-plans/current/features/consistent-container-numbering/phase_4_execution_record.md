# Phase 4 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `4` — Group B Batch 1: Scheduling Editor, Instructor Dashboard Pages + CSV (FR-003, FR-004)

## Scope from plan.md
- FR-003: overlay `decorated_numbering_map/1` onto `scheduling_controller.ex`'s serialized `numbering_index`/`numbering_level`.
- FR-004: overlay `decorated_numbering_map/1` onto `instructor_dashboard/helpers.ex`'s `return_page/3` container labels.
- Confirm `delivery_controller.ex`'s `format_page_title_for_csv/1` needs no direct change.
- Close the Phase 3-documented Grade Sync direct-coverage gap (AC-004) as part of this phase's testing pass.

## Implementation Blocks
- [x] Core behavior changes:
  - `lib/oli_web/controllers/api/scheduling_controller.ex`: `serialize_resource/2` became `serialize_resource/3` (list-clause and single-struct-clause), threading a `numbering_map` computed once in `index/2` through to a new private `resource_numbering/2`, which overlays suppression-aware numbering onto containers only (pages keep raw per-container ordinals).
  - `lib/oli_web/live/delivery/instructor_dashboard/helpers.ex`: `return_page/3` computes `numbering_map` once up front; a new private `container_label/3` overlays it, falling back to bare `container.title` when suppressed. This also hoisted the label computation out of the inner per-child `Enum.reduce` it previously ran inside.
- [x] Data or interface changes: `serialize_resource/2` -> `/3` arity change (both call sites updated); new private helpers `resource_numbering/2`, `container_label/3`. Additive-only: no public interface changed shape in a breaking way.
- [x] Access-control or safety checks: N/A — no new authz boundary; security review confirmed the existing `can_access_section?/2` gate is unchanged and still wraps the new numbering overlay.
- [x] Observability or operational updates: N/A for this phase.
- [x] Frontend changes (scope deviation from FDD, documented below): `assets/src/apps/scheduler/ScheduleLine.tsx`, `ScheduleSlideout.tsx`, `scheduler-slice.ts`, and `scheduling-thunk.ts`.

## Test Blocks
- [x] Tests added:
  - `test/oli_web/controllers/api/scheduling_controller_test.exs` — new `describe "suppression-aware numbering"` block: suppressed container gets `nil` numbering, sibling pages/containers correctly renumbered, plus the AC-020 no-suppression case.
  - `test/oli_web/live/delivery/instructor_dashboard/helpers_test.exs` (new file) — 2 tests against `Helpers.get_practice_pages/2` asserting `container_label` matches Learn's suppression-aware numbering.
  - `test/oli_web/live/grades_live_test.exs` — new `create_section_with_hierarchy/1` fixture (`Oli.Factory`-based) and `describe "grade sync assessment selector"` block, closing the Phase 3 direct-coverage gap for Grade Sync.
- [x] Required verification commands run:
  - `mix format` on all touched files.
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli/delivery/sections_test.exs test/oli_web/controllers/api/scheduling_controller_test.exs test/oli_web/live/delivery/instructor_dashboard/helpers_test.exs test/oli_web/controllers/delivery_controller_test.exs test/oli_web/live/grades_live_test.exs test/oli_web/live/sections/assessment_settings/settings_live_test.exs test/oli/resources/numbering_test.exs` — 263 tests, 0 failures.
  - `mix format --check-formatted` — clean.
  - `tsc --noEmit` (assets/) — clean.
- [x] Results captured: see above.

## Investigation Note 1 — nil-root regression found via the combined suite (significant, worth recording)
Running the full combined Phase 4 test suite (not just this phase's new tests) surfaced 2 pre-existing tests in `test/oli_web/controllers/delivery_controller_test.exs` (`download_scored_pages`, `download_practice_pages`) now crashing with `FunctionClauseError` inside `decorated_numbering_map/1`'s new `SectionResourceDepot`-based hierarchy lookup. Root cause: their shared `setup_lti_session/1` fixture built its section via bare `section_fixture/1`, never calling `Sections.create_section_resources/2`, leaving `root_section_resource_id: nil` and zero `SectionResource` rows — a state the code path `decorated_numbering_map/1` replaced (`SectionResourceDepot.containers/2`-only reads) had degraded gracefully from, but the new hierarchy-based lookup could not.

Investigated whether "a section with no populated section resources" is a realistic production scenario before deciding how to fix it. Confirmed by reading both real section-creation flows — `Oli.Delivery.create_from_publication/2` (`lib/oli/delivery.ex:152-158`) and `OliWeb.OpenAndFreeController.create_from_publication/2` (`lib/oli_web/controllers/open_and_free_controller.ex:280-297`) — that each wraps `create_section` + `create_section_resources` + `rebuild_contained_pages` + `rebuild_contained_objectives` in a single `Repo.transaction/1` with rollback on any step's failure. A section can never persist without its resources via either real flow: this state is structurally impossible in production, not a genuine edge case.

Given that, the fix was applied at the source rather than as defensive production code: `setup_lti_session/1` now calls `Sections.create_section_resources(section, base_publication)` after `section_fixture/1`, matching how a section is actually created. No guard clause was added to `decorated_numbering_map/1` — an earlier draft of this fix did add one (`def decorated_numbering_map(%Section{root_section_resource_id: nil}), do: %{}`), but it was removed once the investigation confirmed the scenario it defended against cannot occur outside of an unrealistic test fixture, consistent with this repository's guidance not to add handling for scenarios that can't happen.

## Investigation Note 2 — AC-006 frontend divergence (significant, worth recording)
The FDD (Section 4.2, 13) assumed FR-003 required zero frontend changes, since the Scheduler UI already renders whatever `numbering_index`/`numbering_level` it receives from the API. That held for the rendering logic itself, but not for `null`-handling: these fields can now be `null` for a suppressed container, and the existing TypeScript directly string-concatenated the value (`item.numbering_index + '.'`), which would render the literal text `"null."` instead of nothing.

Fixed with explicit `!== null` guards in `ScheduleLine.tsx` (line ~174) and `ScheduleSlideout.tsx` (line ~138), and widened `HierarchyItemSrc`'s `numbering_index`/`numbering_level` types from `number` to `number | null` in `scheduler-slice.ts`. A fourth file, `scheduling-thunk.ts`'s `console.info` debug log (dev-console-only, not user-facing), was flagged by the harness-review TypeScript pass as consuming the same now-nullable field and was null-guarded too.

## Work-Item Sync
- [x] FDD updated: Section 4.1 (component list gains `scheduling_controller.ex`, notes the new shared `Numbering.lookup/2` helper), Section 13 (AC-005/AC-006 testing note corrected), Section 16 (three new notes: Grade Sync gap closure, AC-006 frontend divergence, nil-root investigation/resolution).
- [x] plan.md: Phase 4 marked `[COMPLETE]`, tasks and testing tasks checked off with implementation notes, two "Implementation note" callouts (frontend divergence, nil-root investigation), Review Notes subsection added.
- [x] Open questions added to docs when needed: yes, both noted above, in FDD Section 16.

## Review Loop
- Round 1 (four parallel `harness-review` subagents — security, performance, elixir, typescript — diff scoped to only Phase 4's changes; `lib/oli/delivery/sections.ex` explicitly excluded as already reviewed in Phases 1/3):
  - Security: no findings.
  - Performance: no findings — confirmed `decorated_numbering_map/1` is called exactly once per request/mount in both changed files, correctly hoisted outside the per-resource/per-child loop; independently confirmed the `helpers.ex` change removes a pre-existing per-child recomputation of the container label (net improvement, not a regression).
  - Elixir: three Low/informational findings:
    1. Duplicated `Map.get(numbering_map, id)` / nil-vs-`%Numbering{}` branching across `scheduling_controller.ex` and `helpers.ex`.
    2. `scheduling_controller.ex` used `ResourceType.get_id_by_type("container")` instead of the codebase's dominant `ResourceType.id_for_container()` accessor.
    3. `grades_live_test.exs`'s new fixture duplicates a hierarchy shape similar to `Seeder.base_project_with_larger_hierarchy/0` rather than reusing it.
  - TypeScript: one Low finding (`scheduling-thunk.ts`'s debug log would print literal `"null"`) plus two informational notes, both verified safe with no action needed.
- Round 1 fixes:
  - Extracted `Oli.Resources.Numbering.lookup/2` (`lib/oli/resources/numbering.ex`) and updated both `resource_numbering/2` and `container_label/3` to use it instead of a raw `Map.get/2`, closing Elixir finding 1. This required adding a `@type t :: %__MODULE__{...}` to `Numbering` (it had none previously; a local, unqualified `t()` reference in a `@spec` requires an in-module type definition, unlike a cross-module `Numbering.t()` reference elsewhere in the codebase, which only `mix dialyzer` — not `mix compile` — would have caught).
  - Swapped `ResourceType.get_id_by_type("container")` for `ResourceType.id_for_container()` in `scheduling_controller.ex`, closing Elixir finding 2.
  - Elixir finding 3 accepted as a documented test-only tradeoff, not fixed — the fixture specifically needs `Oli.Factory`'s auto-wired LTI deployment, the same reasoning that led to building it in Phase 3/4 in the first place.
  - Null-guarded `scheduling-thunk.ts:74`'s `console.info` interpolation (`${i?.numbering_index ?? ''}`), closing the TypeScript finding.
  - Re-ran the full Phase 4 test suite post-fix: still 263 tests, 0 failures. Re-ran `mix compile --warnings-as-errors` and `tsc --noEmit`: both clean.
- Round 2: not needed — all findings were resolved in round 1's fix pass with no new issues introduced.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (four-checklist round run, all findings resolved)
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
