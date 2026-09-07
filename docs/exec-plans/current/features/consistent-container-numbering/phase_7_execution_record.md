# Phase 7 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `7` — `previous_next_index` Fix + Data Migration (FR-010, FR-011)

## Scope from plan.md
- Add `"display_numbering"` to `Hierarchy.build_navigation_link_map/1`'s per-node output.
- Add a keyset-paginated, throttled production data migration nulling `previous_next_index` for sections with non-empty `unnumbered_unit_ids`.
- No `down/0` restoration (derived, self-healing cache).

## Pre-Implementation Audit (before writing any code)
Before implementing, audited every call site of `build_navigation_link_map/1` via `grep`, since prior phases repeatedly found the FDD's documented call-site list incomplete. Found 4, not the 2 the FDD names:
1. `previous_next_index.ex:146,158` — the FDD's actual target, feeds the persisted `section.previous_next_index` cache.
2. `instructor_dashboard_live.ex:519` (`build_course_content_hierarchy/1`) — undocumented. Builds fresh per request, not migration-relevant, but genuinely broken today for a suppressed section (confirmed by tracing its render path into `DisplayLabels.effective_numbering/1`'s already-correct nil-fallback handling — the gap was purely the missing `"display_numbering"` key upstream).
3. `page_editor.ex:334` — investigated and confirmed irrelevant (authoring-side, never decorated, no `unnumbered_unit_ids` concept).

This audit shaped the whole phase: only site 1 needed the migration; site 2 needed a confirming test (no code); site 3 needed nothing.

## Implementation Blocks
- [x] Core behavior changes:
  - `Hierarchy.build_navigation_link_map/1`: new private `display_numbering_entry/1`, adds `"display_numbering"` (nil or `%{"level" => ..., "index" => ...}`, string-keyed) per node. `"level"`/`"index"` untouched.
  - New `Oli.Delivery.PreviousNextIndexBackfill` (`lib/oli/delivery/previous_next_index_backfill.ex`): `run/1`, keyset-paginated batching logic, kept in `lib/` (not the migration file) specifically for testability outside `Ecto.Migrator`'s runner context.
  - New migration `priv/repo/migrations/20260826190000_nullify_previous_next_index_for_suppressed_sections.exs`: thin wrapper, `@disable_ddl_transaction true`, `@disable_migration_lock true`, calls `PreviousNextIndexBackfill.run/1`, logs the total, `down/0` is a documented no-op.
- [x] Data or interface changes: additive-only (`"display_numbering"` key); new migration (irreversible by design, cache-only).
- [x] Access-control or safety checks: N/A — confirmed by security review the migration has no external trigger and uses fully parameterized SQL.
- [x] Observability or operational updates: migration logs the total row count updated on completion.

## Migration Design Note — refined beyond the plan's literal sketch (significant, worth recording)
The plan/FDD described filtering the SELECT directly by `array_length(unnumbered_unit_ids, 1) > 0`. Implemented instead as a two-step page: (1) SELECT bounded purely by primary key (`id > last_id ORDER BY id LIMIT batch_size`, no domain predicate), (2) UPDATE applying the real predicate (`array_length(...) > 0 AND previous_next_index IS NOT NULL`) only within that already-bounded id batch. Reasoning: a SELECT filtered by the domain predicate directly would need to scan an unbounded number of rows past `last_id` to fill a page if suppressed sections are rare — defeating keyset pagination's purpose. The two-step design bounds every page's cost to exactly `batch_size` regardless of match rarity. The performance review explicitly verified this reasoning holds (see Review Loop below).

## Test Blocks
- [x] Tests added:
  - `test/oli/delivery/hierarchy_test.exs` — new `describe "build_navigation_link_map/1 with suppressed units"`, plus an AC-020 assertion on the existing no-suppression test.
  - `test/oli/delivery/previous_next_index_backfill_test.exs` (new file) — 3 tests: predicate correctness, multi-batch pagination (5 rows, `batch_size: 2`), idempotency.
  - `test/oli/delivery/previous_next_index_test.exs` — new `describe "retrieve/2 with a suppressed unit (AC-018)"`, confirming just-in-time rebuild with suppression-aware numbering.
  - `test/oli/delivery/sections_test.exs` — new `describe "build_hierarchy/1 (AC-015/AC-016 suppression pass-through)"`, confirming `display_numbering` survives `Sections.build_hierarchy/1`'s reshaping of the persisted cache.
  - `test/oli_web/live/delivery/instructor_dashboard/overview/content_tab_test.exs` — new describe block + dedicated `Oli.Factory` fixture (see test-clarity note below) confirming the Instructor Dashboard Course Content tab (call site #2 from the audit) renders correctly with no code change.
- [x] Required verification commands run:
  - `mix format` on all touched files.
  - `mix compile --warnings-as-errors` — clean.
  - Phase-scoped: `mix test test/oli/delivery/hierarchy_test.exs test/oli/delivery/previous_next_index_backfill_test.exs test/oli/delivery/previous_next_index_test.exs test/oli/delivery/sections_test.exs test/oli_web/live/delivery/instructor_dashboard/overview/content_tab_test.exs test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs test/oli/authoring/editing/page_editor_test.exs` — 215 tests, 0 failures.
  - Full combined regression (every phase's touched test files): 812 tests, 0 failures (one transient DBConnection failure on a first pass, confirmed pre-existing infra flakiness on re-run, same class seen in every earlier phase).
  - `mix format --check-formatted` — clean.

## Test-Clarity Correction (mid-phase, user-raised)
Initially wrote the Instructor Dashboard Course Content suppression test reusing the shared `Oli.Seeder.base_project_with_larger_hierarchy/0` fixture (already used by this file's other two tests), asserting the exact heading text `"Unit 1"` for the suppressed case, with a comment explaining why that string (not `"Unit 1: Unit 1"`) was the correct assertion. The user flagged this: needing a comment to explain why a bare title assertion isn't ambiguous is itself a sign to pick a title that isn't ambiguous in the first place. Fixed by giving this one test its own small `Oli.Factory` fixture (a single suppressible unit titled "Foundations", not "Unit N") — same pattern already established in Phases 2/4/6 for the same class of issue, applied here proactively once flagged rather than needing a fresh audit.

## Work-Item Sync
- [x] FDD updated: Section 13 (AC-015/AC-016 testing note corrected to reflect actual coverage decisions), Section 16 (four new notes: the 3-not-2 call-site audit finding, the migration's two-step design refinement, the lib/-vs-migration-file testability decision, the documented course_content_live.ex/page_delivery_controller.ex scope decision; plus a status update on the previously-open "confirm production row count" question).
- [x] plan.md: Phase 7 marked `[COMPLETE]`, tasks/testing tasks checked off with implementation-note callouts, Review Notes subsection added.
- [x] Open questions added to docs when needed: yes, all noted above, in FDD Section 16.

## Review Loop
- Round 1 (three parallel `harness-review` subagents — security, performance, elixir — diff scoped to only Phase 7's changes, with explicit extra review attention to the migration given this phase's risk level):
  - Security: no findings — confirmed both raw SQL queries use fully parameterized placeholders (no interpolation), confirmed no external/user-triggerable entry point to the migration, confirmed `@disable_ddl_transaction`/`@disable_migration_lock` are operational tradeoffs with no security implication.
  - Performance: no findings — confirmed the two-step (bounded SELECT, then scoped UPDATE) design genuinely bounds every page's cost regardless of match rarity; confirmed `array_length/2` is O(1) per row (array dimensions are stored in the header, not scanned); confirmed exactly 2 queries per page, no per-row pattern. One non-blocking operational note: the migration doesn't checkpoint progress outside `sections` table state, so an interrupted run restarts the keyset scan from `id=0` on retry (correctness unaffected — the operation is idempotent) — accepted given the unconfirmed-but-assumed-small table size.
  - Elixir: one finding, fixed. `PreviousNextIndexBackfill`'s id-extraction used `List.flatten(rows)`, which only works because each row happens to be a single-element list and would silently misbehave if the query ever selected more than one column — fixed to `Enum.map(rows, fn [id] -> id end)`. Also explicitly confirmed sound, no changes needed: `%Postgrex.Result{}` pattern-matching against `Repo.query!/2` is idiomatic fail-fast style for migration code; `Oli.Repo` executes identically to `Ecto.Migration`'s `repo()` helper, so the `lib/`-split introduces no behavioral risk; the recursive `run_batches/4` accumulator loop is the correct shape (tail-recursive, no stack growth).
  - Re-verified with the full Phase 7 test suite post-fix: still 215 tests (phase scope) / 812 tests (full regression), 0 failures. `mix compile --warnings-as-errors` and `mix format --check-formatted` both clean.
- Round 2: not needed — the one actionable finding was resolved in round 1's fix pass with no new issues introduced.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (three-checklist round run, all findings resolved or explicitly accepted with rationale)
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
