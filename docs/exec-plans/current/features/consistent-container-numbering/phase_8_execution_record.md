# Phase 8 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `8` — Closeout: Cross-Cutting Regression, Scenario Test, and Pattern Sweep

## Scope from plan.md
- A single consolidated regression check across every surface fixed in Phases 2-7, using one shared "suppressed top-level unit" section fixture.
- One `Oli.Scenarios` end-to-end integration test (author → publish → section → cross-surface assertions).
- The FDD's explicit follow-up pattern sweep for other `thin_hierarchy/3`-shaped bugs.
- A full `mix test` suite re-run.

## Implementation Blocks
- [x] `test/oli/delivery/consistent_container_numbering_regression_test.exs` (new file): one shared Factory-built fixture (2 units, 1 suppressed; 1 module + 1 page each; the suppressed unit's page is graded), checked against 6 independent code paths spanning every group's shared mechanism: `decorated_numbering_map/1` (the primitive), `DisplayLabels.effective_numbering/1` on the decorated hierarchy (Group C), `get_parent_containers_map/2` (Group A), `get_units_and_modules_containers/1` and `overlay_suppression_aware_numbering/2` (Group B), `Hierarchy.build_navigation_link_map/1` (FR-010/FR-011).
- [x] `test/scenarios/consistent_container_numbering/suppression_consistency_test.exs` (new file): inline-YAML `Oli.Scenarios` test authoring a real project (2 containers, 1 graded page), auto-published via the `section` directive, with a real enrolled instructor. `unnumbered_unit_ids` applied post-scenario via `Sections.update_section/2` (no DSL support for this setting, confirmed via audit). Asserts consistency across `decorated_numbering_map/1` (Learn), the Assessment Settings bulk-apply dropdown, and the Instructor Dashboard Content tab's Order column.
- [x] Pattern sweep performed (see Findings below).
- [x] Full `mix test` suite run.

## Design Decision — why 6 shared code paths instead of 12 re-tested surfaces
Every one of the ~12 fixed surfaces from Phases 2-6 is a thin adapter over one of a small number of shared functions (established since Phase 1: `decorated_numbering_map/1`, and the Phase 5 overlay helpers built on it). Re-running all 12 as full LiveView tests against one shared fixture would mostly re-prove what each phase's own review-gated tests already proved in isolation. This consolidated test's actual job -- and the FDD's stated intent ("ties together AC-001 through AC-022 rather than only verifying each in isolation") -- is to prove those independent call sites don't drift apart from each other, which is best done by checking each *distinct underlying mechanism* against the same fixture, not by re-rendering every LiveView a second time.

## Pre-Implementation Audit — `Oli.Scenarios` framework
Investigated (via a research fork, no code written during investigation) before writing the scenario test: YAML directive format (`project`/`section`/`user`/`enroll`/`manipulate`), `DirectiveParser.parse_yaml!/1` + `Engine.execute/2` invocation pattern, and `Engine.get_project/2`/`get_section/2`/`get_user/2` accessors returning real DB-persisted structs. Confirmed the DSL has no directive for `unnumbered_unit_ids` -- applied via a plain `Sections.update_section/2` call on the section struct the scenario hands back instead, using `project.id_by_title["Foundations"]` to resolve the container's resource id. Confirmed there's no scenario-specific assertion DSL for this feature's surfaces (Assessment Settings, Instructor Dashboard) -- other scenario tests either use custom hook modules or (per one existing precedent, `features/instructor_preview_hooks.ex`) plain `Phoenix.ConnTest`/HTML assertions; this test follows the simpler path of ordinary `Phoenix.LiveViewTest` code directly in the `test` block, matching every other test written in this work item, rather than introducing a new hook module for a one-off check.

## Pattern Sweep — Findings
Two convergent searches: every `Map.take/2` call site in `lib/` cross-checked against hierarchy/numbering context; every reference to `"display_numbering"` across `lib/` to confirm every producer/consumer is accounted for.

**Found**: `Helpers.build_units_and_modules_options/1` (`lib/oli_web/live/delivery/instructor_dashboard/helpers.ex:275-295`) reads raw `numbering_index`/`numbering_level` from `SectionResourceDepot.containers/2`, no suppression overlay. Traced its only consumer (`instructor_dashboard_live.ex:225-227`'s `:units_and_modules_options` assign) and confirmed via a repo-wide search (including `.heex` templates) that it is never rendered anywhere. **Disposition: confirmed out of scope, not fixed** -- the PRD's scope criteria require an actually-displayed label, and this is dead code. Documented in FDD Section 16 rather than silently dropped, with a note that it will need the same overlay treatment as its siblings in the same file if it's ever wired to a real UI.

**Not found**: no other instance of FR-014's specific pattern (a field-allowlist silently dropping `display_numbering` from an already-decorated hierarchy) beyond the two `Hierarchy.thin_hierarchy/3` callers already fixed in Phase 2. A third apparent `thin_hierarchy` call site (`lib/oli/delivery/attempts/page_lifecycle/attempt_state.ex:69`) was investigated and ruled out: it calls a same-named but unrelated function on a different module (`Oli.Delivery.Attempts.PageLifecycle.Hierarchy`, not `Oli.Delivery.Hierarchy`), for adaptive-activity attempt state, with no numbering concept at all.

## Test Blocks
- [x] Tests added:
  - `test/oli/delivery/consistent_container_numbering_regression_test.exs` — 6 tests, 0 failures.
  - `test/scenarios/consistent_container_numbering/suppression_consistency_test.exs` — 1 test, 0 failures, re-run 3 times to rule out flakiness (none observed).
- [x] Required verification commands run:
  - `mix format` on all touched files (including a small unrelated cleanup: `test/oli_web/live/delivery/instructor_dashboard/insights/learning_objectives_tab_test.exs` had an unused `unit2_resource` variable surfaced by the full suite compile, removed).
  - `mix compile --warnings-as-errors` — clean.
  - `mix test` (full suite, not targeted modules) — **26 doctests, 8409 tests, 0 failures (75 excluded)**, exit code 0. ~310 seconds.
  - `mix format --check-formatted` — clean.

## Work-Item Sync
- [x] FDD updated: Section 16 (two new notes: the pattern-sweep finding and disposition, and the `Oli.Scenarios` framework audit).
- [x] plan.md: Phase 8 marked `[COMPLETE]`, tasks/testing tasks checked off with implementation notes.
- [x] Open questions added to docs when needed: yes, both noted above, in FDD Section 16.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
- [x] All 22 acceptance criteria (AC-001 through AC-022) covered across Phases 2-8's tests, tied together by this phase's consolidated regression and scenario tests
