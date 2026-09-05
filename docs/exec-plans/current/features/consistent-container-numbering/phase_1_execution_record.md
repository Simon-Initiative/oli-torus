# Phase 1 Execution Record

Work item: `docs/exec-plans/current/features/consistent-container-numbering`
Phase: `1` — Shared Primitive: `Sections.decorated_numbering_map/1`

## Scope from plan.md
- Introduce the one new function every Group A and Group B phase (Phases 3-6) depends on, before any consumer is touched.
- Add `Sections.decorated_numbering_map/1` to `lib/oli/delivery/sections.ex`, filtered to containers, keyed by container resource_id, absent-key-means-suppressed contract.
- No consumers wired in this phase.

## Implementation Blocks
- [x] Core behavior changes: `Sections.decorated_numbering_map/1` added to `lib/oli/delivery/sections.ex`, plus a small shared `container_node?/1` private predicate (also adopted by `fetch_ordered_container_labels/2`, resolving a duplication finding).
- [x] Data or interface changes: new public function `decorated_numbering_map(section :: Section.t()) :: %{integer() => Numbering.t()}`. No schema/interface changes to existing functions.
- [x] Access-control or safety checks: N/A — pure read function over data the caller already has access to; security review confirmed no new authz boundary.
- [x] Observability or operational updates when needed: none required for this phase (no consumer wired yet).

## Test Blocks
- [x] Tests added: `test/oli/delivery/sections_test.exs`, new `describe "decorated_numbering_map/1"` block, 3 tests (no-suppression parity with canonical numbering, suppressed top-level unit + sibling renumbering, modules nested under a suppressed unit).
- [x] Required verification commands run:
  - `mix format lib/oli/delivery/sections.ex test/oli/delivery/sections_test.exs`
  - `mix format --check-formatted lib/oli/delivery/sections.ex test/oli/delivery/sections_test.exs` — clean
  - `mix test test/oli/delivery/sections_test.exs` — 95 tests, 0 failures (both before and after the post-review implementation change)
- [x] Results captured: see above; full output captured in session transcript.

## Work-Item Sync
- [x] FDD updated: Section 4.1 (component description), 4.3 (lifecycle/caching claim), 8 (caching strategy), 9 (performance posture), 10 (failure modes), 15 (risk mitigation), 17 (references) all updated to reflect the `SectionResourceDepot`-backed implementation actually shipped, replacing the originally-planned `MinimalHierarchy.full_hierarchy/1`-based approach.
- [x] PRD updated: Section 8 and Section 13 (Non-Functional Requirements, Risks) touched up to stop hard-coding `MinimalHierarchy` as the specific mechanism, since the NFR intent (reuse a proven, cached pattern) is what actually matters and is still met.
- [x] plan.md updated: Phase 1 marked `[COMPLETE]`, task list updated with the implementation-note explaining the deviation and why, a Review Notes subsection added summarizing the three-checklist review round and how each finding was resolved.
- [x] Open questions added to docs when needed: none new: the review findings were resolved within this phase, not deferred.

## Review Loop
- Round 1 (three parallel `harness-review` subagents, one per checklist — `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, per `docs/CODEREVIEW.md`'s required workflow):
  - Security: no findings.
  - Performance: 1 HIGH (bypasses the Depot cache — `.review/performance.md` §3, an explicit "enforce verbatim" Torus rule), 1 MEDIUM (redundant `Section` re-fetch inside `MinimalHierarchy.full_hierarchy/1`), 1 LOW (no caching wrapper vs. `get_ordered_container_labels/2`'s `SectionCache.get_or_compute/3`).
  - Elixir: pipeline duplicated with `fetch_ordered_container_labels/2`; the other two findings overlapped with the performance review's redundant-fetch and no-caching points.
- Round 1 fixes:
  - Swapped `MinimalHierarchy.full_hierarchy(section.slug)` for `SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)` — resolves the HIGH (now Depot-cached) and the MEDIUM (no redundant fetch, since it accepts the already-loaded `%Section{}` directly instead of re-fetching by slug).
  - Extracted `container_node?/1`, used by both `decorated_numbering_map/1` and `fetch_ordered_container_labels/2` — resolves the Elixir duplication finding.
  - LOW (no caching wrapper) deliberately not addressed further in this phase: the underlying data is now Depot-cached (the expensive part), and adding a second memoization layer on top of the cheap in-memory decoration step would be inconsistent with how other Depot-backed consumers in this codebase already operate (e.g. `scope_resources.ex`, `student_progress_rows/2`) — documented as a considered-and-deferred decision in the FDD (Section 4.3/8), not a gap.
  - Verified with a second `mix test test/oli/delivery/sections_test.exs` run post-fix: still 95 tests, 0 failures.
- Round 2: not needed — all actionable findings were resolved in round 1's fix pass, and the change was small enough not to warrant a second review pass.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed (code review enabled per `harness.yml`; three-checklist round run, findings resolved)
- [x] Validation passes (`validate_work_item.py --check all` green after doc sync)
