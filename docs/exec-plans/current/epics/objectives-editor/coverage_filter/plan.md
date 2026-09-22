# MER-5799 Coverage Issues Filter - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/objectives-editor/coverage_filter/prd.md`
- FDD: `docs/exec-plans/current/epics/objectives-editor/coverage_filter/fdd.md`
- Integration baseline: MER-5794 / PR #6800 (merged 2026-09-02) and
  MER-5797 / PR #6820 (merged 2026-09-07, commit `b913d0463a`). MER-5797's
  PR number changed once before merging (was #6818, closed without merging
  2026-09-02, replaced by #6820) — that risk no longer applies now that it
  is merged.

## Scope

Deliver a project-scoped Coverage Issues filter in the Learning Objectives LiveView. The feature classifies insufficient formative and summative coverage from the existing in-memory `ObjectiveCoverage` snapshot, persists shared thresholds in `ProjectAttributes`, renders the approved warning/filter/settings affordances, and composes with Raphael's search, sort, paging, expansion, and URL state.

Guardrails:

- Do not add coverage queries, migrations, caches, or mutate objective/activity associations.
- Keep classification and persistence out of HEEx rendering.
- Do not fork MER-5797's state or patch machinery. The canonical URL state is `query`, `filter`, `sort_by`, `sort_order`, `offset`, and `expanded`.
- Do not invent a Learn more destination. Keep the prepared affordance hidden in MER-5799; MER-5919 owns the URL and activation.

## Clarifications & Default Assumptions

- Thresholds are shared configuration for every authorized author of a project, stored as new embedded `ProjectAttributes` fields in `projects.attributes`; missing keys read as `3` formative and `3` summative.
- A direct objective issue and an issue found on any descendant both make the visible parent an affected result. A filtered parent need not be auto-expanded solely because it has an issue.
- `Coverage Issues` is a value within the existing `filter` map, rather than a separate query parameter. Its exact key and serialised value must match MER-5797's merged conventions.
- The feature may begin pure-domain/persistence work on the current #6800 base. Before any LiveView/toolbar implementation is finalized, rebase onto the merged #6800 and reconcile with the current merged tip of MER-5797's PR (see the PR-number note above). This is a hard integration gate, not end-of-PR cleanup.
- Final Figma reconciliation covers responsive behavior not explicit in nodes `365:14554` and `365:17228`; MER-5919 resolves the published Learn more URL separately.

## Phase 1: Lock the Integration Contract and UI Brief

- Goal: turn MER-5797's live state contract and the supplied Figma nodes into an implementation baseline before touching the overlapping UI surface.
- Tasks:
  - [x] Record the exact merged revision of MER-5794 and MER-5797 used by the branch; rebase MER-5799 at the required checkpoints.
  - [x] Reconcile `ObjectivesLive`, `Listing`, `FilterBox`, `Filter`, `TableHandlers`, and their LiveView tests against MER-5797 rather than copying an earlier implementation.
  - [x] Preserve `TableHandlers` ownership of `apply_search`, `reset_search`, `apply_filter`, sorting, paging, and patch construction. Use `ObjectivesLive.live_path/2` so its `expanded` serialization remains additive.
  - [x] Confirm that applying or clearing Coverage Issues updates only the existing `filter` map, resets `offset` to zero, and retains query, sort direction, `expanded`, sidebar state, and CSV-compatible URL state.
  - [x] Produce the governed Figma implementation brief for nodes `365:14554` and `365:17228`, including toolbar placement, filter count, popover controls, warning states, keyboard/focus behavior, tokens, icons, and the exact component/file targets.
  - [x] Track the unpublished Learn more destination as an external product dependency; MER-5919 owns its URL and activation.
- Testing Tasks:
  - [x] Add or update a focused regression test that exercises the canonical patch parameter round-trip with a non-empty search query, sort, expanded parent/child set, and active coverage-filter value.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - The branch is based on the documented post-merge integration baseline, the Figma brief is available, and no proposed MER-5799 event or URL parameter bypasses `TableHandlers`.
- Gate:
  - Do not begin overlapping toolbar/LiveView rendering until the MER-5797 PR's merge/rebase reconciliation is complete and the parameter-composition regression passes.
- Dependencies:
  - MER-5794 must be merged; MER-5797's current draft is the design reference and its merge is required before final LiveView integration.
- Parallelizable Work:
  - The pure classifier, `ProjectAttributes` changes, and their unit tests may proceed while Raphael's draft is awaiting merge.

## Phase 2: Project Settings and Pure Issue Classification

- Goal: create the authoritative, testable thresholds and issue data without coupling domain rules to LiveView rendering.
- Tasks:
  - [x] Add non-negative formative and summative threshold fields, defaults, and validation to `Oli.Authoring.Course.ProjectAttributes`.
  - [x] Extend the authorized project update path so both fields persist atomically in `projects.attributes` and projects without keys continue to read defaults.
  - [x] Implement a small pure classifier that accepts direct coverage counts and thresholds and returns formative, summative, and any-issue state.
  - [x] Build parent rollup data from the loaded `ObjectiveCoverage` graph so parent issue state includes direct and descendant evidence while child markers retain their direct reason.
  - [x] Recompute derived issue state from the successful persisted settings and from each successful asynchronous coverage load; do not treat a load failure as zero coverage.
- Testing Tasks:
  - [x] Cover defaults, valid/invalid threshold updates, atomic persistence, backward compatibility for projects with absent keys, direct formative/summative/both classifications, and descendant-to-parent rollup.
  - Command(s): `mix test test/oli/authoring/course/project_attributes_test.exs` and the focused classifier/context test module(s).
- Definition of Done:
  - Project settings are authorized, persisted, backward compatible, and classification is independently tested without a LiveView.
- Gate:
  - No UI code may duplicate the issue predicate or access persistence directly; it consumes the proven derived data.
- Dependencies:
  - Phase 1's documented contract; existing `ObjectiveCoverage` remains the sole coverage source.
- Parallelizable Work:
  - Settings changeset/persistence tests and pure classifier/rollup tests can be developed independently once their shared data shape is agreed.

## Phase 3: Compose Filter State with Search, URL, Sort, and Paging

- Goal: integrate derived issues into Raphael's table lifecycle without losing independent search expansion or shareable URLs.
- Tasks:
  - [x] Add the Coverage Issues control and affected-objective count to the toolbar at the Figma-defined location, using the shared filter surface where its API is sufficient.
  - [x] Represent activation through the existing `filter` map and `apply_filter` flow; preserve `query`, `sort_by`, `sort_order`, `expanded`, sidebar state, and CSV export parameters.
  - [x] Extend `filter_rows/3` to compose search and coverage filtering over the already loaded normalized model before `SortableTableModel` sorts and slices rows.
  - [x] Keep the mechanism MER-5797 merged for automatic search expansion exclusively responsible for that expansion: a local `attach_hook(:objective_search_expansion, :handle_event, ...)` in `objectives_live.ex`'s `mount/3`, plus `search_expanded_objective_slugs`/`search_expansion_ids` and the private `expand_search_results/3`. There is no `prepare_search/2` in this codebase. Coverage filter changes must not discard manual expansions or search-created expansion bookkeeping.
  - [x] Rebuild the table model after threshold changes or coverage reloads, then route state back through the established refresh/patch path.
- Testing Tasks:
  - [x] Add LiveView state-transition coverage for active/inactive filter, count, parent inclusion for child issues, filter plus nested page/activity search, sorting, pagination reset, direct URL loading, clear/reset behavior, and preservation of `expanded=child,parent`.
  - [x] Assert no additional coverage/database loading is triggered by filter toggles.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - All table state combinations are deterministic, shareable through URL patches, and render the same filtered rows after reload.
- Gate:
  - The combined search + Coverage Issues + sort + paging + expanded-state regression must pass against the post-MER-5797 baseline.
- Dependencies:
  - Phases 1 and 2; merged MER-5797 conventions.
- Parallelizable Work:
  - Test fixtures for parent/child coverage and URL-composition assertions can be prepared while the final toolbar markup is being implemented.

## Phase 4: Settings Popover and Issue Rendering

- Goal: deliver the author-facing settings and warning feedback with Figma parity and accessible semantics.
- Tasks:
  - [x] Implement the settings popover with labelled threshold controls, increment/decrement behavior, explanatory copy, restore-defaults action, validation feedback, and a styled hidden Learn more extension point for MER-5919.
  - [x] Render warning icons on deficient formative/summative badges, red outlines and non-color issue indicators on affected objectives and sub-objectives, and formative/summative/both inline messages beneath associated pages and activities.
  - [x] Keep child warning reasons direct and parent warning state rolled up; preserve existing expansion, coverage-bucket, and edit/delete interaction behavior from MER-5794/MER-5797.
  - [x] Verify light and dark-mode token mapping, responsive toolbar/popover layout, visible focus, keyboard operation, ARIA labels, pressed state, result announcements, and error states against the governed Figma brief.
- Testing Tasks:
  - [x] Add LiveView and component tests for rendered markers/messages by issue type, settings update/default restore/validation boundaries, authorized persistence, accessible names/state, and absence of markers for healthy objectives.
  - [x] Perform manual visual QA for the supplied light/dark Figma states; verify keyboard semantics through native controls and rendered ARIA/focus assertions.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - The UI meets all coverage-warning and settings acceptance criteria without relying on color alone, and the Learn more dependency is assigned to MER-5919 with the current affordance hidden.
- Gate:
  - Accessibility and Figma parity QA pass; MER-5919 owns the Learn more URL and visible activation.
- Dependencies:
  - Phases 2 and 3, plus the Phase 1 Figma brief.
- Parallelizable Work:
  - Copy/accessible-message tests and icon/token mapping can proceed alongside the popover interaction work after the data contract is stable.

## Phase 5: Integration Closeout and Verification

- Goal: prove the feature is stable on the real merge order and ready for review.
- Tasks:
  - [x] Rebase or merge the final merged revisions of MER-5794 and MER-5797, resolving only the identified state, toolbar, listing, and test seams.
  - [x] Inspect the final diff for duplicate URL/filter ownership, per-row queries, lost authorization, or accidental changes to objective/activity associations.
  - [x] Update requirements proofs with the implemented test and manual-QA evidence.
  - [x] Confirm existing coverage-load telemetry/error behavior remains intact and no content body or sensitive data is emitted by settings failures.
  - [x] Run the repository-required code review, including Elixir, UI, security, and performance lenses.
- Testing Tasks:
  - [x] Run formatting, targeted tests, the complete affected LiveView suite, and the full test suite as risk/time permits after the final rebase.
  - Command(s): `mix format --check-formatted`, `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`, `mix test`
- Definition of Done:
  - The branch is reconciled with both predecessor PRs, validations are green, requirements have evidence, and no known integration or product dependency is hidden.
- Gate:
  - Final branch must be based on merged MER-5794 and MER-5797; all automated gates and review findings are resolved before PR readiness.
- Dependencies:
  - Phases 1 through 4 and merged predecessor PRs.
- Parallelizable Work:
  - Requirements-proof updates, focused code review, and manual Figma QA can run concurrently once the final rebase is stable.

## Parallelization Notes

- Work safely in parallel only below the LiveView boundary: ProjectAttributes persistence/classifier work does not need to wait for MER-5797's PR.
- Do not independently redesign shared `FilterBox`, `TableHandlers`, `live_path/2`, or `search_expanded_objective_slugs`/`search_expansion_ids` expansion-tracking state. (MER-5797 no longer uses `OliWeb.Common.Filter` for the search box — it now uses `OliWeb.Common.SearchInput` inside a `phx-change="apply_search"` form.) Any change to those seams must carry its combination regression against the merged MER-5797 tip.
- Keep the final LiveView integration as a deliberately serialized reconciliation after MER-5797 merges; this is the lowest-risk point to resolve unavoidable overlapping lines.

## Phase Gate Summary

- Gate A: MER-5797 URL/filter/expansion contract and governed Figma brief are captured before overlapping UI work.
- Gate B: Shared project settings and pure issue classification pass focused tests.
- Gate C: Coverage filter composes with search, sort, paging, URL, and expansions on the post-MER-5797 baseline.
- Gate D: Figma/accessibility QA passes and Learn more is safely deferred to MER-5919 behind the styled hidden extension point.
- Gate E: Final rebase, automated verification, requirements evidence, and review are complete.

## Decision Log

### 2026-09-08 - Close MER-5799 with Learn more hidden for MER-5919

- Change: The plan no longer treats the missing Learn more URL as a release blocker for MER-5799; its styled node remains hidden until MER-5919.
- Reason: Product split the knowledge-base destination and activation into the follow-up ticket.
- Evidence: `phase-1-figma-brief.md`, `fdd.md`, and `lib/oli_web/live/workspaces/course_author/objectives/coverage_settings_popover.ex`.
- Impact: Gate D verifies the hidden state and explicit follow-up ownership instead of requiring a URL in this ticket.
