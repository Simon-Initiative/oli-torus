# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `2` — Group C Quick Fixes (FR-009, FR-012, FR-014)

## Scope from plan.md
- Close the five lowest-risk call sites, each a field-read swap onto an already-decorated hierarchy the code already holds, with no new query. Independent of Phase 1.
- FR-009: `scope_resources.ex` (Intelligent Dashboard assessment context).
- FR-012: `resource_title.ex` (Student Progress breadcrumbs — both `student_view.ex` and Student Dashboard Progress tab call paths).
- FR-014: `Hierarchy.thin_hierarchy/3`'s two callers (`preview_page_context.ex`, `lesson_live.ex`).

## Implementation Blocks
- [x] Core behavior changes:
  - `lib/oli/instructor_dashboard/oracles/scope_resources.ex` — `container_label/2` now uses `DisplayLabels.effective_numbering/1`; `build_items/4` falls back to the container's own title when suppressed.
  - `lib/oli_web/live/progress/resource_title.ex` — rewrote `ancestor_segment/1` (extracted from inline template logic) to use `DisplayLabels.effective_numbering/1` with a title fallback, using `Numbering.prefix/1` for the numbered case (per review finding).
  - `lib/oli_web/delivery/instructor/preview_page_context.ex` and `lib/oli_web/live/delivery/student/lesson_live.ex` — added `"display_numbering"` to `Hierarchy.thin_hierarchy/3`'s `fields_to_keep` allowlist.
- [x] Data or interface changes: none — no new public functions, no signature changes.
- [x] Access-control or safety checks: N/A — confirmed by security review (no new authz boundary; reused already-scoped data).
- [x] Observability or operational updates: none required.

## Test Blocks
- [x] Tests added:
  - `test/oli/instructor_dashboard/oracles/concrete_oracles_test.exs` — 1 new test (ScopeResources oracle, suppression-aware context labels).
  - `test/oli_web/live/progress/resource_title_test.exs` (new file) — 2 tests, direct `render_component/2` coverage of the shared `ResourceTitle` component.
  - `test/oli_web/live/delivery/student/lesson/components/outline_component_test.exs` — 1 new test (suppression-aware outline rendering via `display_numbering`).
- [x] Required verification commands run:
  - `mix format` on all touched files.
  - `mix format --check-formatted` — clean.
  - `mix test test/oli/instructor_dashboard/oracles/concrete_oracles_test.exs test/oli_web/live/progress/resource_title_test.exs test/oli_web/live/delivery/student/lesson/components/outline_component_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli_web/live/delivery/student/lesson_live_test.exs` — 174 tests, 0 failures (includes pre-existing tests on files this phase touched, confirming no regressions).
- [x] Results captured: see above; full output captured in session transcript.
- Known gap (documented, not silent): FR-014's `preview_page_context.ex` call site was fixed but not covered by a dedicated new integration test in this phase — see plan.md Phase 2 Testing Tasks and FDD Section 16 for the reasoning (same one-line fix, same underlying mechanism already verified via the sibling call site's test).

## Work-Item Sync
- [x] plan.md: Phase 2 marked `[COMPLETE]`, tasks checked off with implementation notes, Review Notes subsection added, the FR-014/AC-021 test-coverage decision documented explicitly (not silently dropped).
- [x] FDD: Section 16 (Open Questions & Follow-ups) updated with the same AC-021 coverage note, so it's visible from both documents.
- [x] Open questions added to docs when needed: the AC-021 coverage gap is the only new one; recorded in both plan.md and fdd.md.

## Review Loop
- Round 1 (three parallel `harness-review` subagents — `.review/security.md`, `.review/performance.md`, `.review/elixir.md`):
  - Security: no findings.
  - Performance: no findings — confirmed all 5 sites reuse hierarchies already obtained via `SectionResourceDepot` by code this diff did not modify; no new queries, no `.review/performance.md` §3 violation (the Phase 1 finding did not recur).
  - Elixir: one Medium finding — `resource_title.ex`'s `ancestor_segment/1` duplicated the existing `Numbering.prefix/1` helper (`container_type_label(numbering) <> " #{numbering.index}"`) instead of reusing it, an established convention used in several other files (`links.ex`, `breadcrumb.ex`, `entry.ex`, `hierarchy_picker.ex`). No other findings — nil-handling for suppressed containers was independently verified correct at both call sites, and the deliberate choice to keep `Sections.get_container_label_and_numbering/3` in `scope_resources.ex` (rather than switching to `DisplayLabels.resource_label/3`, which mislabels level-0 as "Section" instead of "Curriculum") was confirmed correct, not a duplication bug.
- Round 1 fixes:
  - Replaced the manual string interpolation in `resource_title.ex` with `Numbering.prefix(numbering)`.
  - Re-ran `mix test test/oli_web/live/progress/resource_title_test.exs` post-fix: still 2/2 passing.
- Round 2: not needed — the single finding was resolved and re-verified in round 1's fix pass.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (three-checklist round run, one finding resolved)
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
